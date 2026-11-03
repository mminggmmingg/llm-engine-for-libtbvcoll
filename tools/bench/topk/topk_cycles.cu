// topk_moe microbench: the ggml kernel (copied verbatim) vs a variant with DPP lane exchanges instead of ds_bpermute
#include "ggml-cuda/common.cuh"
#include "ggml-cuda/topk-moe.cuh"
#include "topk_kernel.inc"
#include "topk_kernel_ts.inc"
#include <cstdio>
#include <vector>
#include <random>
#include <cstring>

// lane ^ mask exchange inside a wave32 without LDS: DPP row_xmask (masks 1..8) or permlanex16 (mask 16)
template <int mask>
static __device__ __forceinline__ int xor_dpp_i(int v) {
    if constexpr (mask == 16) {
        return __builtin_amdgcn_permlanex16(v, v, 0x76543210, 0xfedcba98, false, false);
    } else {
        return __builtin_amdgcn_update_dpp(v, v, 0x160 | mask, 0xf, 0xf, false);
    }
}
template <int mask>
static __device__ __forceinline__ float xor_dpp_f(float v) { return __int_as_float(xor_dpp_i<mask>(__float_as_int(v))); }

static __device__ __forceinline__ float wmax_dpp(float x) {
    x = fmaxf(x, xor_dpp_f<16>(x)); x = fmaxf(x, xor_dpp_f<8>(x)); x = fmaxf(x, xor_dpp_f<4>(x));
    x = fmaxf(x, xor_dpp_f<2>(x));  x = fmaxf(x, xor_dpp_f<1>(x));
    return x;
}
static __device__ __forceinline__ float wsum_dpp(float x) {
    x += xor_dpp_f<16>(x); x += xor_dpp_f<8>(x); x += xor_dpp_f<4>(x); x += xor_dpp_f<2>(x); x += xor_dpp_f<1>(x);
    return x;
}
template <int mask>
static __device__ __forceinline__ void argmax_step(float & v, int & e) {
    const float ov = xor_dpp_f<mask>(v);
    const int   oe = xor_dpp_i<mask>(e);
    if (ov > v || (ov == v && oe < e)) { v = ov; e = oe; }
}

// same algorithm as topk_moe_cuda<n_experts, false> for softmax + with_norm (no bias, no groups), DPP exchanges
template <int n_experts>
__launch_bounds__(TOPK_MOE_ROWS_PER_BLOCK * WARP_SIZE, 1)
__global__ void topk_moe_dpp(const float * logits, float * weights, int32_t * ids, const int n_rows, const int n_expert_used,
                             const float clamp_val, const float scale_val, long long * ts = nullptr) {
    const long long c0 = clock64();
    const int row = blockIdx.x * blockDim.y + threadIdx.y;
    if (row >= n_rows) return;
    logits += n_experts * row; weights += n_expert_used * row; ids += n_experts * row;
    constexpr int ept = n_experts / WARP_SIZE;
    float wt[ept];
#pragma unroll
    for (int i = 0; i < n_experts; i += WARP_SIZE) wt[i / WARP_SIZE] = logits[i + threadIdx.x];
    __syncthreads();
    // softmax_warp_inplace<ept, false>
    float max_val = -INFINITY;
#pragma unroll
    for (int i = 0; i < ept; i++) max_val = max(max_val, wt[i]);
    max_val = wmax_dpp(max_val);
    float sum = 0.f;
#pragma unroll
    for (int i = 0; i < ept; i++) { const float val = expf(wt[i] - max_val); wt[i] = val; sum += val; }
    sum = wsum_dpp(sum);
    const float inv_sum = 1.0f / sum;
#pragma unroll
    for (int i = 0; i < ept; i++) wt[i] *= inv_sum;
#pragma unroll
    for (int i = 0; i < ept; i++) if (__isnanf(wt[i])) wt[i] = -FLT_MAX;
    float wt_sum = 0.f;
    float output_weights[ept];
#pragma unroll
    for (int i = 0; i < ept; i++) output_weights[i] = 0.f;
    for (int k = 0; k < n_expert_used; k++) {
        float mv = wt[0]; int me = threadIdx.x;
#pragma unroll
        for (int i = 1; i < ept; i++) { if (wt[i] > mv) { mv = wt[i]; me = threadIdx.x + i * WARP_SIZE; } }
        argmax_step<16>(mv, me); argmax_step<8>(mv, me); argmax_step<4>(mv, me); argmax_step<2>(mv, me); argmax_step<1>(mv, me);
        if ((me & (WARP_SIZE - 1)) == threadIdx.x) wt[me / WARP_SIZE] = -INFINITY;
        if ((k & (WARP_SIZE - 1)) == threadIdx.x) output_weights[k / WARP_SIZE] = mv;
        if ((me & (WARP_SIZE - 1)) == threadIdx.x) { ids[k] = me; wt_sum += mv; }
    }
    wt_sum = wsum_dpp(wt_sum);
    wt_sum = max(wt_sum, clamp_val);
    const float inv = 1.0f / wt_sum;
    for (int i = 0; i < ept; i++) output_weights[i] *= inv;
#pragma unroll
    for (int i = 0; i < ept; i++) { const int idx = i * WARP_SIZE + threadIdx.x; if (idx < n_expert_used) weights[idx] = output_weights[i] * scale_val; }
    if (ts && threadIdx.x == 0 && row == 0) { ts[0] = clock64() - c0; }
}

