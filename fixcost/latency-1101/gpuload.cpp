// keep the GPU busy streaming memory for argv[1] seconds (decode-like: bandwidth-bound kernels back to back)
#include <hip/hip_runtime.h>
#include <chrono>
#include <cstdio>
#include <cstdlib>
__global__ void k_copy(const float4 * a, float4 * b, size_t n) { for (size_t i = blockIdx.x*(size_t)blockDim.x + threadIdx.x; i < n; i += (size_t)gridDim.x*blockDim.x) b[i] = a[i]; }
int main(int argc, char ** argv) {
    const double secs = argc > 1 ? atof(argv[1]) : 20;
    const size_t n = (256u << 20) / sizeof(float4);
    float4 *a, *b; hipMalloc(&a, n*sizeof(float4)); hipMalloc(&b, n*sizeof(float4));
    auto t0 = std::chrono::steady_clock::now(); long k = 0;
    while (std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count() < secs) {
        for (int i = 0; i < 20; i++) k_copy<<<1024, 256>>>(a, b, n);
        hipDeviceSynchronize(); k += 20;
    }
    printf("gpuload: %ld kernels, %.1f GB/s\n", k, k * 2.0 * n * sizeof(float4) / 1e9 / secs);
}
