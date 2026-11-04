# halogen 0.18.17 vs 우리 2노드 엔진 — GPU 사용률과 토큰 한 단계 (2026-11-04)

이 폴더는 `experiments/halogen/`(저장소 밖 작업 폴더)의 사본이다: `run/`(실행기·표본기·요청), `analysis/ktrace_steps.py`,
`watch-*/`(측정 결과 — 50 MB 커널 기록 CSV 는 빼고 `ktrace_steps.txt` 분석 결과와 sha256 만), `ours/`(같은 표본기로 잰 우리 2노드 A·B).

## 방법
- `run/run_watch.sh`: halogen(A 단독, 기본 설정, v2 체크포인트)에 우리 엔진과 같은 6 프롬프트(`eval/spec_prompts.json`, chat, temperature 0, 256 토큰)를
  serial·mtp 로 보내며 `run/gpu_fast.py` 로 20 ms 마다 `gpu_busy_percent`(작업 표시줄 그래프와 같은 값)·gpu_metrics 기록.
- `KTRACE=1`: flash_serve 를 rocprofv3 `--kernel-trace --memory-copy-trace` 아래에서(10-28 의 `--runtime-trace` 조합은 커널 Start=End 였음 → 이번엔 GPU 시각 정상).
  분석 `analysis/ktrace_steps.py`(k_argmax_final 사이 = 디코드 한 토큰).
- 우리 엔진: 2노드 H5, `GGML_RPC_COMM_DEV=usb4_rdma0`, 같은 샘플러를 A·B 에서 60 s(추론 구간만 잘라 계산).
- 기록: `runs/watch-20261104-111943`(측정), `runs/watch-ktrace-20261104-113312`(커널 기록).

## 결과
| | halogen serial (1노드) | halogen mtp | 우리 2노드 (노드마다) |
|---|---|---|---|
| decode tok/s | 36.6–37.9 | 48.9–68.5 | 32.9 (같은 날) |
| gpu_busy_percent 평균 / 중앙 | 91.2 / 97 | 86.2 / 91 | 81.7 / 88 |
| 95% 이상인 20 ms 표본 | 61% | 37% | 0% (최대 92–93) |
| gfxclk 중앙 | 2497 | 2295 | A 2612 · B 2487 |

halogen 디코드 한 토큰(커널 기록, 221 토큰 중앙):
- 커널 644개(우리: 모델 절반인 노드마다 1806개), 단계 27.75 ms 중 커널이 돈 시간 25.55 ms(**92.1%**).
- 쉰 시간 2.19 ms = 커널 사이 짧은 빈틈 1.59 ms(빈틈 중앙 2.2 µs·p90 5.0 µs — 우리와 같은 수준) + 긴 대기 0.49 ms(토큰마다 1.5번, n-gram 표를 CPU 가 읽는 D2H→H2D 뒤 copyBuffer).
- 층당 ≈13 커널: `k_hc6_fused3` ×2(hyper-connection 묶음), `k_ht_lin_grp` + `k_ht_lin_grp_rt`(전문가 묶음 선형), `k_i4r_rows_gl/fl`, `k_ht_lin`, `k_dn_recur_step`(DeltaNet) 등.
- 10-28 HIP 기록과 합치면: CPU 가 한 토큰 커널을 ≈4.2 ms 에 모두 넣고 동기화는 토큰마다 1번, argmax 는 GPU.

우리 2노드(11-04 영수증): 단계 32.2 ms 중 GPU 계산 23.8(74%, 커널 사이 빈틈 포함) + 단계 경계 2.9 + 호스트 왕복 2.3 + 상대 기다림 1.8 + 링크 멈춤 0.9.

## 해석
- halogen 이 GPU 를 거의 100% 로 두는 이유: (1) 토큰 안에 호스트 왕복이 n-gram 한 번뿐(우리는 AR 96번), (2) 토큰 전체를 미리 넣고 한 번 동기화, (3) 커널 수가 우리 노드당의 1/3(층당 13 vs ≈37).
- 커널 사이 빈틈 자체(2.2 µs)는 우리와 같다 → 차이는 빈틈의 "수"와 AR 기다림.
- 깊은 큐: halogen 도 644 커널을 앞서 넣는데 빈틈이 커지지 않는다. 우리 ZC=3 에서 본 커널당 +0.3–0.6 µs 는 큐 깊이만의 문제가 아닐 수 있음(가설: 같은 스트림의 기다림 커널이 호스트 메모리를 도는 동안의 영향, 프록시 CPU 스핀) — 확인 필요.
