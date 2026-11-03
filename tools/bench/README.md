# 측정 스크립트 (A 에서 실행)

스크래치(tmpfs)는 재부팅 때 지워지므로 측정 스크립트를 여기에 둔다. 스크립트 안의 `S=` 는 작업 폴더(로그)다.

| 파일 | 하는 일 |
|---|---|
| `srv-probe.sh` | llama-server 로 6 프롬프트 생성 속도(`run_server.sh` 와 같은 구성). `SRV_ENV`, `SRV_ENV_B`(B 만 다른 환경), `SPEC_EXTRA`, `A_WRAP` |
| `node-ab.sh` | 노드별 서버 환경 A/B(`RUNS="none:<cfg> mtp:<cfg>"`, `SA_<cfg>`/`SB_<cfg>`, 설정별 바이너리 `BIN_<cfg>`), 회마다 gm·스레드·prof, RDMA 가 안 올라오면 3번까지 다시 |
| `hp-block.sh` | hot 폴링 비교 한 덩어리: 디코드·MTP 번갈아 2회씩 + pp512 |
| `mtpn.sh`, `pmin.sh` | MTP 초안 길이(`--spec-draft-n-max`)·`--spec-draft-p-min` 쓸기 |
| `tp-bench-x.sh` | 2노드 llama-bench(`SRVX` 로 두 서버 환경) |
| `tl2node.sh` | **2노드 시간 명세용 기록**: 두 rpc-server 를 rocprofv3 아래에서(커널·복사 기록), AR 타임라인(`GGML_RPC_COMM_PROF_TL`)·comm_prof·gm·시계 기록과 함께. 결과 `runs/tl2node-<tag>-<시각>/{a,b}/` |
| `tokspec.py` | 1노드 커널 기록 → 토큰 1개 시간 명세(TP 성격별) |
| `tl2spec.py` | `tl2node.sh` 기록 → 2노드 시간 명세·AR 시간 순서(표 + 그림) |
| `gmsum.py`, `profsum.py`, `tlsum.py`, `perprompt.py` | gpu_metrics 요약, comm_prof 블록 평균, AR 타임라인 요약, 프롬프트별 표 |
| `hcmm.py` | rocprofv3 기록 → hc down/up 행렬곱 커널 시간·대역폭 |
| `topk/` | top-k 커널 세 판(원래·DPP·전용) 바이트 비교(`topk_exact.cu`)와 사이클(`topk_cycles.cu`), `run.sh` |

## 2노드 시간 명세 — 할 순서 (2026-11-02 밤 준비)
1. 링크 살리기(절전 뒤): `tools/tbv_hotpoll.sh off`(또는 `on`) — 두 노드 모듈을 다시 올림.
2. 기록: `PROF=1 tools/bench/tl2node.sh dec64 64`(프로파일러 아래, 토큰 64개) + `PROF=0 tools/bench/tl2node.sh dec64np 64`(프로파일러 없이, 같은 타임라인으로 왜곡 확인).
   시험(16 토큰)에서 확인: 두 노드 커널 기록·타임라인·시계 기록이 나옴. 프로파일러 아래 tg16 ≈20–21 tok/s(없으면 ≈29).
3. 분석(`tl2spec.py`, 11-02 첫 판 — RESULTS.md):
   - 노드 안 정렬: rocprof 와 `ggml_time_us` 는 둘 다 CLOCK_MONOTONIC 으로 보임(값 크기 일치). 기준점: `k_comm_wait_add` 커널 끝 ≈ 타임라인 `land` + 해제(수 µs).
     보내기용 D2H 는 coherent 메모리로 가는 복사 커널(`__amd_rocclr_copyBuffer`)이라 복사 기록에 안 잡힘.
   - 노드 사이 정렬: 타임라인의 AR 번호(seq)는 두 노드에서 같은 AR 이다(q=900: 왕복 114 µs). 시계 차이는 같은 q 의 (B.land−A.sent) 와 (A.land−B.sent) 로,
     상대를 기다리지 않은 AR(최솟값 쪽)만 써서 구한다. 더 정확히 하려면 comm init 때 두 서버가 시각을 주고받게(NTP 식) 하는 것을 고려.
   - 명세(노드별, 토큰당): 나뉘는 행렬곱 / hc 행렬곱 / hc 작은 연산 / 라우터·MoE 합치기 / GDN·attn 작은 연산 / 커널 사이 빈틈 / 상대 기다림(`k_comm_wait_add` 안) /
     보내기(부분합 준비 → post) / 호스트 발행 대기.
   - 시간 순서: AR 몇 개를 골라 두 노드의 구간(A=가중치 계산, B=통신, ...)을 같은 시간축에 — 표 + 그림.
