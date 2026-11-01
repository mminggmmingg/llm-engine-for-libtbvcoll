// hipMemcpy2DAsync H2D from pageable memory, pitch == width (contiguous both sides): time by width
#include <hip/hip_runtime.h>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <vector>
int main(int argc, char ** argv) {
    const size_t rows = argc > 2 ? atoll(argv[2]) : 1310720;
    for (int a = 1; a < argc && a == 1; a++) {}
    const int widths[] = {144, 162, 180, 198, 216, 126, 160, 164};
    for (int w : widths) {
        const size_t n = (size_t) w * rows;
        std::vector<char> h(n, 1);
        void * d = nullptr;
        if (hipMalloc(&d, n) != hipSuccess) { printf("malloc fail\n"); return 1; }
        hipStream_t s; hipStreamCreate(&s);
        auto t0 = std::chrono::steady_clock::now();
        hipError_t e = hipMemcpy2DAsync(d, w, h.data(), w, w, rows, hipMemcpyHostToDevice, s);
        hipStreamSynchronize(s);
        auto t1 = std::chrono::steady_clock::now();
        auto t2 = t1;
        hipMemcpyAsync(d, h.data(), n, hipMemcpyHostToDevice, s); hipStreamSynchronize(s);
        auto t3 = std::chrono::steady_clock::now();
        printf("width %3d rows %zu (%.0f MB): 2D %8.1f ms (%s)  1D %6.1f ms\n", w, rows, n / 1e6,
               std::chrono::duration<double, std::milli>(t1 - t0).count(), hipGetErrorString(e),
               std::chrono::duration<double, std::milli>(t3 - t2).count());
        hipStreamDestroy(s); hipFree(d);
        if (std::chrono::duration<double>(t1 - t0).count() > 60) break;
    }
}
