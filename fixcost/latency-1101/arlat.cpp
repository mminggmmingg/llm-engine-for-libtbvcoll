// GPU-side pieces of the decode allreduce on gfx1151 (one node, no network):
//  send: subgraph end -> partial in pinned host memory -> host sees it
//  recv: host writes the flag -> stream released -> peer partial on the GPU -> add done
#include <hip/hip_runtime.h>
#include <algorithm>
#include <chrono>
#include <cstdio>
#include <thread>
#include <vector>
#define CK(x) do { hipError_t e_ = (x); if (e_ != hipSuccess) { printf("%s:%d %s\n", __FILE__, __LINE__, hipGetErrorString(e_)); exit(1); } } while (0)
static const int N = 2560;  // floats in a decode partial (10 KB)
static double now_us() { return std::chrono::duration<double, std::micro>(std::chrono::steady_clock::now().time_since_epoch()).count(); }
__global__ void k_write(float * d, int n, float v) { int i = blockIdx.x*blockDim.x + threadIdx.x; if (i < n) d[i] = v + i; }
__global__ void k_add(float * d, const float * s, int n) { int i = blockIdx.x*blockDim.x + threadIdx.x; if (i < n) d[i] += s[i]; }
__global__ void k_mark(unsigned * done, unsigned v) { if (threadIdx.x == 0 && blockIdx.x == 0) { __threadfence_system(); __hip_atomic_store(done, v, __ATOMIC_RELEASE, __HIP_MEMORY_SCOPE_SYSTEM); } }
__global__ void k_add_mark(float * d, const float * s, int n, unsigned * done, unsigned v) {
    int i = blockIdx.x*blockDim.x + threadIdx.x; if (i < n) d[i] += s[i];
    __syncthreads();
    // last block marks (one block per 256 elements; good enough for timing with a grid-wide counter)
    if (threadIdx.x == 0) { __threadfence_system(); unsigned prev = atomicAdd(&done[1], 1u); if (prev == gridDim.x - 1) { done[1] = 0; __hip_atomic_store(done, v, __ATOMIC_RELEASE, __HIP_MEMORY_SCOPE_SYSTEM); } }
}
__global__ void k_spin_add_mark(volatile unsigned * flag, unsigned seq, float * d, const float * s, int n, unsigned * done, unsigned v) {
    if (threadIdx.x == 0) { while (__hip_atomic_load((unsigned *) flag, __ATOMIC_ACQUIRE, __HIP_MEMORY_SCOPE_SYSTEM) < seq) { __builtin_amdgcn_s_sleep(1); } }
    __syncthreads();
    int i = blockIdx.x*blockDim.x + threadIdx.x; if (i < n) d[i] += s[i];
    __syncthreads();
    if (threadIdx.x == 0) { __threadfence_system(); unsigned prev = atomicAdd(&done[1], 1u); if (prev == gridDim.x - 1) { done[1] = 0; __hip_atomic_store(done, v, __ATOMIC_RELEASE, __HIP_MEMORY_SCOPE_SYSTEM); } }
}
static void stats(const char * name, std::vector<double> & v) {
    std::sort(v.begin(), v.end());
    printf("%-58s p10 %6.1f  med %6.1f  p90 %6.1f us\n", name, v[v.size()/10], v[v.size()/2], v[v.size()*9/10]);
}
int main() {
    const int it = 2000, nb = (N + 255)/256;
    hipStream_t st; CK(hipStreamCreateWithFlags(&st, hipStreamNonBlocking));
    float *d, *d2, *h_p, *h_m; unsigned * flags;
    CK(hipMalloc(&d, N*4)); CK(hipMalloc(&d2, N*4));
    CK(hipHostMalloc((void **) &h_p, N*4, hipHostMallocPortable));                    // like ggml's pinned host buffer
    CK(hipHostMalloc((void **) &h_m, N*4, hipHostMallocMapped | hipHostMallocCoherent)); // GPU-visible zero-copy
    CK(hipHostMalloc((void **) &flags, 64, hipHostMallocMapped | hipHostMallocCoherent));
    float * h_m_dev; CK(hipHostGetDevicePointer((void **) &h_m_dev, h_m, 0));
    unsigned * flags_dev; CK(hipHostGetDevicePointer((void **) &flags_dev, flags, 0));
    volatile unsigned * flag = flags, * done = flags + 4;
    // warm up
    for (int i = 0; i < 50; i++) { k_write<<<nb, 256, 0, st>>>(d, N, 1); CK(hipMemcpyAsync(h_p, d, N*4, hipMemcpyDeviceToHost, st)); CK(hipStreamSynchronize(st)); }
    std::vector<double> a, b, c;
    for (int i = 0; i < it; i++) {
        double t0 = now_us(); k_write<<<nb, 256, 0, st>>>(d, N, i); CK(hipStreamSynchronize(st)); a.push_back(now_us() - t0);
        t0 = now_us(); k_write<<<nb, 256, 0, st>>>(d, N, i); CK(hipMemcpyAsync(h_p, d, N*4, hipMemcpyDeviceToHost, st)); CK(hipStreamSynchronize(st)); b.push_back(now_us() - t0);
        t0 = now_us(); k_write<<<nb, 256, 0, st>>>(h_m_dev, N, i); CK(hipStreamSynchronize(st)); c.push_back(now_us() - t0);
    }
    printf("send side (launch -> host has the partial):\n");
    stats("  kernel, sync", a); stats("  kernel, D2H copy 10 KB (SDMA), sync  [engine now]", b); stats("  kernel writes pinned host directly, sync", c);
    // spin on a host flag written by the GPU instead of hipStreamSynchronize
    std::vector<double> e;
    for (int i = 0; i < it; i++) {
        unsigned v = 1000000 + i;
        double t0 = now_us(); k_write<<<nb, 256, 0, st>>>(h_m_dev, N, i); k_mark<<<1, 64, 0, st>>>((unsigned *) flags_dev + 4, v);
        while (*done != v) {} e.push_back(now_us() - t0);
    }
    CK(hipStreamSynchronize(st));
    stats("  kernel writes pinned host + marker, host spins on marker", e);

    printf("recv side (host writes flag -> add finished on GPU):\n");
    std::vector<double> r0, r1, r2, r3;
    unsigned seq = 1;
    flags[8] = 0;
    for (int i = 0; i < it; i++) {
        for (int m = 0; m < 4; m++) {
            seq++; unsigned v = seq | 0x80000000u;
            if (m == 0) { CK(hipStreamWaitValue32(st, (void *) flag, seq, hipStreamWaitValueGte, 0xFFFFFFFF)); k_mark<<<1, 64, 0, st>>>((unsigned *) flags_dev + 4, v); }
            if (m == 1) { CK(hipStreamWaitValue32(st, (void *) flag, seq, hipStreamWaitValueGte, 0xFFFFFFFF)); CK(hipMemcpyAsync(d2, h_p, N*4, hipMemcpyHostToDevice, st)); k_add_mark<<<nb, 256, 0, st>>>(d, d2, N, (unsigned *) flags_dev + 4, v); }
            if (m == 2) { CK(hipStreamWaitValue32(st, (void *) flag, seq, hipStreamWaitValueGte, 0xFFFFFFFF)); k_add_mark<<<nb, 256, 0, st>>>(d, h_m_dev, N, (unsigned *) flags_dev + 4, v); }
            if (m == 3) { k_spin_add_mark<<<nb, 256, 0, st>>>((volatile unsigned *) flags_dev, seq, d, h_m_dev, N, (unsigned *) flags_dev + 4, v); }
            std::this_thread::sleep_for(std::chrono::microseconds(300));   // the GPU is now parked on the wait
            double t0 = now_us(); __atomic_store_n((unsigned *) flag, seq, __ATOMIC_SEQ_CST);
            while (*done != v) {}
            double t = now_us() - t0;
            (m == 0 ? r0 : m == 1 ? r1 : m == 2 ? r2 : r3).push_back(t);
            CK(hipStreamSynchronize(st));
        }
    }
    stats("  stream wait, marker kernel (release latency)", r0);
    stats("  stream wait, H2D copy 10 KB (SDMA), add  [engine now]", r1);
    stats("  stream wait, add reads pinned host directly", r2);
    stats("  one kernel spins on the host flag, then add", r3);
    return 0;
}
