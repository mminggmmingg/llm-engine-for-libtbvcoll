
## 그 밖 구간: 2340번 나옴 (39.0/토큰), 커널 5개, 앞 AR 끝 → 다음 AR 끝 187.2 µs = 커널 173.0 + 빈틈 14.0
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 25.1 | 0.0 |
| 1 | `k_seg_moe_head<true, false, true>` | 40960 | 1024 | 134.5 | 2.8 |
| 2 | `quantize_q8_1` | 2560 | 256 | 1.9 | 3.0 |
| 3 | `mul_mat_vec_q_glu_q8<t6, 1>` | 20480 | 1024 | 13.4 | 2.9 |
| 4 | `mul_mat_vec_q_shexp_tail<t6, 1>` | 81920 | 1024 | 18.6 | 2.7 |
| 5 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 4.2 | 2.6 |

## 그 밖 구간: 1740번 나옴 (29.0/토큰), 커널 8개, 앞 AR 끝 → 다음 AR 끝 210.1 µs = 커널 187.0 + 빈틈 23.0
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 4.2 | 0.0 |
| 1 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 15.3 | 3.0 |
| 2 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 21.4 | 2.7 |
| 3 | `mul_mat_vec_q<t6, 1, false, false, false>` | 262144 | 32 | 70.6 | 3.0 |
| 4 | `ssm_conv_silu_norm_pair_f32<4ul, true>` | 5120 | 128 | 3.6 | 3.1 |
| 5 | `mul_mat_vec_q_gdn_gates<t8>` | 1536 | 32 | 5.8 | 2.7 |
| 6 | `gated_delta_net_cuda<128, false, false, 4, true>` | 24576 | 32 | 15.9 | 3.0 |
| 7 | `mul_mat_vec_q_comm_out<t6, 1, 8>` | 81920 | 256 | 30.7 | 3.0 |
| 8 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 24.8 | 2.6 |

## 그 밖 구간: 540번 나옴 (9.0/토큰), 커널 22개, 앞 AR 끝 → 다음 AR 끝 324.5 µs = 커널 260.6 + 빈틈 63.2
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 4.2 | 0.0 |
| 1 | `k_seg_moe_head<true, false, false>` | 40960 | 1024 | 44.2 | 2.7 |
| 2 | `idx_k_pool_f32<false>` | 32 | 32 | 9.4 | 3.0 |
| 3 | `mul_mat_vec_q<t6, 1, false, false, false>` | 196608 | 32 | 54.8 | 2.8 |
| 4 | `rms_norm_mul_rope_multi_f32<128, false, float>` | 1536 | 128 | 6.5 | 2.8 |
| 5 | `mul_mat_vec_q<t6, 1, false, false, false>` | 8192 | 32 | 4.7 | 2.5 |
| 6 | `mul_mat_vec_q<t6, 1, false, false, false>` | 8192 | 32 | 4.6 | 2.5 |
| 7 | `rms_norm_mul_rope_multi_f32<128, false, __half>` | 128 | 128 | 5.7 | 2.7 |
| 8 | `k_set_rows<float, long, __half>` | 256 | 256 | 2.2 | 3.0 |
| 9 | `fill_kernel<__half>` | 256 | 256 | 1.7 | 3.0 |
| 10 | `mul_mat_vec_f<__hip_bfloat16, float, 1, 256, false, false>` | 131072 | 256 | 17.2 | 3.0 |
| 11 | `rms_norm_mul_rope_multi_f32<32, false, float>` | 128 | 32 | 5.7 | 2.7 |
| 12 | `k_get_rows_float<__half, float>` | 16384 | 256 | 2.8 | 3.0 |
| 13 | `fill_kernel<float>` | 256 | 256 | 1.4 | 2.6 |
| 14 | `lightning_indexer_kernel_vec<8, 64, 128l, 4l, t0>` | 256 | 32 | 4.5 | 2.9 |
| 15 | `k_argsort_f32_i32<` | 64 | 64 | 7.0 | 3.0 |
| 16 | `__amd_rocclr_copyBufferRectAligned` | 256 | 256 | 1.7 | 3.0 |
| 17 | `top_k_mask_kernel<__half>` | 512 | 512 | 3.6 | 2.9 |
| 18 | `flash_attn_tile<256, 256, 1, 4, false>` | 3072 | 32 | 6.4 | 3.0 |
| 19 | `flash_attn_combine_results<256>` | 3072 | 256 | 2.6 | 2.7 |
| 20 | `k_gate_sigmoid_mul_q8` | 3072 | 256 | 2.3 | 3.0 |
| 21 | `mul_mat_vec_q_comm_out<t8, 1, 8>` | 81920 | 256 | 44.4 | 2.9 |
| 22 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 26.0 | 2.9 |

