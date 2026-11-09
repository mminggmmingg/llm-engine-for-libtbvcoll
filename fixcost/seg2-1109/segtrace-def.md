
## MoE 구간: 2295번 나옴 (38.2/토큰), 커널 11개, 앞 AR 끝 → 다음 AR 끝 195.5 µs = 커널 164.7 + 빈틈 30.7
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 21.2 | 0.0 |
| 1 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 10.4 | 2.6 |
| 2 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 19.4 | 2.5 |
| 3 | `mul_mat_vec_f<__hip_bfloat16, float, 1, 256, false, false>` | 131072 | 256 | 16.0 | 2.9 |
| 4 | `topk_moe_softmax_cuda<512>` | 256 | 32 | 4.5 | 2.9 |
| 5 | `mul_mat_vec_q_glu_q8<t23, 1>` | 102400 | 1024 | 48.6 | 2.8 |
| 6 | `mul_mat_vec_q<t20, 1, false, false, false>` | 204800 | 32 | 25.1 | 3.0 |
| 7 | `moe_weighted_reduction_f32_out` | 2560 | 256 | 4.0 | 2.9 |
| 8 | `quantize_q8_1` | 2560 | 256 | 1.8 | 2.8 |
| 9 | `mul_mat_vec_q_glu_q8<t6, 1>` | 20480 | 1024 | 12.8 | 2.6 |
| 10 | `mul_mat_vec_q_shexp_tail<t6, 1>` | 81920 | 1024 | 18.3 | 2.9 |
| 11 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 4.3 | 2.7 |

## 그 밖 구간: 1735번 나옴 (28.9/토큰), 커널 8개, 앞 AR 끝 → 다음 AR 끝 205.2 µs = 커널 182.6 + 빈틈 22.5
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 4.2 | 0.0 |
| 1 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 14.5 | 2.7 |
| 2 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 20.4 | 2.8 |
| 3 | `mul_mat_vec_q<t6, 1, false, false, false>` | 262144 | 32 | 71.0 | 2.9 |
| 4 | `ssm_conv_silu_norm_pair_f32<4ul, true>` | 5120 | 128 | 3.6 | 3.0 |
| 5 | `mul_mat_vec_q_gdn_gates<t8>` | 1536 | 32 | 5.7 | 2.6 |
| 6 | `gated_delta_net_cuda<128, false, false, 4, true>` | 24576 | 32 | 15.6 | 2.9 |
| 7 | `mul_mat_vec_q_comm_out<t6, 1, 8>` | 81920 | 256 | 30.3 | 2.9 |
| 8 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 21.9 | 2.6 |

## 그 밖 구간: 521번 나옴 (8.7/토큰), 커널 24개, 앞 AR 끝 → 다음 AR 끝 337.9 µs = 커널 261.7 + 빈틈 75.2
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 4.4 | 0.0 |
| 1 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 14.5 | 2.6 |
| 2 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 20.5 | 2.8 |
| 3 | `mul_mat_vec_f<__hip_bfloat16, float, 1, 256, false, false>` | 32768 | 256 | 5.4 | 2.8 |
| 4 | `idx_k_pool_f32<false>` | 32 | 32 | 9.3 | 2.9 |
| 5 | `mul_mat_vec_q<t6, 1, false, false, false>` | 196608 | 32 | 54.5 | 2.8 |
| 6 | `rms_norm_mul_rope_multi_f32<128, false, float>` | 1536 | 128 | 6.3 | 2.8 |
| 7 | `mul_mat_vec_q<t6, 1, false, false, false>` | 8192 | 32 | 4.6 | 2.5 |
| 8 | `mul_mat_vec_q<t6, 1, false, false, false>` | 8192 | 32 | 4.6 | 2.4 |
| 9 | `rms_norm_mul_rope_multi_f32<128, false, __half>` | 128 | 128 | 5.6 | 2.6 |
| 10 | `k_set_rows<float, long, __half>` | 256 | 256 | 2.1 | 2.9 |
| 11 | `fill_kernel<__half>` | 256 | 256 | 1.7 | 2.9 |
| 12 | `mul_mat_vec_f<__hip_bfloat16, float, 1, 256, false, false>` | 131072 | 256 | 16.6 | 2.4 |
| 13 | `rms_norm_mul_rope_multi_f32<32, false, float>` | 128 | 32 | 5.6 | 2.7 |
| 14 | `k_get_rows_float<__half, float>` | 16384 | 256 | 2.8 | 3.0 |
| 15 | `fill_kernel<float>` | 256 | 256 | 1.8 | 2.8 |
| 16 | `lightning_indexer_kernel_vec<8, 64, 128l, 4l, t0>` | 256 | 32 | 5.9 | 3.5 |
| 17 | `k_argsort_f32_i32<` | 64 | 64 | 8.4 | 4.1 |
| 18 | `__amd_rocclr_copyBufferRectAligned` | 256 | 256 | 2.5 | 4.1 |
| 19 | `top_k_mask_kernel<__half>` | 512 | 512 | 5.2 | 4.0 |
| 20 | `flash_attn_tile<256, 256, 1, 4, false>` | 3072 | 32 | 9.5 | 4.0 |
| 21 | `flash_attn_combine_results<256>` | 3072 | 256 | 4.1 | 3.7 |
| 22 | `k_gate_sigmoid_mul_q8` | 3072 | 256 | 2.9 | 4.1 |
| 23 | `mul_mat_vec_q_comm_out<t8, 1, 8>` | 81920 | 256 | 45.5 | 3.8 |
| 24 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 19.8 | 2.9 |