template <int n_experts>
__launch_bounds__(TOPK_MOE_ROWS_PER_BLOCK * WARP_SIZE, 1)
__global__ void topk_moe_dpp_t(const float * logits, float * weights, int32_t * ids, const int n_rows, const int n_expert_used,
                             const float clamp_val, const float scale_val, long long * ts) {
    long long t0 = wall_clock64(); long long c0 = clock64();
    const int row = blockIdx.x * blockDim.y + threadIdx.y;
    if (row >= n_rows) return;
    logits += n_experts * row; weights += n_expert_used * row; ids += n_experts * row;
    constexpr int ept = n_experts / WARP_SIZE;
    float wt[ept];
#pragma unroll
    for (int i = 0; i < n_experts; i += WARP_SIZE) wt[i / WARP_SIZE] = logits[i + threadIdx.x];
    long long c1 = clock64();
    __syncthreads();
    // softmax_warp_inplace<ept, false>
    float max_val = -INFINITY;
#pragma unroll
    for (int i = 0; i < ept; i++) max_val = max(max_val, wt[i]);
    max_val = wmax_dpp(max_val);
    float sum = 0.f;
#pragma unroll
    for (int i = 0; i < ept; i++) { const float val = expf(wt[i] - max_val); wt[i] = val; sum += val; }
    sum = wsum_dpp(sum);
    const float inv_sum = 1.0f / sum;
#pragma unroll
    for (int i = 0; i < ept; i++) wt[i] *= inv_sum;
#pragma unroll
    for (int i = 0; i < ept; i++) if (__isnanf(wt[i])) wt[i] = -FLT_MAX;
    long long c2 = clock64();
    float wt_sum = 0.f;
    float output_weights[ept];
#pragma unroll
    for (int i = 0; i < ept; i++) output_weights[i] = 0.f;
    for (int k = 0; k < n_expert_used; k++) {
        float mv = wt[0]; int me = threadIdx.x;
#pragma unroll
        for (int i = 1; i < ept; i++) { if (wt[i] > mv) { mv = wt[i]; me = threadIdx.x + i * WARP_SIZE; } }
        argmax_step<16>(mv, me); argmax_step<8>(mv, me); argmax_step<4>(mv, me); argmax_step<2>(mv, me); argmax_step<1>(mv, me);
        if ((me & (WARP_SIZE - 1)) == threadIdx.x) wt[me / WARP_SIZE] = -INFINITY;
        if ((k & (WARP_SIZE - 1)) == threadIdx.x) output_weights[k / WARP_SIZE] = mv;
        if ((me & (WARP_SIZE - 1)) == threadIdx.x) { ids[k] = me; wt_sum += mv; }
    }
    long long c3 = clock64();
    wt_sum = wsum_dpp(wt_sum);
    wt_sum = max(wt_sum, clamp_val);
    const float inv = 1.0f / wt_sum;
    for (int i = 0; i < ept; i++) output_weights[i] *= inv;
#pragma unroll
    for (int i = 0; i < ept; i++) { const int idx = i * WARP_SIZE + threadIdx.x; if (idx < n_expert_used) weights[idx] = output_weights[i] * scale_val; }
    long long c4 = clock64();
    if (threadIdx.x == 0 && row == 0) { ts[0]=c0; ts[1]=c1; ts[2]=c2; ts[3]=c3; ts[4]=c4; ts[5]=t0; ts[6]=wall_clock64(); }
}

