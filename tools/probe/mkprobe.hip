// Megakernel feasibility on one node (gfx1151): device limits, the cost of one grid-wide barrier in a persistent kernel,
// streaming read bandwidth when a barrier ends every stage (as between dependent ops of one layer), the same with the next
// stage's loads issued before the barrier, and re-read bandwidth of a buffer that fits the 32 MB MALL.
//   mkprobe            (build: hipcc -O3 --offload-arch=gfx1151 mkprobe.hip -o mkprobe)
#include <hip/hip_runtime.h>
#include <algorithm>
#include <cstdio>
#include <vector>
#define CK(x) do { hipError_t e_ = (x); if (e_ != hipSuccess) { printf("%s -> %s\n", #x, hipGetErrorString(e_)); return 1; } } while (0)

// sense-free barrier: every block adds 1 and waits until the counter reaches the next multiple of the block count
__device__ __forceinline__ void grid_barrier(unsigned * ctr, unsigned nblocks, unsigned & target) {
    target += nblocks;
    __syncthreads();
    if (threadIdx.x == 0) {
        __hip_atomic_fetch_add(ctr, 1u, __ATOMIC_RELEASE, __HIP_MEMORY_SCOPE_AGENT);
        while (__hip_atomic_load(ctr, __ATOMIC_ACQUIRE, __HIP_MEMORY_SCOPE_AGENT) < target) {
            __builtin_amdgcn_s_sleep(1);
        }
    }
    __syncthreads();
}

__global__ void k_barriers(unsigned * ctr, int iters) {
    unsigned target = 0;
    for (int i = 0; i < iters; i++) {
        grid_barrier(ctr, gridDim.x, target);
    }
}

// stream `stages` chunks of `stage_bytes` each; a barrier after every stage. ahead: load the next stage's share into
// registers before the barrier (the weights of the next op do not depend on this op's result)
template <bool ahead>
__global__ void k_stages(const float4 * __restrict__ w, size_t stage_n, int stages, unsigned * ctr, float * out) {
    unsigned target = 0;
    float4 acc = {0, 0, 0, 0};
    const size_t tid = blockIdx.x * (size_t) blockDim.x + threadIdx.x, nth = (size_t) gridDim.x * blockDim.x;
    constexpr int R = 8;  // loads in flight per thread
    float4 nxt[R];
    if (ahead) {
        for (int r = 0; r < R; r++) { const size_t i = tid + r*nth; nxt[r] = i < stage_n ? w[i] : float4{0, 0, 0, 0}; }
    }
    for (int s = 0; s < stages; s++) {
        const float4 * ws = w + (size_t) s*stage_n;
        size_t i0 = tid;
        if (ahead) {
            for (int r = 0; r < R; r++) { acc.x += nxt[r].x; acc.y += nxt[r].y; acc.z += nxt[r].z; acc.w += nxt[r].w; }
            i0 = tid + R*nth;
        }
        for (size_t i = i0; i < stage_n; i += nth) {
            const float4 v = ws[i]; acc.x += v.x; acc.y += v.y; acc.z += v.z; acc.w += v.w;
        }
        if (ahead && s + 1 < stages) {
            const float4 * wn = w + (size_t) (s + 1)*stage_n;
            for (int r = 0; r < R; r++) { const size_t i = tid + r*nth; nxt[r] = i < stage_n ? wn[i] : float4{0, 0, 0, 0}; }
        }
        grid_barrier(ctr, gridDim.x, target);
    }
    if (acc.x + acc.y + acc.z + acc.w == 12345.f) out[0] = acc.x;
}

__global__ void k_read(const float4 * __restrict__ a, size_t n, float * out) {
    float4 s = {0, 0, 0, 0};
    for (size_t i = blockIdx.x * (size_t) blockDim.x + threadIdx.x; i < n; i += (size_t) gridDim.x * blockDim.x) {
        const float4 v = a[i]; s.x += v.x; s.y += v.y; s.z += v.z; s.w += v.w;
    }
    if (s.x + s.y + s.z + s.w == 12345.f) out[0] = s.x;
}

static float time_ms(hipEvent_t e0, hipEvent_t e1) { float ms = 0; hipEventSynchronize(e1); hipEventElapsedTime(&ms, e0, e1); return ms; }

