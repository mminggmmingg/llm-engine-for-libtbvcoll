// per-kernel floor: GPU time per tiny kernel when kernels run back to back on one stream, as a HIP graph and as
// direct launches. Decode issues ~3200 such kernels per token, so floor x count is a lower bound of their cost.
//   kfloor [kernels per graph=3200] [replays=50]
#include <hip/hip_runtime.h>
#include <chrono>
#include <cstdio>
#include <cstdlib>
__global__ void k_empty(float * p) { if (p == nullptr && threadIdx.x == 12345) p[0] = 0; }
// y = x * a + b over n floats, like a small elementwise op on a 2560..10240 activation
__global__ void k_ew(const float * x, float * y, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) y[i] = x[i] * 1.0001f + 0.5f;
}
static double now_us() { return std::chrono::duration<double, std::micro>(std::chrono::steady_clock::now().time_since_epoch()).count(); }
int main(int argc, char ** argv) {
    const int N = argc > 1 ? atoi(argv[1]) : 3200, R = argc > 2 ? atoi(argv[2]) : 50;
    hipStream_t s; hipStreamCreateWithFlags(&s, hipStreamNonBlocking);
    float *a, *b; hipMalloc(&a, 1 << 22); hipMalloc(&b, 1 << 22); hipMemset(a, 0, 1 << 22);
    hipEvent_t e0, e1; hipEventCreate(&e0); hipEventCreate(&e1);
    struct V { const char * name; int n; } vs[] = {{"empty 1x64", 0}, {"elementwise 2560", 2560}, {"elementwise 10240", 10240}, {"elementwise 262144", 262144}};
    for (const V & v : vs) {
        auto launch = [&](int i) {
            if (v.n == 0) k_empty<<<1, 64, 0, s>>>(nullptr);
            else k_ew<<<(v.n + 255) / 256, 256, 0, s>>>(i & 1 ? b : a, i & 1 ? a : b, v.n);
        };
        hipGraph_t g; hipGraphExec_t ge;
        hipStreamBeginCapture(s, hipStreamCaptureModeRelaxed);
        for (int i = 0; i < N; i++) launch(i);
        hipStreamEndCapture(s, &g); hipGraphInstantiate(&ge, g, nullptr, nullptr, 0);
        for (int w = 0; w < 5; w++) hipGraphLaunch(ge, s);
        hipStreamSynchronize(s);
        double h0 = now_us(); hipEventRecord(e0, s);
        for (int r = 0; r < R; r++) hipGraphLaunch(ge, s);
        hipEventRecord(e1, s); hipEventSynchronize(e1); double h1 = now_us();
        float ms_g; hipEventElapsedTime(&ms_g, e0, e1);
        for (int i = 0; i < N; i++) launch(i);
        hipStreamSynchronize(s);
        hipEventRecord(e0, s);
        for (int r = 0; r < R; r++) for (int i = 0; i < N; i++) launch(i);
        hipEventRecord(e1, s); hipEventSynchronize(e1);
        float ms_d; hipEventElapsedTime(&ms_d, e0, e1);
        printf("%-20s graph %.2f us/kernel (%.2f ms per %d, host %.2f ms/replay) | direct %.2f us/kernel\n", v.name,
               ms_g * 1e3 / (R * N), ms_g / R, N, (h1 - h0) / 1e3 / R, ms_d * 1e3 / (R * N));
        hipGraphExecDestroy(ge); hipGraphDestroy(g);
    }
    return 0;
}