## 그 밖 구간: 240번 나옴 (4.0/토큰), 커널 13개, 앞 AR 끝 → 다음 AR 끝 408.2 µs = 커널 371.1 + 빈틈 37.4
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 24.5 | 0.0 |
| 1 | `k_seg_moe_head<true, false, true>` | 40960 | 1024 | 134.9 | 2.7 |
| 2 | `quantize_q8_1` | 2560 | 256 | 1.9 | 3.0 |
| 3 | `mul_mat_vec_q_glu_q8<t6, 1>` | 20480 | 1024 | 13.3 | 2.9 |
| 4 | `mul_mat_vec_q_shexp_tail<t6, 1>` | 81920 | 1024 | 18.6 | 2.6 |
| 5 | `rms_norm_hcpost_one_block<4, true>` | 1024 | 1024 | 12.5 | 2.7 |
| 6 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 15.2 | 3.0 |
| 7 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 21.3 | 2.8 |
| 8 | `mul_mat_vec_q<t6, 1, false, false, false>` | 262144 | 32 | 71.8 | 3.1 |
| 9 | `ssm_conv_silu_norm_pair_f32<4ul, true>` | 5120 | 128 | 4.0 | 2.9 |
| 10 | `mul_mat_vec_q_gdn_gates<t8>` | 1536 | 32 | 5.6 | 2.6 |
| 11 | `gated_delta_net_cuda<128, false, false, 4, true>` | 24576 | 32 | 15.7 | 2.9 |
| 12 | `mul_mat_vec_q_comm_out<t6, 1, 8>` | 81920 | 256 | 30.9 | 3.0 |
| 13 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 24.4 | 2.7 |