## MoE 구간: 233번 나옴 (3.9/토큰), 커널 19개, 앞 AR 끝 → 다음 AR 끝 410.8 µs = 커널 357.4 + 빈틈 53.6
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 22.5 | 0.0 |
| 1 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 9.9 | 2.6 |
| 2 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 18.9 | 2.5 |
| 3 | `mul_mat_vec_f<__hip_bfloat16, float, 1, 256, false, false>` | 131072 | 256 | 16.3 | 2.9 |
| 4 | `topk_moe_softmax_cuda<512>` | 256 | 32 | 4.6 | 2.9 |
| 5 | `mul_mat_vec_q_glu_q8<t23, 1>` | 102400 | 1024 | 48.6 | 2.8 |
| 6 | `mul_mat_vec_q<t20, 1, false, false, false>` | 204800 | 32 | 25.4 | 3.0 |
| 7 | `moe_weighted_reduction_f32_out` | 2560 | 256 | 4.0 | 3.0 |
| 8 | `quantize_q8_1` | 2560 | 256 | 2.0 | 2.9 |
| 9 | `mul_mat_vec_q_glu_q8<t6, 1>` | 20480 | 1024 | 12.9 | 2.6 |
| 10 | `mul_mat_vec_q_shexp_tail<t6, 1>` | 81920 | 1024 | 18.3 | 2.9 |
| 11 | `rms_norm_hcpost_one_block<4, true>` | 1024 | 1024 | 12.0 | 2.8 |
| 12 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 14.5 | 2.8 |
| 13 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 20.6 | 2.8 |
| 14 | `mul_mat_vec_q<t6, 1, false, false, false>` | 262144 | 32 | 72.0 | 2.9 |
| 15 | `ssm_conv_silu_norm_pair_f32<4ul, true>` | 5120 | 128 | 3.6 | 3.1 |
| 16 | `mul_mat_vec_q_gdn_gates<t8>` | 1536 | 32 | 5.7 | 2.6 |
| 17 | `gated_delta_net_cuda<128, false, false, 4, true>` | 24576 | 32 | 15.3 | 2.7 |
| 18 | `mul_mat_vec_q_comm_out<t6, 1, 8>` | 81920 | 256 | 30.3 | 2.9 |
| 19 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 21.6 | 2.7 |