template <int n_experts>
__launch_bounds__(TOPK_MOE_ROWS_PER_BLOCK * WARP_SIZE, 1)
__global__ void topk_moe_v2(const float * logits, float * weights, int32_t * ids, const int n_rows, const int n_expert_used,
                             const float clamp_val, const float scale_val, long long * ts = nullptr) {
    const long long c0 = clock64();
    const int row = blockIdx.x * blockDim.y + threadIdx.y;
    if (row >= n_rows) return;
    logits += n_experts * row; weights += n_expert_used * row; ids += n_experts * row;
    constexpr int ept = n_experts / WARP_SIZE;
    float wt[ept];
#pragma unroll
    for (int i = 0; i < n_experts; i += WARP_SIZE) wt[i / WARP_SIZE] = logits[i + threadIdx.x];
    __syncthreads();
    // softmax_warp_inplace<ept, false>
    float max_val = -INFINITY;
#pragma unroll
    for (int i = 0; i < ept; i++) max_val = max(max_val, wt[i]);
    max_val = wmax_dpp(max_val);
    float sum = 0.f;
#pragma unroll
    for (int i = 0; i < ept; i++) { const float val = expf(wt[i] - max_val); wt[i] = val; sum += val; }
    sum = wsum_dpp(sum);
    const float inv_sum = 1.0f / sum;
#pragma unroll
    for (int i = 0; i < ept; i++) wt[i] *= inv_sum;
#pragma unroll
    for (int i = 0; i < ept; i++) if (__isnanf(wt[i])) wt[i] = -FLT_MAX;
    float wt_sum = 0.f;
    float output_weights[ept];
#pragma unroll
    for (int i = 0; i < ept; i++) output_weights[i] = 0.f;
    for (int k = 0; k < n_expert_used; k++) {
        float mv = wt[0]; int me = threadIdx.x;
#pragma unroll
        for (int i = 1; i < ept; i++) { if (wt[i] > mv) { mv = wt[i]; me = threadIdx.x + i * WARP_SIZE; } }
        argmax_step<16>(mv, me); argmax_step<8>(mv, me); argmax_step<4>(mv, me); argmax_step<2>(mv, me); argmax_step<1>(mv, me);
        // every lane holds the same winner: make it scalar so the array updates need no per-lane indexing
        me = __builtin_amdgcn_readfirstlane(me);
        mv = __int_as_float(__builtin_amdgcn_readfirstlane(__float_as_int(mv)));
#pragma unroll
        for (int i = 0; i < ept; i++) {
            if (i == me / WARP_SIZE && (me & (WARP_SIZE - 1)) == threadIdx.x) wt[i] = -INFINITY;
            if (i == k / WARP_SIZE && (k & (WARP_SIZE - 1)) == threadIdx.x) output_weights[i] = mv;
        }
        if ((me & (WARP_SIZE - 1)) == threadIdx.x) { ids[k] = me; wt_sum += mv; }
    }
    wt_sum = wsum_dpp(wt_sum);
    wt_sum = max(wt_sum, clamp_val);
    const float inv = 1.0f / wt_sum;
    for (int i = 0; i < ept; i++) output_weights[i] *= inv;
#pragma unroll
    for (int i = 0; i < ept; i++) { const int idx = i * WARP_SIZE + threadIdx.x; if (idx < n_expert_used) weights[idx] = output_weights[i] * scale_val; }
    if (ts && threadIdx.x == 0 && row == 0) { ts[0] = clock64() - c0; }
}

