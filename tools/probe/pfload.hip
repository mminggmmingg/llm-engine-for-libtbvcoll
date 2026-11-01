// GPU 읽기 부하 + 단계별 CPU 바쁜 스레드: 펌웨어의 CPU/GPU 전력 배분을 보기 위한 시험 (단계마다 GB/s 출력)
//   pfload <단계초=12>   단계: GPU만 | GPU+스핀1 | GPU+스핀2 | GPU만 | 스핀1만
#include <hip/hip_runtime.h>
#include <atomic>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <thread>
#include <vector>
__global__ void rd(const float4 * __restrict__ a, size_t n, float * out) {
    float4 s = {0, 0, 0, 0};
    for (size_t i = blockIdx.x * (size_t) blockDim.x + threadIdx.x; i < n; i += (size_t) gridDim.x * blockDim.x) {
        float4 v = a[i]; s.x += v.x; s.y += v.y; s.z += v.z; s.w += v.w;
    }
    if (s.x + s.y + s.z + s.w == 12345.f) out[0] = s.x;
}
static double now() { return std::chrono::duration<double>(std::chrono::steady_clock::now().time_since_epoch()).count(); }
int main(int argc, char ** argv) {
    const double ph = argc > 1 ? atof(argv[1]) : 12;
    hipSetDeviceFlags(hipDeviceScheduleBlockingSync);  // 기다리는 본 스레드가 CPU 를 돌리지 않게
    const size_t sz = 1ull << 30; char * a; float * o;
    hipMalloc(&a, sz); hipMalloc(&o, 4); hipMemset(a, 1, sz); hipDeviceSynchronize();
    std::atomic<int> nspin{0}; std::atomic<bool> stop{false};
    std::vector<std::thread> th;
    for (int k = 0; k < 2; k++) th.emplace_back([&, k] { while (!stop) { if (nspin > k) { for (int i = 0; i < 1000; i++) __builtin_ia32_pause(); } else std::this_thread::sleep_for(std::chrono::milliseconds(1)); } });
    struct P { const char * name; bool gpu; int spin; } ps[] = {{"gpu", 1, 0}, {"gpu+spin1", 1, 1}, {"gpu+spin2", 1, 2}, {"gpu", 1, 0}, {"spin1", 0, 1}};
    const double t0 = now();
    for (const P & p : ps) {
        nspin = p.spin; const double te = now() + ph; double tl = now(); size_t bytes = 0;
        while (now() < te) {
            if (p.gpu) { for (int r = 0; r < 8; r++) rd<<<4096, 256>>>((const float4 *) a, sz / 16, o); hipDeviceSynchronize(); bytes += 8 * sz; }
            else std::this_thread::sleep_for(std::chrono::milliseconds(50));
            if (now() - tl >= 1.0) { printf("%6.1f %-10s %.1f GB/s\n", now() - t0, p.name, bytes / (now() - tl) / 1e9); fflush(stdout); tl = now(); bytes = 0; }
        }
    }
    stop = true; for (auto & t : th) t.join();
    return 0;
}