## 그 밖 구간: 117번 나옴 (1.9/토큰), 커널 8개, 앞 AR 끝 → 다음 AR 끝 254.7 µs = 커널 216.7 + 빈틈 36.9
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, false>` | 4096 | 1024 | 4.9 | 0.0 |
| 1 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 17.4 | 3.8 |
| 2 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 24.5 | 4.3 |
| 3 | `mul_mat_vec_q<t6, 1, false, false, false>` | 262144 | 32 | 69.1 | 4.7 |
| 4 | `ssm_conv_silu_norm_pair_f32<4ul, true>` | 5120 | 128 | 5.2 | 5.9 |
| 5 | `mul_mat_vec_q_gdn_gates<t8>` | 1536 | 32 | 7.7 | 3.4 |
| 6 | `gated_delta_net_cuda<128, false, false, 4, true>` | 24576 | 32 | 18.0 | 4.0 |
| 7 | `mul_mat_vec_q_comm_out<t6, 1, 8>` | 81920 | 256 | 32.9 | 4.2 |
| 8 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 35.3 | 4.8 |

## MoE 구간: 111번 나옴 (1.9/토큰), 커널 35개, 앞 AR 끝 → 다음 AR 끝 547.4 µs = 커널 436.7 + 빈틈 109.8
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 21.4 | 0.0 |
| 1 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 10.4 | 2.6 |
| 2 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 20.0 | 2.6 |
| 3 | `mul_mat_vec_f<__hip_bfloat16, float, 1, 256, false, false>` | 131072 | 256 | 15.5 | 3.0 |
| 4 | `topk_moe_softmax_cuda<512>` | 256 | 32 | 4.7 | 2.9 |
| 5 | `mul_mat_vec_q_glu_q8<t23, 1>` | 102400 | 1024 | 48.9 | 3.0 |
| 6 | `mul_mat_vec_q<t20, 1, false, false, false>` | 204800 | 32 | 25.4 | 3.1 |
| 7 | `moe_weighted_reduction_f32_out` | 2560 | 256 | 4.0 | 2.8 |
| 8 | `quantize_q8_1` | 2560 | 256 | 2.0 | 2.8 |
| 9 | `mul_mat_vec_q_glu_q8<t6, 1>` | 20480 | 1024 | 12.8 | 2.6 |
| 10 | `mul_mat_vec_q_shexp_tail<t6, 1>` | 81920 | 1024 | 18.1 | 3.0 |
| 11 | `rms_norm_hcpost_one_block<4, true>` | 1024 | 1024 | 12.3 | 3.0 |
| 12 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 14.5 | 2.8 |
| 13 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 20.7 | 2.9 |
| 14 | `mul_mat_vec_f<__hip_bfloat16, float, 1, 256, false, false>` | 32768 | 256 | 5.3 | 2.8 |
| 15 | `idx_k_pool_f32<false>` | 32 | 32 | 9.3 | 2.9 |
| 16 | `mul_mat_vec_q<t6, 1, false, false, false>` | 196608 | 32 | 54.9 | 3.0 |
| 17 | `rms_norm_mul_rope_multi_f32<128, false, float>` | 1536 | 128 | 6.2 | 2.8 |
| 18 | `mul_mat_vec_q<t6, 1, false, false, false>` | 8192 | 32 | 4.7 | 2.5 |
| 19 | `mul_mat_vec_q<t6, 1, false, false, false>` | 8192 | 32 | 4.4 | 2.4 |
| 20 | `rms_norm_mul_rope_multi_f32<128, false, __half>` | 128 | 128 | 5.7 | 2.6 |
| 21 | `k_set_rows<float, long, __half>` | 256 | 256 | 2.1 | 3.0 |
| 22 | `fill_kernel<__half>` | 256 | 256 | 1.7 | 2.9 |
| 23 | `mul_mat_vec_f<__hip_bfloat16, float, 1, 256, false, false>` | 131072 | 256 | 16.2 | 2.4 |
| 24 | `rms_norm_mul_rope_multi_f32<32, false, float>` | 128 | 32 | 5.6 | 2.7 |
| 25 | `k_get_rows_float<__half, float>` | 16384 | 256 | 4.0 | 4.0 |
| 26 | `fill_kernel<float>` | 256 | 256 | 2.2 | 3.6 |
| 27 | `lightning_indexer_kernel_vec<8, 64, 128l, 4l, t0>` | 256 | 32 | 5.9 | 4.0 |
| 28 | `k_argsort_f32_i32<` | 64 | 64 | 8.4 | 4.1 |
| 29 | `__amd_rocclr_copyBufferRectAligned` | 256 | 256 | 2.5 | 4.1 |
| 30 | `top_k_mask_kernel<__half>` | 512 | 512 | 5.1 | 4.0 |
| 31 | `flash_attn_tile<256, 256, 1, 4, false>` | 3072 | 32 | 9.5 | 4.0 |
| 32 | `flash_attn_combine_results<256>` | 3072 | 256 | 4.0 | 3.7 |
| 33 | `k_gate_sigmoid_mul_q8` | 3072 | 256 | 2.8 | 4.0 |
| 34 | `mul_mat_vec_q_comm_out<t8, 1, 8>` | 81920 | 256 | 45.7 | 4.0 |
| 35 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 19.7 | 3.0 |

## MoE 구간: 59번 나옴 (1.0/토큰), 커널 19개, 앞 AR 끝 → 다음 AR 끝 418.3 µs = 커널 363.1 + 빈틈 54.2
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 4.3 | 0.0 |
| 1 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 14.6 | 2.6 |
| 2 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 21.5 | 2.6 |
| 3 | `mul_mat_vec_q<t6, 1, false, false, false>` | 262144 | 32 | 71.3 | 2.8 |
| 4 | `ssm_conv_silu_norm_pair_f32<4ul, true>` | 5120 | 128 | 3.3 | 3.0 |
| 5 | `mul_mat_vec_q_gdn_gates<t8>` | 1536 | 32 | 5.7 | 2.6 |
| 6 | `gated_delta_net_cuda<128, false, false, 4, true>` | 24576 | 32 | 15.8 | 3.0 |
| 7 | `mul_mat_vec_q_comm_out<t6, 1, 8>` | 81920 | 256 | 30.3 | 2.8 |
| 8 | `rms_norm_hcpost_one_block<4, true>` | 1024 | 1024 | 28.4 | 2.8 |
| 9 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 14.7 | 2.6 |
| 10 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 20.7 | 2.6 |
| 11 | `mul_mat_vec_f<__hip_bfloat16, float, 1, 256, false, false>` | 131072 | 256 | 15.7 | 3.0 |
| 12 | `topk_moe_softmax_cuda<512>` | 256 | 32 | 4.6 | 3.0 |
| 13 | `mul_mat_vec_q_glu_q8<t23, 1>` | 102400 | 1024 | 48.6 | 2.9 |
| 14 | `mul_mat_vec_q<t20, 1, false, false, false>` | 204800 | 32 | 25.4 | 3.1 |
| 15 | `moe_weighted_reduction_f32_out` | 2560 | 256 | 4.0 | 2.8 |
| 16 | `quantize_q8_1` | 2560 | 256 | 2.0 | 3.0 |
| 17 | `mul_mat_vec_q_glu_q8<t6, 1>` | 20480 | 1024 | 12.7 | 2.6 |
| 18 | `mul_mat_vec_q_shexp_tail<t6, 1>` | 81920 | 1024 | 18.5 | 3.0 |
| 19 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 4.6 | 3.0 |

## MoE 구간: 58번 나옴 (1.0/토큰), 커널 13개, 앞 AR 끝 → 다음 AR 끝 342.7 µs = 커널 304.6 + 빈틈 37.7
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 40.8 | 0.0 |
| 1 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 8.4 | 2.7 |
| 2 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 13.4 | 2.5 |
| 3 | `mul_mat_vec_f<__hip_bfloat16, float, 1, 256, false, false>` | 131072 | 256 | 15.4 | 3.0 |
| 4 | `topk_moe_softmax_cuda<512>` | 256 | 32 | 4.5 | 2.9 |
| 5 | `mul_mat_vec_q_glu_q8<t23, 1>` | 102400 | 1024 | 49.2 | 2.9 |
| 6 | `mul_mat_vec_q<t20, 1, false, false, false>` | 204800 | 32 | 25.5 | 3.0 |
| 7 | `moe_weighted_reduction_f32_out` | 2560 | 256 | 4.1 | 3.0 |
| 8 | `k_get_rows_float<float, float>` | 92160 | 256 | 6.1 | 2.9 |
| 9 | `quantize_q8_1` | 2560 | 256 | 2.2 | 2.9 |
| 10 | `mul_mat_vec_q<t8, 1, false, false, false>` | 81920 | 32 | 36.8 | 2.8 |
| 11 | `k_bin_bcast<&` | 5120 | 128 | 1.9 | 3.0 |
| 12 | `mul_mat_vec_q<t8, 1, false, false, false>` | 327680 | 32 | 134.7 | 2.4 |
| 13 | `rms_norm_f32<1024, 1, true, true, false, false, false, false, false>` | 4096 | 1024 | 3.7 | 3.0 |

## 그 밖 구간: 58번 나옴 (1.0/토큰), 커널 4개, 앞 AR 끝 → 다음 AR 끝 54.4 µs = 커널 42.6 + 빈틈 11.4
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, false, false, false>` | 4096 | 1024 | 3.7 | 0.0 |
| 1 | `quantize_q8_1` | 2560 | 256 | 1.8 | 2.6 |
| 2 | `mul_mat_vec_q_glu_q8<t6, 1>` | 20480 | 1024 | 13.0 | 2.6 |
| 3 | `mul_mat_vec_q_shexp_tail<t6, 1>` | 81920 | 1024 | 20.6 | 3.0 |
| 4 | `rms_norm_f32<1024, 1, true, true, false, false, false, false, true>` | 4096 | 1024 | 6.8 | 3.0 |

