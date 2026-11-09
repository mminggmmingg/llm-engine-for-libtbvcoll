
## MoE 구간: 1716번 나옴 (39.0/토큰), 커널 11개, 앞 AR 끝 → 다음 AR 끝 194.8 µs = 커널 164.1 + 빈틈 30.7
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 21.6 | 0.0 |
| 1 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 10.1 | 2.6 |
| 2 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 19.4 | 2.5 |
| 3 | `mul_mat_vec_f<__hip_bfloat16, float, 1, 256, false, false>` | 131072 | 256 | 16.3 | 2.9 |
| 4 | `topk_moe_softmax_cuda<512>` | 256 | 32 | 4.6 | 2.9 |
| 5 | `mul_mat_vec_q_glu_q8<t23, 1>` | 102400 | 1024 | 48.3 | 2.8 |
| 6 | `mul_mat_vec_q<t20, 1, false, false, false>` | 204800 | 32 | 25.2 | 3.0 |
| 7 | `moe_weighted_reduction_f32_out` | 2560 | 256 | 4.0 | 2.9 |
| 8 | `quantize_q8_1` | 2560 | 256 | 1.8 | 2.8 |
| 9 | `mul_mat_vec_q_glu_q8<t6, 1>` | 20480 | 1024 | 13.1 | 2.8 |
| 10 | `mul_mat_vec_q_shexp_tail<t6, 1>` | 81920 | 1024 | 17.8 | 2.7 |
| 11 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 4.1 | 2.8 |

## 그 밖 구간: 1276번 나옴 (29.0/토큰), 커널 8개, 앞 AR 끝 → 다음 AR 끝 205.4 µs = 커널 182.9 + 빈틈 22.4
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 4.1 | 0.0 |
| 1 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 14.5 | 2.7 |
| 2 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 20.9 | 2.7 |
| 3 | `mul_mat_vec_q<t6, 1, false, false, false>` | 262144 | 32 | 70.6 | 2.9 |
| 4 | `ssm_conv_silu_norm_pair_f32<4ul, true>` | 5120 | 128 | 3.6 | 3.0 |
| 5 | `mul_mat_vec_q_gdn_gates<t8>` | 1536 | 32 | 5.4 | 2.6 |
| 6 | `gated_delta_net_cuda<128, false, false, 4, true>` | 24576 | 32 | 15.3 | 2.8 |
| 7 | `mul_mat_vec_q_comm_out<t6, 1, 8>` | 81920 | 256 | 30.8 | 2.9 |
| 8 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 22.3 | 2.6 |