## 그 밖 구간: 120번 나옴 (2.0/토큰), 커널 8개, 앞 AR 끝 → 다음 AR 끝 272.7 µs = 커널 248.0 + 빈틈 24.3
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, false>` | 4096 | 1024 | 3.5 | 0.0 |
| 1 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 16.2 | 3.0 |
| 2 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 21.5 | 3.1 |
| 3 | `mul_mat_vec_q<t6, 1, false, false, false>` | 262144 | 32 | 65.8 | 3.1 |
| 4 | `ssm_conv_silu_norm_pair_f32<4ul, true>` | 5120 | 128 | 3.9 | 3.1 |
| 5 | `mul_mat_vec_q_gdn_gates<t8>` | 1536 | 32 | 5.9 | 2.9 |
| 6 | `gated_delta_net_cuda<128, false, false, 4, true>` | 24576 | 32 | 15.6 | 3.0 |
| 7 | `mul_mat_vec_q_comm_out<t6, 1, 8>` | 81920 | 256 | 30.5 | 3.0 |
| 8 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 88.5 | 2.8 |

## 그 밖 구간: 120번 나옴 (2.0/토큰), 커널 27개, 앞 AR 끝 → 다음 AR 끝 525.4 µs = 커널 447.2 + 빈틈 77.6
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 24.4 | 0.0 |
| 1 | `k_seg_moe_head<true, false, true>` | 40960 | 1024 | 135.6 | 2.7 |
| 2 | `quantize_q8_1` | 2560 | 256 | 1.7 | 2.8 |
| 3 | `mul_mat_vec_q_glu_q8<t6, 1>` | 20480 | 1024 | 13.5 | 2.7 |
| 4 | `mul_mat_vec_q_shexp_tail<t6, 1>` | 81920 | 1024 | 18.8 | 2.7 |
| 5 | `rms_norm_hcpost_one_block<4, true>` | 1024 | 1024 | 12.3 | 2.7 |
| 6 | `k_seg_moe_head<true, false, false>` | 40960 | 1024 | 44.3 | 2.7 |
| 7 | `idx_k_pool_f32<false>` | 32 | 32 | 9.5 | 3.0 |
| 8 | `mul_mat_vec_q<t6, 1, false, false, false>` | 196608 | 32 | 54.6 | 3.0 |
| 9 | `rms_norm_mul_rope_multi_f32<128, false, float>` | 1536 | 128 | 6.4 | 2.8 |
| 10 | `mul_mat_vec_q<t6, 1, false, false, false>` | 8192 | 32 | 4.8 | 2.5 |
| 11 | `mul_mat_vec_q<t6, 1, false, false, false>` | 8192 | 32 | 4.5 | 2.5 |
| 12 | `rms_norm_mul_rope_multi_f32<128, false, __half>` | 128 | 128 | 5.8 | 2.6 |
| 13 | `k_set_rows<float, long, __half>` | 256 | 256 | 2.2 | 3.0 |
| 14 | `fill_kernel<__half>` | 256 | 256 | 1.7 | 3.0 |
| 15 | `mul_mat_vec_f<__hip_bfloat16, float, 1, 256, false, false>` | 131072 | 256 | 17.0 | 3.0 |
| 16 | `rms_norm_mul_rope_multi_f32<32, false, float>` | 128 | 32 | 5.7 | 2.7 |
| 17 | `k_get_rows_float<__half, float>` | 16384 | 256 | 2.7 | 3.0 |
| 18 | `fill_kernel<float>` | 256 | 256 | 1.4 | 2.6 |
| 19 | `lightning_indexer_kernel_vec<8, 64, 128l, 4l, t0>` | 256 | 32 | 4.4 | 3.0 |
| 20 | `k_argsort_f32_i32<` | 64 | 64 | 7.0 | 3.0 |
| 21 | `__amd_rocclr_copyBufferRectAligned` | 256 | 256 | 1.6 | 3.0 |
| 22 | `top_k_mask_kernel<__half>` | 512 | 512 | 3.6 | 2.9 |
| 23 | `flash_attn_tile<256, 256, 1, 4, false>` | 3072 | 32 | 6.4 | 3.0 |
| 24 | `flash_attn_combine_results<256>` | 3072 | 256 | 2.5 | 2.7 |
| 25 | `k_gate_sigmoid_mul_q8` | 3072 | 256 | 2.1 | 3.0 |
| 26 | `mul_mat_vec_q_comm_out<t8, 1, 8>` | 81920 | 256 | 44.7 | 3.0 |
| 27 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 31.0 | 3.0 |

## 그 밖 구간: 60번 나옴 (1.0/토큰), 커널 7개, 앞 AR 끝 → 다음 AR 끝 325.1 µs = 커널 305.0 + 빈틈 20.0
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 86.5 | 0.0 |
| 1 | `k_seg_moe_head<true, false, true>` | 40960 | 1024 | 119.7 | 2.8 |
| 2 | `k_get_rows_float<float, float>` | 92160 | 256 | 6.1 | 3.1 |
| 3 | `quantize_q8_1` | 2560 | 256 | 2.0 | 2.9 |
| 4 | `mul_mat_vec_q<t8, 1, false, false, false>` | 81920 | 32 | 36.8 | 2.7 |
| 5 | `k_bin_bcast<&` | 5120 | 128 | 1.8 | 3.0 |
| 6 | `mul_mat_vec_q<t8, 1, false, false, false>` | 327680 | 32 | 135.0 | 2.5 |
| 7 | `rms_norm_f32<1024, 1, true, true, false, false, false, false, false>` | 4096 | 1024 | 3.7 | 2.8 |

## 그 밖 구간: 60번 나옴 (1.0/토큰), 커널 4개, 앞 AR 끝 → 다음 AR 끝 51.9 µs = 커널 40.4 + 빈틈 11.6
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, false, false, false>` | 4096 | 1024 | 3.7 | 0.0 |
| 1 | `quantize_q8_1` | 2560 | 256 | 1.8 | 2.7 |
| 2 | `mul_mat_vec_q_glu_q8<t6, 1>` | 20480 | 1024 | 13.4 | 3.0 |
| 3 | `mul_mat_vec_q_shexp_tail<t6, 1>` | 81920 | 1024 | 20.2 | 3.1 |
| 4 | `rms_norm_f32<1024, 1, true, true, false, false, false, false, true>` | 4096 | 1024 | 4.7 | 2.8 |