## 그 밖 구간: 58번 나옴 (1.0/토큰), 커널 21개, 앞 AR 끝 → 다음 AR 끝 145.1 µs = 커널 62.5 + 빈틈 78.7
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, false, false, false>` | 4096 | 1024 | 2.9 | 0.0 |
| 1 | `concat_dim0_tail_f32` | 102400 | 256 | 7.3 | 3.9 |
| 2 | `cpy_scalar<&` | 10240 | 64 | 4.2 | 4.1 |
| 3 | `__amd_rocclr_copyBufferRectAligned` | 163840 | 16 | 8.6 | 4.1 |
| 4 | `k_bin_bcast<&` | 5120 | 128 | 1.3 | 3.6 |
| 5 | `cpy_scalar<&` | 10240 | 64 | 2.4 | 3.3 |
| 6 | `__amd_rocclr_copyBufferRectAligned` | 163840 | 16 | 3.7 | 3.4 |
| 7 | `k_bin_bcast<&` | 5120 | 128 | 1.3 | 3.4 |
| 8 | `k_bin_bcast<&` | 5120 | 128 | 2.7 | 4.0 |
| 9 | `cpy_scalar<&` | 10240 | 64 | 1.7 | 3.4 |
| 10 | `__amd_rocclr_copyBufferRectAligned` | 163840 | 16 | 3.7 | 3.4 |
| 11 | `k_bin_bcast<&` | 5120 | 128 | 1.3 | 3.3 |
| 12 | `k_bin_bcast<&` | 5120 | 128 | 1.3 | 3.3 |
| 13 | `cpy_scalar<&` | 10240 | 64 | 1.7 | 3.4 |
| 14 | `__amd_rocclr_copyBufferRectAligned` | 163840 | 16 | 3.7 | 3.4 |
| 15 | `k_bin_bcast<&` | 5120 | 128 | 1.3 | 3.4 |
| 16 | `k_bin_bcast<&` | 5120 | 128 | 1.3 | 3.5 |
| 17 | `unary_op_kernel<&` | 10240 | 256 | 2.3 | 3.8 |
| 18 | `__amd_rocclr_copyBuffer` | 2560 | 512 | 1.2 | 3.8 |
| 19 | `k_bin_bcast<&` | 5120 | 128 | 1.3 | 3.5 |
| 20 | `k_bin_bcast<&` | 5120 | 128 | 1.3 | 3.6 |
| 21 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, false>` | 4096 | 1024 | 5.1 | 3.9 |