## 그 밖 구간: 396번 나옴 (9.0/토큰), 커널 24개, 앞 AR 끝 → 다음 AR 끝 338.5 µs = 커널 261.4 + 빈틈 75.8
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 4.1 | 0.0 |
| 1 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 14.4 | 2.7 |
| 2 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 20.9 | 2.8 |
| 3 | `mul_mat_vec_f<__hip_bfloat16, float, 1, 256, false, false>` | 32768 | 256 | 5.7 | 2.7 |
| 4 | `idx_k_pool_f32<false>` | 32 | 32 | 9.2 | 2.9 |
| 5 | `mul_mat_vec_q<t6, 1, false, false, false>` | 196608 | 32 | 54.1 | 2.9 |
| 6 | `rms_norm_mul_rope_multi_f32<128, false, float>` | 1536 | 128 | 6.4 | 2.8 |
| 7 | `mul_mat_vec_q<t6, 1, false, false, false>` | 8192 | 32 | 4.6 | 2.5 |
| 8 | `mul_mat_vec_q<t6, 1, false, false, false>` | 8192 | 32 | 4.6 | 2.5 |
| 9 | `rms_norm_mul_rope_multi_f32<128, false, __half>` | 128 | 128 | 5.7 | 2.6 |
| 10 | `k_set_rows<float, long, __half>` | 256 | 256 | 2.0 | 2.9 |
| 11 | `fill_kernel<__half>` | 256 | 256 | 1.6 | 2.9 |
| 12 | `mul_mat_vec_f<__hip_bfloat16, float, 1, 256, false, false>` | 131072 | 256 | 16.4 | 2.4 |
| 13 | `rms_norm_mul_rope_multi_f32<32, false, float>` | 128 | 32 | 5.7 | 2.7 |
| 14 | `k_get_rows_float<__half, float>` | 16384 | 256 | 2.7 | 3.0 |
| 15 | `fill_kernel<float>` | 256 | 256 | 1.6 | 2.7 |
| 16 | `lightning_indexer_kernel_vec<8, 64, 128l, 4l, t0>` | 256 | 32 | 5.2 | 3.8 |
| 17 | `k_argsort_f32_i32<` | 64 | 64 | 8.1 | 4.1 |
| 18 | `__amd_rocclr_copyBufferRectAligned` | 256 | 256 | 2.5 | 4.2 |
| 19 | `top_k_mask_kernel<__half>` | 512 | 512 | 4.9 | 4.1 |
| 20 | `flash_attn_tile<256, 256, 1, 4, false>` | 3072 | 32 | 8.7 | 4.2 |
| 21 | `flash_attn_combine_results<256>` | 3072 | 256 | 3.7 | 3.5 |
| 22 | `k_gate_sigmoid_mul_q8` | 3072 | 256 | 2.7 | 4.1 |
| 23 | `mul_mat_vec_q_comm_out<t8, 1, 8>` | 81920 | 256 | 45.7 | 3.6 |
| 24 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 20.1 | 2.7 |

## MoE 구간: 176번 나옴 (4.0/토큰), 커널 19개, 앞 AR 끝 → 다음 AR 끝 412.8 µs = 커널 358.8 + 빈틈 53.9
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 22.1 | 0.0 |
| 1 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 10.0 | 2.6 |
| 2 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 19.4 | 2.5 |
| 3 | `mul_mat_vec_f<__hip_bfloat16, float, 1, 256, false, false>` | 131072 | 256 | 16.8 | 2.7 |
| 4 | `topk_moe_softmax_cuda<512>` | 256 | 32 | 4.6 | 2.9 |
| 5 | `mul_mat_vec_q_glu_q8<t23, 1>` | 102400 | 1024 | 48.4 | 2.9 |
| 6 | `mul_mat_vec_q<t20, 1, false, false, false>` | 204800 | 32 | 25.3 | 3.0 |
| 7 | `moe_weighted_reduction_f32_out` | 2560 | 256 | 4.0 | 2.8 |
| 8 | `quantize_q8_1` | 2560 | 256 | 1.9 | 2.9 |
| 9 | `mul_mat_vec_q_glu_q8<t6, 1>` | 20480 | 1024 | 13.2 | 2.8 |
| 10 | `mul_mat_vec_q_shexp_tail<t6, 1>` | 81920 | 1024 | 17.8 | 2.7 |
| 11 | `rms_norm_hcpost_one_block<4, true>` | 1024 | 1024 | 12.4 | 2.9 |
| 12 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 14.4 | 2.8 |
| 13 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 21.1 | 2.8 |
| 14 | `mul_mat_vec_q<t6, 1, false, false, false>` | 262144 | 32 | 71.5 | 3.0 |
| 15 | `ssm_conv_silu_norm_pair_f32<4ul, true>` | 5120 | 128 | 3.6 | 3.0 |
| 16 | `mul_mat_vec_q_gdn_gates<t8>` | 1536 | 32 | 5.2 | 2.6 |
| 17 | `gated_delta_net_cuda<128, false, false, 4, true>` | 24576 | 32 | 14.9 | 2.9 |
| 18 | `mul_mat_vec_q_comm_out<t6, 1, 8>` | 81920 | 256 | 31.0 | 2.9 |
| 19 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 22.4 | 2.7 |