## 그 밖 구간: 60번 나옴 (1.0/토큰), 커널 11개, 앞 AR 끝 → 다음 AR 끝 51.2 µs = 커널 20.2 + 빈틈 30.8
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, false, false, true>` | 4096 | 1024 | 4.7 | 0.0 |
| 1 | `k_bin_bcast<&` | 5120 | 128 | 2.1 | 3.0 |
| 2 | `reduce_rows_f32<false>` | 2048 | 512 | 2.1 | 3.0 |
| 3 | `scale_f32<float>` | 256 | 256 | 1.7 | 2.9 |
| 4 | `unary_op_kernel<&` | 256 | 256 | 1.5 | 2.9 |
| 5 | `unary_op_kernel<&` | 256 | 256 | 1.5 | 2.6 |
| 6 | `op_clamp_kernel<float>` | 256 | 256 | 1.5 | 3.0 |
| 7 | `unary_op_kernel<&` | 256 | 256 | 1.6 | 2.9 |
| 8 | `k_bin_bcast<&` | 2 | 2 | 1.5 | 2.4 |
| 9 | `unary_op_kernel<&` | 256 | 256 | 1.5 | 2.9 |
| 10 | `k_bin_bcast<&` | 5120 | 128 | 2.2 | 2.4 |
| 11 | `rms_norm_f32<1024, 1, true, true, false, false, false, false, false>` | 4096 | 1024 | 2.7 | 2.5 |

## 그 밖 구간: 60번 나옴 (1.0/토큰), 커널 21개, 앞 AR 끝 → 다음 AR 끝 132.0 µs = 커널 51.0 + 빈틈 79.8
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, false, false, false>` | 4096 | 1024 | 2.7 | 0.0 |
| 1 | `concat_dim0_tail_f32` | 102400 | 256 | 5.6 | 3.0 |
| 2 | `cpy_scalar<&` | 10240 | 64 | 2.5 | 3.0 |
| 3 | `__amd_rocclr_copyBufferRectAligned` | 163840 | 16 | 5.7 | 3.0 |
| 4 | `k_bin_bcast<&` | 5120 | 128 | 1.4 | 2.5 |
| 5 | `cpy_scalar<&` | 10240 | 64 | 2.1 | 2.4 |
| 6 | `__amd_rocclr_copyBufferRectAligned` | 163840 | 16 | 3.8 | 2.5 |
| 7 | `k_bin_bcast<&` | 5120 | 128 | 1.3 | 2.5 |
| 8 | `k_bin_bcast<&` | 5120 | 128 | 1.9 | 2.7 |
| 9 | `cpy_scalar<&` | 10240 | 64 | 1.8 | 2.5 |
| 10 | `__amd_rocclr_copyBufferRectAligned` | 163840 | 16 | 3.9 | 2.5 |
| 11 | `k_bin_bcast<&` | 5120 | 128 | 1.3 | 2.5 |
| 12 | `k_bin_bcast<&` | 5120 | 128 | 1.3 | 2.5 |
| 13 | `cpy_scalar<&` | 10240 | 64 | 1.9 | 2.5 |
| 14 | `__amd_rocclr_copyBufferRectAligned` | 163840 | 16 | 3.9 | 2.6 |
| 15 | `k_bin_bcast<&` | 5120 | 128 | 1.3 | 2.6 |
| 16 | `k_bin_bcast<&` | 5120 | 128 | 1.3 | 2.8 |
| 17 | `unary_op_kernel<&` | 10240 | 256 | 1.6 | 2.9 |
| 18 | `__amd_rocclr_copyBuffer` | 2560 | 512 | 1.3 | 3.2 |
| 19 | `k_bin_bcast<&` | 5120 | 128 | 1.3 | 4.2 |
| 20 | `k_bin_bcast<&` | 5120 | 128 | 1.5 | 4.4 |
| 21 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, false>` | 4096 | 1024 | 3.3 | 7.2 |

## 그 밖 구간: 60번 나옴 (1.0/토큰), 커널 13개, 앞 AR 끝 → 다음 AR 끝 416.1 µs = 커널 379.7 + 빈틈 36.8
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 4.1 | 0.0 |
| 1 | `mul_mat_vec_q<t14, 1, false, false, false>` | 10368 | 32 | 13.8 | 2.7 |
| 2 | `k_hc_up_pre<true, 1, false>` | 81920 | 1024 | 22.4 | 2.7 |
| 3 | `mul_mat_vec_q<t6, 1, false, false, false>` | 262144 | 32 | 71.1 | 2.8 |
| 4 | `ssm_conv_silu_norm_pair_f32<4ul, true>` | 5120 | 128 | 3.7 | 3.1 |
| 5 | `mul_mat_vec_q_gdn_gates<t8>` | 1536 | 32 | 5.6 | 2.7 |
| 6 | `gated_delta_net_cuda<128, false, false, 4, true>` | 24576 | 32 | 16.0 | 3.0 |
| 7 | `mul_mat_vec_q_comm_out<t6, 1, 8>` | 81920 | 256 | 30.2 | 2.8 |
| 8 | `rms_norm_hcpost_one_block<4, true>` | 1024 | 1024 | 29.4 | 2.7 |
| 9 | `k_seg_moe_head<true, false, true>` | 40960 | 1024 | 144.3 | 2.7 |
| 10 | `quantize_q8_1` | 2560 | 256 | 1.7 | 2.9 |
| 11 | `mul_mat_vec_q_glu_q8<t6, 1>` | 20480 | 1024 | 13.4 | 2.8 |
| 12 | `mul_mat_vec_q_shexp_tail<t6, 1>` | 81920 | 1024 | 22.1 | 2.7 |
| 13 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 4.7 | 2.7 |

## 그 밖 구간: 60번 나옴 (1.0/토큰), 커널 30개, 앞 AR 끝 → 다음 AR 끝 387.6 µs = 커널 301.2 + 빈틈 85.4
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 4.4 | 0.0 |
| 1 | `k_seg_moe_head<true, false, false>` | 40960 | 1024 | 43.9 | 2.7 |
| 2 | `idx_k_pool_f32<false>` | 32 | 32 | 9.6 | 3.1 |
| 3 | `mul_mat_vec_q<t6, 1, false, false, false>` | 196608 | 32 | 54.4 | 2.8 |
| 4 | `rms_norm_mul_rope_multi_f32<128, false, float>` | 1536 | 128 | 6.5 | 2.8 |
| 5 | `mul_mat_vec_q<t6, 1, false, false, false>` | 8192 | 32 | 4.6 | 2.5 |
| 6 | `mul_mat_vec_q<t6, 1, false, false, false>` | 8192 | 32 | 4.8 | 2.5 |
| 7 | `rms_norm_mul_rope_multi_f32<128, false, __half>` | 128 | 128 | 5.6 | 2.7 |
| 8 | `k_set_rows<float, long, __half>` | 256 | 256 | 2.2 | 3.0 |
| 9 | `fill_kernel<__half>` | 256 | 256 | 1.6 | 3.0 |
| 10 | `mul_mat_vec_f<__hip_bfloat16, float, 1, 256, false, false>` | 131072 | 256 | 17.3 | 2.9 |
| 11 | `rms_norm_mul_rope_multi_f32<32, false, float>` | 128 | 32 | 5.7 | 2.7 |
| 12 | `k_get_rows_float<__half, float>` | 16384 | 256 | 2.8 | 3.0 |
| 13 | `fill_kernel<float>` | 256 | 256 | 1.4 | 2.6 |
| 14 | `lightning_indexer_kernel_vec<8, 64, 128l, 4l, t0>` | 256 | 32 | 4.2 | 3.0 |
| 15 | `k_argsort_f32_i32<` | 64 | 64 | 7.0 | 3.0 |
| 16 | `__amd_rocclr_copyBufferRectAligned` | 256 | 256 | 1.7 | 3.0 |
| 17 | `top_k_mask_kernel<__half>` | 512 | 512 | 3.6 | 3.0 |
| 18 | `flash_attn_tile<256, 256, 1, 4, false>` | 3072 | 32 | 6.3 | 3.0 |
| 19 | `flash_attn_combine_results<256>` | 3072 | 256 | 2.6 | 2.7 |
| 20 | `k_gate_sigmoid_mul_q8` | 3072 | 256 | 2.2 | 3.0 |
| 21 | `mul_mat_vec_q_comm_out<t8, 1, 8>` | 81920 | 256 | 44.5 | 3.0 |
| 22 | `k_comm_wait_add` | 1024 | 1024 | 50.8 | 3.1 |
| 23 | `k_get_rows_float<float, float>` | 2560 | 256 | 2.4 | 2.7 |
| 24 | `k_get_rows_float<float, float>` | 10240 | 256 | 2.0 | 2.4 |
| 25 | `scale_f32<float>` | 256 | 256 | 1.8 | 3.0 |
| 26 | `k_get_rows_float<float, float>` | 256 | 256 | 1.4 | 2.4 |
| 27 | `unary_op_kernel<&` | 256 | 256 | 1.6 | 2.9 |
| 28 | `scale_f32<float>` | 256 | 256 | 1.0 | 2.4 |
| 29 | `dsv4_hc_post_f32<false, false>` | 10240 | 256 | 2.1 | 2.9 |
| 30 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, false>` | 4096 | 1024 | 3.6 | 3.0 |

## 그 밖 구간: 60번 나옴 (1.0/토큰), 커널 5개, 앞 AR 끝 → 다음 AR 끝 201.4 µs = 커널 186.6 + 빈틈 14.3
| # | 커널 | grid | 블록 | µs | 앞 빈틈 µs |
|---:|---|---:|---:|---:|---:|
| 0 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, false>` | 4096 | 1024 | 3.6 | 0.0 |
| 1 | `k_seg_moe_head<true, false, true>` | 40960 | 1024 | 146.7 | 2.7 |
| 2 | `quantize_q8_1` | 2560 | 256 | 2.2 | 3.0 |
| 3 | `mul_mat_vec_q_glu_q8<t6, 1>` | 20480 | 1024 | 13.3 | 2.9 |
| 4 | `mul_mat_vec_q_shexp_tail<t6, 1>` | 81920 | 1024 | 19.0 | 3.0 |
| 5 | `rms_norm_f32<1024, 1, true, true, false, false, true, false, true>` | 4096 | 1024 | 4.6 | 2.6 |