## 그 밖 구간: 58번 나옴 (1.0/토큰), 커널 32개, 앞 AR 끝 → 다음 AR 끝 385.0 µs = 커널 278.8 + 빈틈 105.0
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 4.1 | 0.0 |
| 1 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 14.3 | 2.5 |
| 2 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 20.8 | 2.9 |
| 3 | `mul_mat_vec_f<__hip_bfloat16, float, 1, 256, false, false>` | 32768 | 256 | 4.7 | 2.9 |
| 4 | `idx_k_pool_f32<false>` | 32 | 32 | 9.4 | 2.9 |
| 5 | `mul_mat_vec_q<t6, 1, false, false, false>` | 196608 | 32 | 55.2 | 3.0 |
| 6 | `rms_norm_mul_rope_multi_f32<128, false, float>` | 1536 | 128 | 6.3 | 2.8 |
| 7 | `mul_mat_vec_q<t6, 1, false, false, false>` | 8192 | 32 | 4.4 | 2.5 |
| 8 | `mul_mat_vec_q<t6, 1, false, false, false>` | 8192 | 32 | 5.0 | 2.4 |
| 9 | `rms_norm_mul_rope_multi_f32<128, false, __half>` | 128 | 128 | 6.2 | 3.6 |
| 10 | `k_set_rows<float, long, __half>` | 256 | 256 | 3.7 | 4.1 |
| 11 | `fill_kernel<__half>` | 256 | 256 | 2.2 | 4.1 |
| 12 | `mul_mat_vec_f<__hip_bfloat16, float, 1, 256, false, false>` | 131072 | 256 | 18.4 | 3.4 |
| 13 | `rms_norm_mul_rope_multi_f32<32, false, float>` | 128 | 32 | 6.5 | 3.9 |
| 14 | `k_get_rows_float<__half, float>` | 16384 | 256 | 4.3 | 3.9 |
| 15 | `fill_kernel<float>` | 256 | 256 | 2.3 | 3.7 |
| 16 | `lightning_indexer_kernel_vec<8, 64, 128l, 4l, t0>` | 256 | 32 | 5.9 | 4.0 |
| 17 | `k_argsort_f32_i32<` | 64 | 64 | 8.4 | 4.1 |
| 18 | `__amd_rocclr_copyBufferRectAligned` | 256 | 256 | 2.5 | 4.1 |
| 19 | `top_k_mask_kernel<__half>` | 512 | 512 | 5.2 | 4.0 |
| 20 | `flash_attn_tile<256, 256, 1, 4, false>` | 3072 | 32 | 9.8 | 4.0 |
| 21 | `flash_attn_combine_results<256>` | 3072 | 256 | 3.9 | 3.7 |
| 22 | `k_gate_sigmoid_mul_q8` | 3072 | 256 | 2.8 | 4.1 |
| 23 | `mul_mat_vec_q_comm_out<t8, 1, 8>` | 81920 | 256 | 45.9 | 4.0 |
| 24 | `k_comm_wait_add` | 1024 | 1024 | 12.6 | 3.0 |
| 25 | `k_get_rows_float<float, float>` | 2560 | 256 | 2.4 | 2.7 |
| 26 | `k_get_rows_float<float, float>` | 10240 | 256 | 1.8 | 2.4 |
| 27 | `scale_f32<float>` | 256 | 256 | 1.6 | 2.8 |
| 28 | `k_get_rows_float<float, float>` | 256 | 256 | 1.4 | 2.3 |
| 29 | `unary_op_kernel<&` | 256 | 256 | 1.5 | 2.7 |
| 30 | `scale_f32<float>` | 256 | 256 | 1.0 | 2.3 |
| 31 | `dsv4_hc_post_f32<false, false>` | 10240 | 256 | 1.9 | 2.4 |
| 32 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, false>` | 4096 | 1024 | 3.5 | 2.6 |

## MoE 구간: 58번 나옴 (1.0/토큰), 커널 11개, 앞 AR 끝 → 다음 AR 끝 216.7 µs = 커널 179.0 + 빈틈 37.6
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, false>` | 4096 | 1024 | 3.5 | 0.0 |
| 1 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 16.9 | 2.8 |
| 2 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 20.4 | 2.6 |
| 3 | `mul_mat_vec_f<__hip_bfloat16, float, 1, 256, false, false>` | 131072 | 256 | 16.2 | 2.6 |
| 4 | `topk_moe_softmax_cuda<512>` | 256 | 32 | 4.8 | 3.0 |
| 5 | `mul_mat_vec_q_glu_q8<t23, 1>` | 102400 | 1024 | 49.4 | 3.0 |
| 6 | `mul_mat_vec_q<t20, 1, false, false, false>` | 204800 | 32 | 27.8 | 5.8 |
| 7 | `moe_weighted_reduction_f32_out` | 2560 | 256 | 4.7 | 5.8 |
| 8 | `quantize_q8_1` | 2560 | 256 | 2.4 | 3.2 |
| 9 | `mul_mat_vec_q_glu_q8<t6, 1>` | 20480 | 1024 | 12.9 | 2.6 |
| 10 | `mul_mat_vec_q_shexp_tail<t6, 1>` | 81920 | 1024 | 18.6 | 2.9 |
| 11 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 4.4 | 2.9 |

