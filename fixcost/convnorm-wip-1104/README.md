# conv + q/k norm 묶기 — 미완(빌드·검증 안 함), 2026-11-04 17:40

`convnorm-wip.patch` 는 llama.cpp 트리(`patches/llama-e09a78a-engine2n-t5.patch` 적용 뒤) 기준 diff 다. 적용: `git -C llama.cpp apply ../fixcost/convnorm-wip-1104/convnorm-wip.patch`.

- 내용: 1토큰 SSM_CONV → SILU [→ 뷰] → GDN q/k 의 RMS_NORM → SCALE 쌍(`rms_norm_scale_pair_f32`)을 한 커널(`ssm_conv_silu_norm_pair_f32`, ssm-conv.cu)로.
  128 채널 블록마다 ssm_conv_f32<true,128,4> 와 같은 식으로 conv+silu, q/k 머리 블록은 출력 128개를 공유 메모리에 두고 워프 0 이 norm 쌍 커널과 같은 코드로 정규화.
  토큰당 −36 커널 예상. 꺼짐 `GGML_CUDA_NO_CONV_NORM_PAIR=1`, 검증 `GGML_CUDA_CONV_NORM_VERIFY=1`(묶은 결과와 두 커널 결과를 비트 비교).
- 상태: 코드만 씀. 빌드·검증·A/B 안 함(사용자 이동 전 정리). 트리에서는 빼 두었고 푸시한 패치에도 없음.
- 다음: 적용 → 빌드 → `GGML_CUDA_CONV_NORM_VERIFY=1` 2노드 실행(같음 + 해시 6개) → prof2node.sh + `tools/bench/kdiff.py` 로 커널 시간 → 끔/켬 A/B.
- 같은 사슬의 다음 단계: conv 상태 concat(`concat_dim0_tail_direct_f32`)까지 합치기. 그래프에서 CONCAT 과 SSM_CONV 사이에 뷰·생략된 gather 노드가 끼어 있어
  연속 묶음이 아님 → 사이 노드가 모두 실행 안 되는지 확인하고, 나중 노드를 건너뛰는 장치가 필요.
