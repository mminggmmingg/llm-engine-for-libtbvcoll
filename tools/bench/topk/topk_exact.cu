// topk exactness + timing: general ggml kernel and lean kernel, outputs dumped to a file for comparison across builds
#include "ggml-cuda/common.cuh"
#include "ggml-cuda/topk-moe.cuh"
#include "topk_kernel3.inc"
#include <cstdio>
#include <vector>
#include <random>
int main(int argc, char ** argv) {
    const int NE = 512, K = 10;
    FILE * f = fopen(argv[1], "wb");
    float *dl, *dw; int *di; hipMalloc(&dl, NE*8*4); hipMalloc(&dw, K*8*4); hipMalloc(&di, NE*8*4);
    std::mt19937 rng(77); std::normal_distribution<float> nd(0.f, 2.f);
    topk_moe_config cfg{}; 
    for (int rows : {1, 4, 8}) for (int norm = 0; norm < 2; norm++) for (int t = 0; t < 200; t++) {
        cfg.with_norm = norm;
        const float clamp = norm ? 6.103515625e-5f : -INFINITY;
        std::vector<float> hl(NE*rows); for (auto & x : hl) x = nd(rng);
        if (t % 5 == 0) for (int j = 0; j < NE*rows; j += 3) hl[j] = hl[(j*7) % (NE*rows)];
        if (t % 11 == 0) for (int j = 0; j < NE*rows; j++) hl[j] = (j % 13) * 0.5f;
        for (int kern = 0; kern < 2; kern++) {
            hipMemcpy(dl, hl.data(), NE*rows*4, hipMemcpyHostToDevice);
            dim3 grid((rows + TOPK_MOE_ROWS_PER_BLOCK - 1)/TOPK_MOE_ROWS_PER_BLOCK), block(WARP_SIZE, TOPK_MOE_ROWS_PER_BLOCK);
            if (kern == 0) topk_moe_cuda<512, false><<<grid, block>>>(dl, dw, di, nullptr, rows, K, clamp, 1.0f, cfg);
            else           topk_moe_softmax_cuda<512><<<grid, block>>>(dl, dw, di, rows, K, clamp, 1.0f, cfg.with_norm);
            std::vector<float> w(K*rows); std::vector<int> id(NE*rows);
            hipMemcpy(w.data(), dw, K*rows*4, hipMemcpyDeviceToHost); hipMemcpy(id.data(), di, NE*rows*4, hipMemcpyDeviceToHost);
            fwrite(w.data(), 4, K*rows, f);
            for (int r = 0; r < rows; r++) fwrite(&id[r*NE], 4, K, f);
        }
    }
    fclose(f);
    return 0;
}