## 그 밖 구간: 88번 나옴 (2.0/토큰), 커널 8개, 앞 AR 끝 → 다음 AR 끝 240.1 µs = 커널 200.5 + 빈틈 34.6
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, false>` | 4096 | 1024 | 5.4 | 0.0 |
| 1 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 17.8 | 3.9 |
| 2 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 22.6 | 4.5 |
| 3 | `mul_mat_vec_q<t6, 1, false, false, false>` | 262144 | 32 | 68.5 | 4.5 |
| 4 | `ssm_conv_silu_norm_pair_f32<4ul, true>` | 5120 | 128 | 5.6 | 5.6 |
| 5 | `mul_mat_vec_q_gdn_gates<t8>` | 1536 | 32 | 7.4 | 3.5 |
| 6 | `gated_delta_net_cuda<128, false, false, 4, true>` | 24576 | 32 | 17.2 | 3.8 |
| 7 | `mul_mat_vec_q_comm_out<t6, 1, 8>` | 81920 | 256 | 32.3 | 4.1 |
| 8 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 23.0 | 3.0 |

## MoE 구간: 88번 나옴 (2.0/토큰), 커널 35개, 앞 AR 끝 → 다음 AR 끝 541.1 µs = 커널 431.2 + 빈틈 108.6
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 22.9 | 0.0 |
| 1 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 9.2 | 2.6 |
| 2 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 19.3 | 2.5 |
| 3 | `mul_mat_vec_f<__hip_bfloat16, float, 1, 256, false, false>` | 131072 | 256 | 16.1 | 3.0 |
| 4 | `topk_moe_softmax_cuda<512>` | 256 | 32 | 4.6 | 2.9 |
| 5 | `mul_mat_vec_q_glu_q8<t23, 1>` | 102400 | 1024 | 48.7 | 2.9 |
| 6 | `mul_mat_vec_q<t20, 1, false, false, false>` | 204800 | 32 | 25.2 | 3.0 |
| 7 | `moe_weighted_reduction_f32_out` | 2560 | 256 | 4.1 | 3.0 |
| 8 | `quantize_q8_1` | 2560 | 256 | 1.8 | 2.8 |
| 9 | `mul_mat_vec_q_glu_q8<t6, 1>` | 20480 | 1024 | 12.9 | 2.8 |
| 10 | `mul_mat_vec_q_shexp_tail<t6, 1>` | 81920 | 1024 | 17.6 | 2.7 |
| 11 | `rms_norm_hcpost_one_block<4, true>` | 1024 | 1024 | 11.8 | 2.9 |
| 12 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 14.5 | 2.7 |
| 13 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 21.2 | 2.8 |
| 14 | `mul_mat_vec_f<__hip_bfloat16, float, 1, 256, false, false>` | 32768 | 256 | 5.6 | 2.6 |
| 15 | `idx_k_pool_f32<false>` | 32 | 32 | 9.1 | 2.9 |
| 16 | `mul_mat_vec_q<t6, 1, false, false, false>` | 196608 | 32 | 54.0 | 2.8 |
| 17 | `rms_norm_mul_rope_multi_f32<128, false, float>` | 1536 | 128 | 6.3 | 2.8 |
| 18 | `mul_mat_vec_q<t6, 1, false, false, false>` | 8192 | 32 | 4.8 | 2.5 |
| 19 | `mul_mat_vec_q<t6, 1, false, false, false>` | 8192 | 32 | 4.4 | 2.4 |
| 20 | `rms_norm_mul_rope_multi_f32<128, false, __half>` | 128 | 128 | 5.8 | 2.6 |
| 21 | `k_set_rows<float, long, __half>` | 256 | 256 | 2.1 | 3.0 |
| 22 | `fill_kernel<__half>` | 256 | 256 | 1.6 | 2.9 |
| 23 | `mul_mat_vec_f<__hip_bfloat16, float, 1, 256, false, false>` | 131072 | 256 | 16.3 | 2.4 |
| 24 | `rms_norm_mul_rope_multi_f32<32, false, float>` | 128 | 32 | 5.6 | 2.7 |
| 25 | `k_get_rows_float<__half, float>` | 16384 | 256 | 2.8 | 3.1 |
| 26 | `fill_kernel<float>` | 256 | 256 | 2.0 | 3.4 |
| 27 | `lightning_indexer_kernel_vec<8, 64, 128l, 4l, t0>` | 256 | 32 | 4.8 | 4.1 |
| 28 | `k_argsort_f32_i32<` | 64 | 64 | 8.2 | 4.2 |
| 29 | `__amd_rocclr_copyBufferRectAligned` | 256 | 256 | 2.4 | 4.1 |
| 30 | `top_k_mask_kernel<__half>` | 512 | 512 | 5.3 | 4.1 |
| 31 | `flash_attn_tile<256, 256, 1, 4, false>` | 3072 | 32 | 8.6 | 4.1 |
| 32 | `flash_attn_combine_results<256>` | 3072 | 256 | 3.0 | 3.4 |
| 33 | `k_gate_sigmoid_mul_q8` | 3072 | 256 | 2.6 | 4.1 |
| 34 | `mul_mat_vec_q_comm_out<t8, 1, 8>` | 81920 | 256 | 45.8 | 3.7 |
| 35 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 20.0 | 2.8 |

## MoE 구간: 44번 나옴 (1.0/토큰), 커널 13개, 앞 AR 끝 → 다음 AR 끝 345.3 µs = 커널 308.2 + 빈틈 37.4
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 36.6 | 0.0 |
| 1 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 8.6 | 2.6 |
| 2 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 14.1 | 2.5 |
| 3 | `mul_mat_vec_f<__hip_bfloat16, float, 1, 256, false, false>` | 131072 | 256 | 16.7 | 2.9 |
| 4 | `topk_moe_softmax_cuda<512>` | 256 | 32 | 4.6 | 2.9 |
| 5 | `mul_mat_vec_q_glu_q8<t23, 1>` | 102400 | 1024 | 48.7 | 2.9 |
| 6 | `mul_mat_vec_q<t20, 1, false, false, false>` | 204800 | 32 | 25.6 | 3.1 |
| 7 | `moe_weighted_reduction_f32_out` | 2560 | 256 | 4.3 | 3.0 |
| 8 | `k_get_rows_float<float, float>` | 92160 | 256 | 5.7 | 2.9 |
| 9 | `quantize_q8_1` | 2560 | 256 | 2.2 | 2.9 |
| 10 | `mul_mat_vec_q<t8, 1, false, false, false>` | 81920 | 32 | 36.0 | 2.8 |
| 11 | `k_bin_bcast<&` | 5120 | 128 | 1.6 | 3.0 |
| 12 | `mul_mat_vec_q<t8, 1, false, false, false>` | 327680 | 32 | 135.1 | 2.5 |
| 13 | `rms_norm_f32<1024, 1, true, true, false, false, false, false, false>` | 4096 | 1024 | 3.6 | 3.1 |

## 그 밖 구간: 44번 나옴 (1.0/토큰), 커널 4개, 앞 AR 끝 → 다음 AR 끝 52.1 µs = 커널 40.8 + 빈틈 11.3
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, false, false, false>` | 4096 | 1024 | 3.6 | 0.0 |
| 1 | `quantize_q8_1` | 2560 | 256 | 1.7 | 2.6 |
| 2 | `mul_mat_vec_q_glu_q8<t6, 1>` | 20480 | 1024 | 13.4 | 2.9 |
| 3 | `mul_mat_vec_q_shexp_tail<t6, 1>` | 81920 | 1024 | 19.6 | 2.7 |
| 4 | `rms_norm_f32<1024, 1, true, true, false, false, false, false, true>` | 4096 | 1024 | 6.5 | 2.8 |