template <int n_experts>
__launch_bounds__(TOPK_MOE_ROWS_PER_BLOCK * WARP_SIZE, 1)
__global__ void topk_moe_v3(const float * logits, float * weights, int32_t * ids, const int n_rows, const int n_expert_used,
                             const float clamp_val, const float scale_val, long long * ts = nullptr) {
    const long long c0 = clock64();
    const int row = blockIdx.x * blockDim.y + threadIdx.y;
    if (row >= n_rows) return;
    logits += n_experts * row; weights += n_expert_used * row; ids += n_experts * row;
    constexpr int ept = n_experts / WARP_SIZE;
    float wt[ept];
#pragma unroll
    for (int i = 0; i < n_experts; i += WARP_SIZE) wt[i / WARP_SIZE] = logits[i + threadIdx.x];
    __syncthreads();
    // softmax_warp_inplace<ept, false>
    float max_val = -INFINITY;
#pragma unroll
    for (int i = 0; i < ept; i++) max_val = max(max_val, wt[i]);
    max_val = wmax_dpp(max_val);
    float sum = 0.f;
#pragma unroll
    for (int i = 0; i < ept; i++) { const float val = expf(wt[i] - max_val); wt[i] = val; sum += val; }
    sum = wsum_dpp(sum);
    const float inv_sum = 1.0f / sum;
#pragma unroll
    for (int i = 0; i < ept; i++) wt[i] *= inv_sum;
#pragma unroll
    for (int i = 0; i < ept; i++) if (__isnanf(wt[i])) wt[i] = -FLT_MAX;
    float wt_sum = 0.f;
    float output_weights[ept];
#pragma unroll
    for (int i = 0; i < ept; i++) output_weights[i] = 0.f;
    for (int k = 0; k < n_expert_used; k++) {
        float mv = wt[0]; int me = threadIdx.x;
#pragma unroll
        for (int i = 1; i < ept; i++) { if (wt[i] > mv) { mv = wt[i]; me = threadIdx.x + i * WARP_SIZE; } }
#pragma unroll
        for (int mask = WARP_SIZE / 2; mask > 0; mask /= 2) {
            const float val = __shfl_xor_sync(0xFFFFFFFF, mv, mask, WARP_SIZE);
            const int   e   = __shfl_xor_sync(0xFFFFFFFF, me, mask, WARP_SIZE);
            if (val > mv || (val == mv && e < me)) { mv = val; me = e; }
        }
        // every lane holds the same winner: make it scalar so the array updates need no per-lane indexing
        me = __builtin_amdgcn_readfirstlane(me);
        mv = __int_as_float(__builtin_amdgcn_readfirstlane(__float_as_int(mv)));
#pragma unroll
        for (int i = 0; i < ept; i++) {
            if (i == me / WARP_SIZE && (me & (WARP_SIZE - 1)) == threadIdx.x) wt[i] = -INFINITY;
            if (i == k / WARP_SIZE && (k & (WARP_SIZE - 1)) == threadIdx.x) output_weights[i] = mv;
        }
        if ((me & (WARP_SIZE - 1)) == threadIdx.x) { ids[k] = me; wt_sum += mv; }
    }
    wt_sum = wsum_dpp(wt_sum);
    wt_sum = max(wt_sum, clamp_val);
    const float inv = 1.0f / wt_sum;
    for (int i = 0; i < ept; i++) output_weights[i] *= inv;
#pragma unroll
    for (int i = 0; i < ept; i++) { const int idx = i * WARP_SIZE + threadIdx.x; if (idx < n_expert_used) weights[idx] = output_weights[i] * scale_val; }
    if (ts && threadIdx.x == 0 && row == 0) { ts[0] = clock64() - c0; }
}

__global__ void k_empty() {}