int main() {
    hipDeviceProp_t p; CK(hipGetDeviceProperties(&p, 0));
    int coop = 0; CK(hipDeviceGetAttribute(&coop, hipDeviceAttributeCooperativeLaunch, 0));
    printf("device %s: %d CUs, LDS/block %zu KiB, LDS/CU %zu KiB, L2 %d KiB, max threads/CU %d, cooperative launch %d\n",
           p.gcnArchName, p.multiProcessorCount, p.sharedMemPerBlock / 1024, p.maxSharedMemoryPerMultiProcessor / 1024,
           p.l2CacheSize / 1024, p.maxThreadsPerMultiProcessor, coop);
    unsigned * ctr; float * out; CK(hipMalloc(&ctr, 64)); CK(hipMalloc(&out, 4));
    hipEvent_t e0, e1; CK(hipEventCreate(&e0)); CK(hipEventCreate(&e1));

    printf("\n-- grid barrier (persistent blocks, all co-resident)\n");
    for (int th : {1024, 512, 256, 128}) {
        int occ = 0; CK(hipOccupancyMaxActiveBlocksPerMultiprocessor(&occ, k_barriers, th, 0));
        for (int per_cu : {1, 2, 4}) {
            if (per_cu > occ) continue;
            const int nb = per_cu * p.multiProcessorCount, iters = 20000;
            std::vector<float> v;
            for (int r = 0; r < 5; r++) {
                CK(hipMemset(ctr, 0, 64));
                CK(hipEventRecord(e0)); k_barriers<<<nb, th>>>(ctr, iters); CK(hipEventRecord(e1));
                v.push_back(time_ms(e0, e1) * 1000.0f / iters);
            }
            std::sort(v.begin(), v.end());
            printf("  %4d threads x %3d blocks (occupancy %d/CU): %.2f us per barrier (median of 5)\n", th, nb, occ, v[2]);
        }
    }

    const size_t total = 1ull << 30;  // 1 GiB of "weights"
    float4 * w; CK(hipMalloc(&w, total)); CK(hipMemset(w, 1, total));
    printf("\n-- streaming 1 GiB in stages with a barrier after each (256 threads x 4 blocks/CU)\n");
    const int nb = 4 * p.multiProcessorCount, th = 256;
    for (size_t sb : {(size_t) 256 << 10, (size_t) 1 << 20, (size_t) 4 << 20, (size_t) 16 << 20}) {
        const int stages = (int) (total / sb);
        for (int ahead = 0; ahead < 2; ahead++) {
            std::vector<float> v;
            for (int r = 0; r < 5; r++) {
                CK(hipMemset(ctr, 0, 64));
                CK(hipEventRecord(e0));
                if (ahead) k_stages<true><<<nb, th>>>(w, sb / 16, stages, ctr, out); else k_stages<false><<<nb, th>>>(w, sb / 16, stages, ctr, out);
                CK(hipEventRecord(e1));
                v.push_back((float) (total / (time_ms(e0, e1) * 1e6)));
            }
            std::sort(v.begin(), v.end());
            printf("  stage %6zu KiB x %5d, next loads %s the barrier: %6.1f GB/s\n", sb >> 10, stages, ahead ? "before" : "after ", v[2]);
        }
    }
    {
        std::vector<float> v;
        for (int r = 0; r < 5; r++) { CK(hipEventRecord(e0)); k_read<<<4096, 256>>>(w, total / 16, out); CK(hipEventRecord(e1)); v.push_back((float) (total / (time_ms(e0, e1) * 1e6))); }
        std::sort(v.begin(), v.end());
        printf("  one kernel, no barrier (4096 x 256): %6.1f GB/s\n", v[2]);
    }

    printf("\n-- re-reading a buffer right after reading it (MALL 32 MB): cold = after reading 1 GiB of other data\n");
    for (size_t mb : {8, 16, 24, 32, 48, 96}) {
        const size_t n = (mb << 20) / 16;
        float cold = 0, warm = 0;
        for (int r = 0; r < 5; r++) {
            k_read<<<4096, 256>>>(w + n, total / 16 - n, out);  // evict
            CK(hipEventRecord(e0)); k_read<<<1024, 256>>>(w, n, out); CK(hipEventRecord(e1)); cold += (mb << 20) / (time_ms(e0, e1) * 1e6);
            CK(hipEventRecord(e0)); k_read<<<1024, 256>>>(w, n, out); CK(hipEventRecord(e1)); warm += (mb << 20) / (time_ms(e0, e1) * 1e6);
        }
        printf("  %3zu MiB: cold %6.1f GB/s, again %6.1f GB/s\n", mb, cold / 5, warm / 5);
    }
    return 0;
}