## 그 밖 구간: 44번 나옴 (1.0/토큰), 커널 11개, 앞 AR 끝 → 다음 AR 끝 71.2 µs = 커널 28.6 + 빈틈 41.5
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, false, false, true>` | 4096 | 1024 | 6.5 | 0.0 |
| 1 | `k_bin_bcast<&` | 5120 | 128 | 2.2 | 3.7 |
| 2 | `reduce_rows_f32<false>` | 2048 | 512 | 3.4 | 4.2 |
| 3 | `scale_f32<float>` | 256 | 256 | 2.3 | 4.0 |
| 4 | `unary_op_kernel<&` | 256 | 256 | 2.2 | 4.1 |
| 5 | `unary_op_kernel<&` | 256 | 256 | 2.3 | 3.6 |
| 6 | `op_clamp_kernel<float>` | 256 | 256 | 2.2 | 4.1 |
| 7 | `unary_op_kernel<&` | 256 | 256 | 2.2 | 3.9 |
| 8 | `k_bin_bcast<&` | 2 | 2 | 1.5 | 3.4 |
| 9 | `unary_op_kernel<&` | 256 | 256 | 2.2 | 4.1 |
| 10 | `k_bin_bcast<&` | 5120 | 128 | 2.8 | 3.2 |
| 11 | `rms_norm_f32<1024, 1, true, true, false, false, false, false, false>` | 4096 | 1024 | 2.9 | 3.5 |

## 그 밖 구간: 44번 나옴 (1.0/토큰), 커널 21개, 앞 AR 끝 → 다음 AR 끝 170.5 µs = 커널 64.7 + 빈틈 103.1
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, false, false, false>` | 4096 | 1024 | 2.9 | 0.0 |
| 1 | `concat_dim0_tail_f32` | 102400 | 256 | 7.3 | 4.1 |
| 2 | `cpy_scalar<&` | 10240 | 64 | 4.0 | 4.2 |
| 3 | `__amd_rocclr_copyBufferRectAligned` | 163840 | 16 | 8.8 | 4.1 |
| 4 | `k_bin_bcast<&` | 5120 | 128 | 1.4 | 3.6 |
| 5 | `cpy_scalar<&` | 10240 | 64 | 2.7 | 3.4 |
| 6 | `__amd_rocclr_copyBufferRectAligned` | 163840 | 16 | 3.8 | 3.3 |
| 7 | `k_bin_bcast<&` | 5120 | 128 | 1.3 | 3.3 |
| 8 | `k_bin_bcast<&` | 5120 | 128 | 2.2 | 4.1 |
| 9 | `cpy_scalar<&` | 10240 | 64 | 1.8 | 3.4 |
| 10 | `__amd_rocclr_copyBufferRectAligned` | 163840 | 16 | 3.8 | 3.2 |
| 11 | `k_bin_bcast<&` | 5120 | 128 | 1.3 | 3.4 |
| 12 | `k_bin_bcast<&` | 5120 | 128 | 1.3 | 3.6 |
| 13 | `cpy_scalar<&` | 10240 | 64 | 1.9 | 3.4 |
| 14 | `__amd_rocclr_copyBufferRectAligned` | 163840 | 16 | 3.8 | 3.5 |
| 15 | `k_bin_bcast<&` | 5120 | 128 | 1.3 | 3.6 |
| 16 | `k_bin_bcast<&` | 5120 | 128 | 1.3 | 4.1 |
| 17 | `unary_op_kernel<&` | 10240 | 256 | 2.3 | 4.1 |
| 18 | `__amd_rocclr_copyBuffer` | 2560 | 512 | 1.3 | 4.2 |
| 19 | `k_bin_bcast<&` | 5120 | 128 | 1.3 | 4.9 |
| 20 | `k_bin_bcast<&` | 5120 | 128 | 1.3 | 4.9 |
| 21 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, false>` | 4096 | 1024 | 6.1 | 7.7 |

## MoE 구간: 44번 나옴 (1.0/토큰), 커널 19개, 앞 AR 끝 → 다음 AR 끝 417.8 µs = 커널 364.2 + 빈틈 53.3
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 4.2 | 0.0 |
| 1 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 15.2 | 2.7 |
| 2 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 21.6 | 2.9 |
| 3 | `mul_mat_vec_q<t6, 1, false, false, false>` | 262144 | 32 | 71.7 | 2.8 |
| 4 | `ssm_conv_silu_norm_pair_f32<4ul, true>` | 5120 | 128 | 3.6 | 2.8 |
| 5 | `mul_mat_vec_q_gdn_gates<t8>` | 1536 | 32 | 5.2 | 2.6 |
| 6 | `gated_delta_net_cuda<128, false, false, 4, true>` | 24576 | 32 | 15.2 | 2.7 |
| 7 | `mul_mat_vec_q_comm_out<t6, 1, 8>` | 81920 | 256 | 31.0 | 2.9 |
| 8 | `rms_norm_hcpost_one_block<4, true>` | 1024 | 1024 | 26.3 | 2.7 |
| 9 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 15.4 | 2.6 |
| 10 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 20.6 | 2.6 |
| 11 | `mul_mat_vec_f<__hip_bfloat16, float, 1, 256, false, false>` | 131072 | 256 | 16.1 | 2.9 |
| 12 | `topk_moe_softmax_cuda<512>` | 256 | 32 | 4.6 | 2.9 |
| 13 | `mul_mat_vec_q_glu_q8<t23, 1>` | 102400 | 1024 | 48.5 | 2.7 |
| 14 | `mul_mat_vec_q<t20, 1, false, false, false>` | 204800 | 32 | 25.6 | 2.8 |
| 15 | `moe_weighted_reduction_f32_out` | 2560 | 256 | 4.1 | 3.0 |
| 16 | `quantize_q8_1` | 2560 | 256 | 1.9 | 2.8 |
| 17 | `mul_mat_vec_q_glu_q8<t6, 1>` | 20480 | 1024 | 12.9 | 2.7 |
| 18 | `mul_mat_vec_q_shexp_tail<t6, 1>` | 81920 | 1024 | 18.7 | 2.7 |
| 19 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 4.5 | 3.0 |

## 그 밖 구간: 44번 나옴 (1.0/토큰), 커널 32개, 앞 AR 끝 → 다음 AR 끝 387.1 µs = 커널 278.9 + 빈틈 105.9
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 4.0 | 0.0 |
| 1 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 14.3 | 2.7 |
| 2 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 20.7 | 2.8 |
| 3 | `mul_mat_vec_f<__hip_bfloat16, float, 1, 256, false, false>` | 32768 | 256 | 5.0 | 3.0 |
| 4 | `idx_k_pool_f32<false>` | 32 | 32 | 9.5 | 3.0 |
| 5 | `mul_mat_vec_q<t6, 1, false, false, false>` | 196608 | 32 | 53.8 | 3.0 |
| 6 | `rms_norm_mul_rope_multi_f32<128, false, float>` | 1536 | 128 | 6.3 | 2.8 |
| 7 | `mul_mat_vec_q<t6, 1, false, false, false>` | 8192 | 32 | 4.5 | 2.5 |
| 8 | `mul_mat_vec_q<t6, 1, false, false, false>` | 8192 | 32 | 4.9 | 2.5 |
| 9 | `rms_norm_mul_rope_multi_f32<128, false, __half>` | 128 | 128 | 5.9 | 3.4 |
| 10 | `k_set_rows<float, long, __half>` | 256 | 256 | 3.4 | 4.1 |
| 11 | `fill_kernel<__half>` | 256 | 256 | 2.1 | 4.1 |
| 12 | `mul_mat_vec_f<__hip_bfloat16, float, 1, 256, false, false>` | 131072 | 256 | 18.7 | 3.4 |
| 13 | `rms_norm_mul_rope_multi_f32<32, false, float>` | 128 | 32 | 6.4 | 4.4 |
| 14 | `k_get_rows_float<__half, float>` | 16384 | 256 | 3.2 | 3.4 |
| 15 | `fill_kernel<float>` | 256 | 256 | 2.1 | 3.4 |
| 16 | `lightning_indexer_kernel_vec<8, 64, 128l, 4l, t0>` | 256 | 32 | 5.3 | 4.0 |
| 17 | `k_argsort_f32_i32<` | 64 | 64 | 8.2 | 4.2 |
| 18 | `__amd_rocclr_copyBufferRectAligned` | 256 | 256 | 2.5 | 4.2 |
| 19 | `top_k_mask_kernel<__half>` | 512 | 512 | 4.8 | 4.1 |
| 20 | `flash_attn_tile<256, 256, 1, 4, false>` | 3072 | 32 | 9.2 | 4.2 |
| 21 | `flash_attn_combine_results<256>` | 3072 | 256 | 3.9 | 3.6 |
| 22 | `k_gate_sigmoid_mul_q8` | 3072 | 256 | 2.8 | 4.1 |
| 23 | `mul_mat_vec_q_comm_out<t8, 1, 8>` | 81920 | 256 | 46.6 | 4.0 |
| 24 | `k_comm_wait_add` | 1024 | 1024 | 12.2 | 3.0 |
| 25 | `k_get_rows_float<float, float>` | 2560 | 256 | 2.4 | 2.7 |
| 26 | `k_get_rows_float<float, float>` | 10240 | 256 | 1.8 | 2.4 |
| 27 | `scale_f32<float>` | 256 | 256 | 1.6 | 2.8 |
| 28 | `k_get_rows_float<float, float>` | 256 | 256 | 1.3 | 2.4 |
| 29 | `unary_op_kernel<&` | 256 | 256 | 1.6 | 2.8 |
| 30 | `scale_f32<float>` | 256 | 256 | 1.0 | 2.4 |
| 31 | `dsv4_hc_post_f32<false, false>` | 10240 | 256 | 2.0 | 2.8 |
| 32 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, false>` | 4096 | 1024 | 3.5 | 2.6 |