int main(int argc, char ** argv) {
    const int NE = 512, K = 10, ROWS = argc > 1 ? atoi(argv[1]) : 1;
    const float clamp = 6.103515625e-5f, scale = 1.0f;
    float *dl, *dw; int *di;
    hipMalloc(&dl, NE*ROWS*4); hipMalloc(&dw, K*ROWS*4); hipMalloc(&di, NE*ROWS*4);
    std::mt19937 rng(1234); std::normal_distribution<float> nd(0.f, 2.f);
    std::vector<float> hl(NE*ROWS), w0(K*ROWS), w1(K*ROWS); std::vector<int> i0(NE*ROWS), i1(NE*ROWS);
    topk_moe_config cfg{}; cfg.with_norm = true;
    dim3 grid((ROWS + TOPK_MOE_ROWS_PER_BLOCK - 1)/TOPK_MOE_ROWS_PER_BLOCK), block(WARP_SIZE, TOPK_MOE_ROWS_PER_BLOCK);
    int bad = 0;
    for (int t = 0; t < 300; t++) {
        for (auto & x : hl) x = nd(rng);
        if (t % 7 == 0) for (int j = 0; j < NE*ROWS; j += 3) hl[j] = hl[(j*7)%(NE*ROWS)];  // ties
        hipMemcpy(dl, hl.data(), NE*ROWS*4, hipMemcpyHostToDevice);
        topk_moe_cuda<512, false><<<grid, block>>>(dl, dw, di, nullptr, ROWS, K, clamp, scale, cfg);
        hipMemcpy(w0.data(), dw, K*ROWS*4, hipMemcpyDeviceToHost); hipMemcpy(i0.data(), di, NE*ROWS*4, hipMemcpyDeviceToHost);
        hipMemcpy(dl, hl.data(), NE*ROWS*4, hipMemcpyHostToDevice);
        for (int v = 0; v < 3; v++) {
            hipMemcpy(dl, hl.data(), NE*ROWS*4, hipMemcpyHostToDevice);
            if (v == 0) topk_moe_dpp<512><<<grid, block>>>(dl, dw, di, ROWS, K, clamp, scale);
            if (v == 1) topk_moe_v2<512><<<grid, block>>>(dl, dw, di, ROWS, K, clamp, scale);
            if (v == 2) topk_moe_v3<512><<<grid, block>>>(dl, dw, di, ROWS, K, clamp, scale);
            hipMemcpy(w1.data(), dw, K*ROWS*4, hipMemcpyDeviceToHost); hipMemcpy(i1.data(), di, NE*ROWS*4, hipMemcpyDeviceToHost);
            for (int r = 0; r < ROWS; r++) {
                if (memcmp(&w0[r*K], &w1[r*K], K*4) || memcmp(&i0[r*NE], &i1[r*NE], K*4)) bad++;
            }
        }
    }
    printf("rows %d: mismatching rows %d / %d\n", ROWS, bad, 300*ROWS);
    hipEvent_t a, b; hipEventCreate(&a); hipEventCreate(&b);
    auto timeit = [&](const char * name, auto launch) {
        for (int i = 0; i < 200; i++) launch();
        hipDeviceSynchronize();
        const int N = 5000; hipEventRecord(a); for (int i = 0; i < N; i++) launch(); hipEventRecord(b); hipEventSynchronize(b);
        float ms; hipEventElapsedTime(&ms, a, b); printf("%-10s %7.2f us/launch\n", name, ms*1000/N);
    };
    timeit("empty", [&]{ k_empty<<<1, 32>>>(); });
    timeit("ggml", [&]{ topk_moe_cuda<512, false><<<grid, block>>>(dl, dw, di, nullptr, ROWS, K, clamp, scale, cfg); });
    timeit("dpp",  [&]{ topk_moe_dpp<512><<<grid, block>>>(dl, dw, di, ROWS, K, clamp, scale); });
    timeit("v2 dpp+uni",  [&]{ topk_moe_v2<512><<<grid, block>>>(dl, dw, di, ROWS, K, clamp, scale); });
    timeit("v3 shfl+uni", [&]{ topk_moe_v3<512><<<grid, block>>>(dl, dw, di, ROWS, K, clamp, scale); });
    timeit("empty", [&]{ k_empty<<<1, 32>>>(); });
    long long * dts; hipMalloc(&dts, 64); long long h[8];
    for (int rep = 0; rep < 3; rep++) {
        topk_moe_dpp_t<512><<<grid, block>>>(dl, dw, di, ROWS, K, clamp, scale, dts); hipDeviceSynchronize();
        hipMemcpy(h, dts, 56, hipMemcpyDeviceToHost);
        printf("cycles: load %lld softmax %lld rounds %lld tail %lld total %lld | wall %lld ticks\n", h[1]-h[0], h[2]-h[1], h[3]-h[2], h[4]-h[3], h[4]-h[0], h[6]-h[5]);
    }
    for (int rep = 0; rep < 3; rep++) {
        topk_moe_cuda_ts<512, false><<<grid, block>>>(dl, dw, di, nullptr, ROWS, K, clamp, scale, cfg, dts);
        hipDeviceSynchronize(); hipMemcpy(h, dts, 8, hipMemcpyDeviceToHost); hipMemcpy(h, dts, 32, hipMemcpyDeviceToHost); printf("ggml total cycles %lld load %lld softmax+mask %lld rounds %lld\n", h[0], h[1], h[2], h[3]);
    }
    for (int v = 0; v < 3; v++) for (int rep = 0; rep < 3; rep++) {
        if (v == 0) topk_moe_dpp<512><<<grid, block>>>(dl, dw, di, ROWS, K, clamp, scale, dts);
        if (v == 1) topk_moe_v2<512><<<grid, block>>>(dl, dw, di, ROWS, K, clamp, scale, dts);
        if (v == 2) topk_moe_v3<512><<<grid, block>>>(dl, dw, di, ROWS, K, clamp, scale, dts);
        hipDeviceSynchronize(); hipMemcpy(h, dts, 8, hipMemcpyDeviceToHost); printf("variant %d total cycles %lld\n", v, h[0]);
    }
    int wclk; hipDeviceGetAttribute(&wclk, hipDeviceAttributeWallClockRate, 0); printf("wall clock rate %d kHz\n", wclk);
    return 0;
}