## 그 밖 구간: 57번 나옴 (0.9/토큰), 커널 11개, 앞 AR 끝 → 다음 AR 끝 67.6 µs = 커널 26.6 + 빈틈 40.7
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, false, false, true>` | 4096 | 1024 | 6.8 | 0.0 |
| 1 | `k_bin_bcast<&` | 5120 | 128 | 2.2 | 3.7 |
| 2 | `reduce_rows_f32<false>` | 2048 | 512 | 3.8 | 4.0 |
| 3 | `scale_f32<float>` | 256 | 256 | 2.2 | 4.0 |
| 4 | `unary_op_kernel<&` | 256 | 256 | 2.3 | 3.9 |
| 5 | `unary_op_kernel<&` | 256 | 256 | 2.4 | 3.6 |
| 6 | `op_clamp_kernel<float>` | 256 | 256 | 2.4 | 3.8 |
| 7 | `unary_op_kernel<&` | 256 | 256 | 2.3 | 4.0 |
| 8 | `k_bin_bcast<&` | 2 | 2 | 1.4 | 3.5 |
| 9 | `unary_op_kernel<&` | 256 | 256 | 2.2 | 3.8 |
| 10 | `k_bin_bcast<&` | 5120 | 128 | 1.6 | 3.2 |
| 11 | `rms_norm_f32<1024, 1, true, true, false, false, false, false, false>` | 4096 | 1024 | 2.9 | 3.4 |

## MoE 구간: 37번 나옴 (0.6/토큰), 커널 11개, 앞 AR 끝 → 다음 AR 끝 194.4 µs = 커널 164.8 + 빈틈 30.4
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 21.6 | 0.0 |
| 1 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 10.1 | 4.0 |
| 2 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 19.2 | 1.9 |
| 3 | `mul_mat_vec_f<__hip_bfloat16, float, 1, 256, false, false>` | 131072 | 256 | 16.1 | 3.8 |
| 4 | `topk_moe_softmax_cuda<512>` | 256 | 32 | 4.4 | 2.6 |
| 5 | `mul_mat_vec_q_glu_q8<t23, 1>` | 102400 | 1024 | 48.5 | 2.5 |
| 6 | `mul_mat_vec_q<t20, 1, false, false, false>` | 204800 | 32 | 24.8 | 3.0 |
| 7 | `moe_weighted_reduction_f32_out` | 2560 | 256 | 4.1 | 2.8 |
| 8 | `mul_mat_vec_q_glu_q8<t6, 1>` | 20480 | 1024 | 12.9 | 4.4 |
| 9 | `quantize_q8_1` | 2560 | 256 | 1.8 | -12.0 |
| 10 | `mul_mat_vec_q_shexp_tail<t6, 1>` | 81920 | 1024 | 18.1 | 14.9 |
| 11 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 4.2 | 2.5 |

## MoE 구간: 6번 나옴 (0.1/토큰), 커널 19개, 앞 AR 끝 → 다음 AR 끝 409.2 µs = 커널 355.4 + 빈틈 52.3
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 23.6 | 0.0 |
| 1 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 9.7 | 5.4 |
| 2 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 17.7 | 2.2 |
| 3 | `mul_mat_vec_f<__hip_bfloat16, float, 1, 256, false, false>` | 131072 | 256 | 16.1 | 2.1 |
| 4 | `topk_moe_softmax_cuda<512>` | 256 | 32 | 4.7 | 4.3 |
| 5 | `mul_mat_vec_q_glu_q8<t23, 1>` | 102400 | 1024 | 49.1 | -1.1 |
| 6 | `mul_mat_vec_q<t20, 1, false, false, false>` | 204800 | 32 | 25.2 | 4.5 |
| 7 | `moe_weighted_reduction_f32_out` | 2560 | 256 | 4.0 | 5.2 |
| 8 | `mul_mat_vec_q_glu_q8<t6, 1>` | 20480 | 1024 | 12.7 | 3.4 |
| 9 | `quantize_q8_1` | 2560 | 256 | 2.0 | -12.4 |
| 10 | `mul_mat_vec_q_shexp_tail<t6, 1>` | 81920 | 1024 | 18.0 | 16.9 |
| 11 | `rms_norm_hcpost_one_block<4, true>` | 1024 | 1024 | 11.8 | 3.2 |
| 12 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 15.0 | 2.2 |
| 13 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 20.6 | 0.3 |
| 14 | `mul_mat_vec_q<t6, 1, false, false, false>` | 262144 | 32 | 72.1 | 3.7 |
| 15 | `ssm_conv_silu_norm_pair_f32<4ul, true>` | 5120 | 128 | 3.5 | 6.5 |
| 16 | `mul_mat_vec_q_gdn_gates<t8>` | 1536 | 32 | 5.7 | 2.1 |
| 17 | `gated_delta_net_cuda<128, false, false, 4, true>` | 24576 | 32 | 15.4 | 2.2 |
| 18 | `mul_mat_vec_q_comm_out<t6, 1, 8>` | 81920 | 256 | 30.2 | 3.6 |
| 19 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 21.8 | 1.8 |

## 그 밖 구간: 3번 나옴 (0.1/토큰), 커널 24개, 앞 AR 끝 → 다음 AR 끝 339.7 µs = 커널 263.4 + 빈틈 79.8
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 4.6 | 0.0 |
| 1 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 13.9 | 3.0 |
| 2 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 20.5 | 2.6 |
| 3 | `mul_mat_vec_f<__hip_bfloat16, float, 1, 256, false, false>` | 32768 | 256 | 5.7 | 2.7 |
| 4 | `idx_k_pool_f32<false>` | 32 | 32 | 9.3 | 2.9 |
| 5 | `mul_mat_vec_q<t6, 1, false, false, false>` | 196608 | 32 | 54.4 | 5.4 |
| 6 | `rms_norm_mul_rope_multi_f32<128, false, float>` | 1536 | 128 | 6.6 | 4.6 |
| 7 | `mul_mat_vec_q<t6, 1, false, false, false>` | 8192 | 32 | 4.6 | 2.5 |
| 8 | `mul_mat_vec_q<t6, 1, false, false, false>` | 8192 | 32 | 4.7 | 1.3 |
| 9 | `rms_norm_mul_rope_multi_f32<128, false, __half>` | 128 | 128 | 5.4 | 7.0 |
| 10 | `k_set_rows<float, long, __half>` | 256 | 256 | 2.1 | 1.1 |
| 11 | `mul_mat_vec_f<__hip_bfloat16, float, 1, 256, false, false>` | 131072 | 256 | 15.9 | 0.5 |
| 12 | `fill_kernel<__half>` | 256 | 256 | 1.6 | -15.7 |
| 13 | `rms_norm_mul_rope_multi_f32<32, false, float>` | 128 | 32 | 5.5 | 18.3 |
| 14 | `k_get_rows_float<__half, float>` | 16384 | 256 | 3.0 | 3.8 |
| 15 | `fill_kernel<float>` | 256 | 256 | 2.3 | 0.9 |
| 16 | `lightning_indexer_kernel_vec<8, 64, 128l, 4l, t0>` | 256 | 32 | 6.1 | 6.5 |
| 17 | `k_argsort_f32_i32<` | 64 | 64 | 8.7 | 3.8 |
| 18 | `__amd_rocclr_copyBufferRectAligned` | 256 | 256 | 2.5 | 3.9 |
| 19 | `top_k_mask_kernel<__half>` | 512 | 512 | 5.4 | 4.6 |
| 20 | `flash_attn_tile<256, 256, 1, 4, false>` | 3072 | 32 | 9.5 | 7.5 |
| 21 | `flash_attn_combine_results<256>` | 3072 | 256 | 3.7 | 1.3 |
| 22 | `k_gate_sigmoid_mul_q8` | 3072 | 256 | 2.9 | 4.1 |
| 23 | `mul_mat_vec_q_comm_out<t8, 1, 8>` | 81920 | 256 | 45.4 | 1.9 |
| 24 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 18.8 | 2.3 |