## MoE 구간: 44번 나옴 (1.0/토큰), 커널 11개, 앞 AR 끝 → 다음 AR 끝 216.5 µs = 커널 179.5 + 빈틈 36.5
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, false>` | 4096 | 1024 | 3.5 | 0.0 |
| 1 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 17.0 | 2.8 |
| 2 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 20.7 | 2.6 |
| 3 | `mul_mat_vec_f<__hip_bfloat16, float, 1, 256, false, false>` | 131072 | 256 | 16.2 | 2.7 |
| 4 | `topk_moe_softmax_cuda<512>` | 256 | 32 | 4.6 | 2.8 |
| 5 | `mul_mat_vec_q_glu_q8<t23, 1>` | 102400 | 1024 | 49.3 | 3.0 |
| 6 | `mul_mat_vec_q<t20, 1, false, false, false>` | 204800 | 32 | 28.2 | 5.7 |
| 7 | `moe_weighted_reduction_f32_out` | 2560 | 256 | 4.5 | 5.6 |
| 8 | `quantize_q8_1` | 2560 | 256 | 1.6 | 2.8 |
| 9 | `mul_mat_vec_q_glu_q8<t6, 1>` | 20480 | 1024 | 13.0 | 2.9 |
| 10 | `mul_mat_vec_q_shexp_tail<t6, 1>` | 81920 | 1024 | 18.3 | 2.6 |
| 11 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 4.5 | 2.9 |
