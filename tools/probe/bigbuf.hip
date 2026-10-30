// Read bandwidth of 512 MiB windows inside one large hipMalloc buffer (like the 65.8 GB model buffer) versus a
// small buffer read repeatedly (like test-backend-ops). Each window is read once ("cold") then again ("warm").
//   bigbuf [GiB=60]
#include <hip/hip_runtime.h>
#include <cstdio>
#include <cstdlib>
#define CK(x) do { hipError_t e = (x); if (e != hipSuccess) { printf("%s -> %s\n", #x, hipGetErrorString(e)); return 1; } } while (0)
__global__ void rd(const float4 * __restrict__ a, size_t n, float * out) {
    float4 s = {0, 0, 0, 0};
    for (size_t i = blockIdx.x * (size_t) blockDim.x + threadIdx.x; i < n; i += (size_t) gridDim.x * blockDim.x) {
        float4 v = a[i]; s.x += v.x; s.y += v.y; s.z += v.z; s.w += v.w;
    }
    if (s.x + s.y + s.z + s.w == 12345.f) out[0] = s.x;
}
int main(int argc, char ** argv) {
    const size_t gib = argc > 1 ? atoll(argv[1]) : 60, big = gib << 30, win = 512ull << 20;
    char * a; char * small; float * o;
    CK(hipMalloc(&a, big)); CK(hipMalloc(&small, win)); CK(hipMalloc(&o, 4));
    CK(hipMemset(a, 1, big)); CK(hipMemset(small, 1, win));
    hipEvent_t e0, e1; CK(hipEventCreate(&e0)); CK(hipEventCreate(&e1));
    auto time_rd = [&](const char * p) {
        hipEventRecord(e0); rd<<<4096, 256>>>((const float4 *) p, win / 16, o); hipEventRecord(e1); hipEventSynchronize(e1);
        float ms; hipEventElapsedTime(&ms, e0, e1); return win / (ms * 1e6);
    };
    for (int r = 0; r < 3; r++) printf("small buffer        : %.1f GB/s\n", time_rd(small));
    for (size_t off = 0; off + win <= big; off += big / 6) {
        const double c = time_rd(a + off), w = time_rd(a + off);
        printf("big buffer @ %5.1f GiB: cold %.1f GB/s, warm %.1f GB/s\n", off / double(1 << 30), c, w);
    }
    // windows read one after another, like successive layers' weights within a token
    hipEventRecord(e0);
    const size_t n_seq = 8ull << 30;
    for (size_t off = big - n_seq; off + win <= big; off += win) rd<<<4096, 256>>>((const float4 *) (a + off), win / 16, o);
    hipEventRecord(e1); hipEventSynchronize(e1);
    float ms; hipEventElapsedTime(&ms, e0, e1);
    printf("big buffer, last 8 GiB as 512 MiB windows back to back: %.1f GB/s\n", n_seq / (ms * 1e6));
    return 0;
}
