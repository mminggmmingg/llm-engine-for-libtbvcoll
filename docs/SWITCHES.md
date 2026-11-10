# 패치·환경변수·도구 기록

엔진 패치(`patches/llama-e09a78a-engine2n-t5.patch`)가 더한 것과 켜고 끄는 환경변수를 날짜 순으로 모은 참고 문서다(README 에서 옮김, 2026-11-06).
기본값은 모두 측정으로 정했고, 끄는 스위치는 비교·문제 찾기용이다. 각 항목의 수치와 근거는 [RESULTS.md](../RESULTS.md) 의 같은 날짜 절에 있다.

- 노드 점검 도구(읽기만): [tools/probe/](../tools/probe/) — `gpumetrics.py`(gpu_metrics v3.0 클럭·전력·DRAM 카운터), `clkmon2.sh`, `nodeinfo.sh`,
  HIP 시험 `lat.hip`(발행·동기화 지연), `bw.hip`(메모리 대역폭), `wv.hip`(`hipStreamWaitValue32` 동작),
  `kfloor.hip`(작은 커널 하나의 바닥 비용, 그래프/직접), `bigbuf.hip`(큰 버퍼 안 창 읽기 대역폭). 빌드: `hipcc -O2 --offload-arch=gfx1151 x.hip -o x`
  `ktok.py`(rocprofv3 기록 → 토큰당 커널 수·시간), `memclk_ts.py`(FCLK·UCLK·DRAM 카운터 시계열)
- llama.cpp 패치: [patches/llama-e09a78a-engine2n-t5.patch](../patches/llama-e09a78a-engine2n-t5.patch)
  - RDMA 전송: 보내기 묶음(flush 때 SEND 1번)·받기 바이트 스트림, 송신 슬롯 링(`GGML_RDMA_TX_SLOTS`), 조각 크기·수신 깊이(`GGML_RDMA_CHUNK`, `GGML_RDMA_RX_DEPTH`)
  - 서버 all-reduce: pinned 호스트 버퍼 + 비동기 복사, 양쪽 동시 조각 교환(`GGML_RPC_COMM_SYM_MAX`, `GGML_RPC_COMM_AHEAD`)
  - AR 뒤 발행 겹치기: `GGML_RPC_COMM_OVERLAP=1|2` — 스트림이 pinned 플래그를 기다리게 하고(ggml-cuda `ggml_backend_stream_wait_u32`,
    `hipStreamWaitValue32`) 다음 부분그래프를 먼저 발행, 2 는 도우미 스레드가 상대 부분합을 받는 즉시 플래그를 쓴다
  - 계측: `GGML_RPC_COMM_PROF=N` (AR 단계별·명령별 시간)
  - AR 호출별 기록: `GGML_RPC_COMM_PROF_TRACE=<file>` (`run_tp.sh` 에서 `TRACE=1`)
  - TP 분할(클라이언트): `LLAMA_TP_FFN_GRAN` (FFN 알갱이, 스크립트 기본 32 → 전문가 640 을 320/320), `LLAMA_TP_FFN_SPLIT` (FFN 만 장치 0 몫),
    `LLAMA_TP_SPLIT_DEBUG=1` (0–3층 분할 출력)
  - `run_tp.sh`: `SRV_ENV` 로 두 서버에 환경변수 전달(기본 `GGML_CUDA_DISABLE_GRAPHS=1`), `APREFIX` 로 A 서버를 rocprofv3 아래에서 실행
  - `GGML_RPC_COMM_OVERLAP=3`: AR 이 GPU 를 기다리지 않고 돌아가고 송수신은 별도 스레드(`hipStreamWriteValue32` 플래그). 정확하지만 이 APU 에서는
    펌웨어가 CPU 우선으로 바뀌어 GPU 클럭이 떨어져 느림 → 기본은 2(`run_tp.sh`)
  - `GGML_RPC_SPIN_US=<n>`: 대기가 n µs 만 바쁘게 돌고 잠듦(RDMA 완료 이벤트, 명령 전달 큐, 송수신 스레드). 미설정이면 기존 동작
  - `GGML_RPC_COMM_BF16_MIN=<n>`: 이 원소 수 이상인 부분합을 bf16 으로 보냄(기본 32768, 아주 크게 주면 모두 f32). 측정용
  - `GGML_RPC_COMM_HALF=1|2`(2026-11-08, 기본 0 = f32): ZC=3 decode 부분합을 bf16(1)·f16(2)로 보냄 — 두 서버에 같은 값. 자기 부분합도 같이 반올림해
    두 노드 합이 같다. 출력이 바뀜(KLD 0.017 vs 잡음 0.014), 속도 이득 ≈0 이라 측정용(RESULTS.md 2026-11-08 00:50 절)
  - 컴파일 매크로 `MMVQ_RDNA2_IQ4NL_ROWS`(2026-11-08, 기본 4): gfx1151(RDNA2 표, 워프 1개) 1토큰 IQ4_NL 행렬곱(MoE down, K=320)을 블록당 4행으로 —
    행마다 같은 루프·워프 합이라 값이 같다. none +1.7%(RESULTS.md 2026-11-08 03:10 절). `MMVQ_RDNA2_Q5_0_ROWS`(기본 1 = 끔)는 같은 것을 Q5_0 에 —
    행 2 −0.7%, 행 4 −1.5% 라 끔(같은 날 05:48 절). 바꿔 보려면 `-DCMAKE_HIP_FLAGS=-DMMVQ_RDNA2_IQ4NL_ROWS=2` 처럼 다른 빌드 폴더에서.
  - `GGML_CUDA_GLU_Q8_ROWS=2|4|8`(2026-11-08, 기본 1): MoE gate+up(`mul_mat_vec_q_glu_q8`) 워프당 행 R 개. 값 그대로, 커널 시간 그대로(49.0 µs) → 측정용.
    `GGML_CUDA_HC_UP_ILV=1`(기본 꺼짐): `k_hc_up_pre` 의 hc 행 4개를 한 고리에서. 값 그대로, 21.0 → 22.9 µs 로 느려짐(RESULTS.md 2026-11-08 12:20 절)
  - `GGML_RPC_COMM_RAIL2=<RDMA 장치>` (+`GGML_RPC_COMM_RAIL2_MIN`): 두 번째 케이블로 큰 부분합을 반씩 교환. 지금 tbv 에서는 이득 없음, 기본 꺼짐
  - 불러올 때 가중치 합치기(qwen4exp, 기본 켬): `LLAMA_MERGE_WEIGHTS=<mask>` — 1 hc down+inject, 2 GDN qkv+gate, 4 GDN beta+alpha(기본 7, 0 은 끔).
    형식이 다르면 바이트가 큰 쪽 형식으로 다시 양자화(H5 의 hc inject Q8_0 → Q6_K), `LLAMA_MERGE_WIDE=1` 은 bpw 큰 쪽(hc down → Q8_0). TP 에서도 모두 합친다(`attn_qkv_gate`·`ssm_beta_alpha` 분할 규칙 추가, 2026-10-31)
  - `GGML_CUDA_SKIP_OPS=<연산|w:가중치이름,...>` (앞에 `!` 면 나열한 것만 남김): 측정 전용, 결과가 틀림. 연산 종류를 GPU 에서 빼 토큰당 시간이 얼마나 주는지 잰다
    (`fixcost/ablate.sh <GGUF> <회차> 이름=환경 ...`, 프로파일러 없이 고정비 분해)
  - 2026-10-31 – 11-01 엔진 변경(자세한 수치는 RESULTS.md):
    - GDN 상태를 캐시에서 바로 읽기(기본 켬, 값 같음): `GGML_CUDA_NO_GDN_DIRECT=1` 이면 끔
    - 라우터 BF16 사본(기본 켬, 값 같음 — 16-bit 라우터는 F32 정밀도로 계산): `LLAMA_ROUTER_BF16=0` 이면 F32
    - 4토큰 conv `concat` 원소당 스레드 커널(항상)
    - hc 경계 묶기 `GGML_CUDA_HC_MIX=1|f32` (기본 끔 — f32 활성값은 품질 손해), 호스트 검사 `GGML_CUDA_HC_MIX_CHECK=<n>`
    - 받는 쪽 zero-copy AR `GGML_RPC_COMM_ZC` (기본 1, 값 같음): 커널이 coherent 호스트 플래그를 기다렸다 상대 부분합을 더한다. 2 는 보내는 쪽도
      (APU 펌웨어가 CPU 우선으로 바뀌어 느림), 0 은 끔
    - 계측: `GGML_RPC_COMM_PROF` 에 받기 대기·보내기 쪼개기 줄, `GGML_RPC_COMM_PROF_TL=<file>` AR 별 시각(`fixcost/zc-allreduce-1101/tlsum.py`)
    - 양쪽 연속인 2D 복사를 1D 로(HIP 은 4의 배수가 아닌 폭의 2D 복사를 행마다 함 — TP 분할 비율 0.45 로딩 실패의 원인)
    - 바쁜 대기 줄이기 `GGML_CUDA_BLOCKING_SYNC=1`(기본 끔), 디버그 `GGML_CUDA_DUMP_NODES=<n>`
  - 2026-11-03 엔진 변경(모두 기본 켬, 값 같음; 끄는 환경변수):
    - 묶기: hc lo SCALE→SILU 가 q8_1 사본도 `GGML_CUDA_NO_SCALE_SILU_Q8`, shexp 게이트 끝 `GGML_CUDA_NO_SHEXP_GATE_FUSE`, 게이트 행렬곱까지
      `GGML_CUDA_NO_SHEXP_GATE_DOT`, GDN 게이트 `GGML_CUDA_NO_GDN_GATES_FUSE`, GDN gated norm `GGML_CUDA_NO_NORM_GATE_FUSE`(q8_1 사본만 `GGML_CUDA_NO_NORM_GATE_Q8`),
      GDN conv 상태 `GGML_CUDA_NO_CONV_STATE_FUSE`(캐시 줄 직접 읽기만 `GGML_CUDA_NO_CONV_DIRECT`), hc_post → norm `GGML_CUDA_NO_HC_POST_NORM`
      (출력이 입력과 겹치는 곳의 한 블록 커널만 `GGML_CUDA_NO_HC_POST_NORM_1B`), GDN q/k norm 한 커널 `GGML_CUDA_NO_NORM_SCALE_PAIR`
    - q8_1 사본을 만드는 쪽에서: norm `GGML_CUDA_NO_NORM_Q8`, hc_pre `GGML_CUDA_NO_HC_PRE_Q8`
    - top-k 전용 커널(512 전문가 softmax) `GGML_CUDA_NO_TOPK_LEAN`, warp 교환 DPP(빌드 `-DGGML_CUDA_NO_XOR_DPP` 면 `__shfl_xor`)
    - 묶은 커널은 할당기가 비운 입력 메모리와 출력이 겹치면 묶지 않음(`ggml_cuda_tensors_overlap`)
    - 측정·디버그: `GGML_CUDA_PAD_KERNELS=<n>`(노드마다 빈 커널 n개, 커널 하나 비용 재기), `GGML_CUDA_Q8_VERIFY=1`(그래프 끔에서 q8_1 캐시 적중을 새 양자화와 비교, stderr)
  - 2026-11-03 저녁: 단계 시작 GPU 쉼 줄이기(값 같음, 2노드 decode +1.9%) — 클라이언트 작은 입력 비동기 `GGML_RPC_ASYNC_SET`(바이트, 0 = 끔), sched 입력 동기화 생략
    (`GGML_SCHED_INPUT_SYNC_ALWAYS=1` = 예전), 서버 작은 입력 비동기 `GGML_RPC_SERVER_ASYNC_SET`, 명령 묶어 보내기 `GGML_RPC_BATCH_MAX`(기본 끔).
  - 2026-11-08 낮: 토큰 경계(값 같음) — 쌓인 일이 없으면 다른 부분그래프 출력 입력도 기다리지 않음(기본 켬, none +0.4%; `GGML_SCHED_OTHER_INPUT_SYNC=1` = 예전),
    작은 RPC 명령 한 번에 쓰기(기본 켬, 본문 4096 B 이하; `GGML_RPC_ONE_WRITE=0` = 예전, A 로 가는 TCP 명령 13 → 5 µs).
    클라이언트 기다림 돌기 `GGML_RPC_SYNC_SPIN` 기본 1(none +1.0%, MTP +1.7%; `=0` 예전처럼 잠, RESULTS.md 2026-11-08 14:20·17:28 절),
    `=2`(끝 무렵만 돎, `GGML_RPC_SYNC_SPIN_TAIL_US`)는 이득 없음.
    계측 `GGML_SCHED_TIMES=N`(클라이언트, N 번째 호출마다 부분그래프별 입력 복사 시간 stderr).
  - 2026-11-09 새벽: 커널 줄이기(값 같음) — GDN 묶은 norm 을 36층 모두에(겹치면 쓰는 블록이 그리드 전체를 기다림, 기본 켬; `GGML_CUDA_GDN_NORM_NO_WAIT=1` 예전),
    AR 부분합 내보내기를 만드는 커널이 같이(`GGML_CUDA_COMM_OUT_FUSE`, 기본 켬, =0 끔; 붙드는 최대 토큰 `GGML_CUDA_COMM_OUT_MAX_TOKENS` 기본 4(MTP 검증까지) —
    11-09 아침 붙드는 것을 ≤64 KB 출력(AR 부분합)으로 한정한 뒤 4 가 MTP +1.5%, 그 전엔 출력층까지 붙들어 −2.4%; =1 은 1토큰만; 블록당 행 `GGML_CUDA_COMM_OUT_NW` 기본 8; 검사 `GGML_CUDA_COMM_OUT_VERIFY=1`, 셈 `GGML_CUDA_COMM_OUT_STATS=1`),
    `GGML_CUDA_Q8_CACHE_PERSIST=1`(AR 경계 뒤 shared expert 입력 다시 양자화 없앰: none +0.45%, MTP 판정 중 — RESULTS.md 2026-11-08 23:40 절),
    `GGML_CUDA_FUSE_OVERLAP_LOG=1`(묶음이 겹침으로 거절될 때 이유를 stderr 로).
    `GGML_RPC_BATCH_SET_ONLY=1`(+`GGML_RPC_BATCH_MAX`): 입력 SET_TENSOR 끼리만 묶어 보냄 — 경계 ≈110 µs 당겨지지만 속도 그대로, 기본 꺼짐.
    `GGML_RPC_BATCH_MAX` 만 켜면(그래프 명령까지 묶음) −5.7%: 서버가 커널을 깊게 앞서 넣어 GPU 계산 +0.8 ms. `GGML_RDMA_TX_SLOTS` 8·16 차이 없음(4 그대로).
  - 추론 감시: 서버 `GGML_RPC_TRACE=/dev/shm/ggml-rpc-trace-{port}.bin`, 클라이언트 `GGML_RPC_TRACE_CLIENT=...`(run_tp.sh·srv-probe.sh 가 켬, `TRACE=0` 끔, 부담 ≈1.5%),
    `tools/watch/inferwatch.sh start` → 실행마다 `runs/watch/<시각>/report.html`·`receipt.md`. tbv 카운터를 리포트에 넣으려면 `inferwatch.sh tbv-copy`(sudo).
    기록 조건(코드 ggml-rpc.cpp `comm_prof_every()`·`rpc_serve_client`, 2026-11-10 확인): 서버의 CMD 와 AR·AR_SYNC·RECV·GPU·PROXY 는 모두 같은
    `GGML_RPC_COMM_PROF` 값을 따른다 — 주지 않으면 기록 링이 켜졌을 때 1000(켬), `=0` 이면 모두 빠짐. 함정: `run_tp.sh` 는 B 에
    `GGML_RPC_COMM_PROF=${GGML_RPC_COMM_PROF:-0}` 을 넘겨, 따로 주지 않으면 B 링에 CMD·AR 기록이 없다(node-ab 는 `BASE` 가 두 서버에 =1000).
  - 2026-11-04 밤(자세히는 RESULTS.md "11-03 23:50 – 11-04"):
    - greedy argmax 빠른 경로(llama-server 대상 샘플러, 항상): temperature 0 이고 최댓값을 지울 수 있는 샘플러가 없을 때 후보 배열·정렬 대신 argmax. 값 같음
    - `GGML_RPC_COMM_DEV=<RDMA 장치>`(두 서버): AR 링크만 그 장치로(두 번째 케이블). 스크립트 기본값에는 없다 — 11-05(ZC=1)·11-07(ZC=3) 다시 재 보니
      이득이 없어 그대로 둠(RESULTS.md 11-07 08:00 절). 장치 이름은 재부팅 때 노드마다 바뀔 수 있다
    - `GGML_RPC_COMM_ZC=3`: 스트림 안 AR + 프록시 스레드(느림), `GGML_RPC_COMM_ZC3_AHEAD=K`(호스트가 앞서는 AR 수 제한)
    - `LLAMA_TP_OUTPUT_SPLIT=<f>`(output.weight 의 장치 0 몫), `LLAMA_KV_PAD=<n>`(n_kv 패딩, 256 이 아니면 출력이 바뀜 — 측정용),
      `GGML_RPC_GRAPH_DEDUP=1`(서버에 이미 있는 내용의 그래프를 다시 보내지 않음, 기본 끔), `GGML_RPC_SYNC_SPIN=1`(클라이언트 대기를 돌며 — 11-04 에는 −0.3% 라 끔, 11-08 부터 기본 켬)
    - 진단: `GGML_RPC_GC_STATS=1`(서버 새 그래프 비용), `GGML_META_CACHE_STATS=1`(메타 분할 상태 캐시·다시 짓기), `GGML_RPC_DEDUP_TIME=1`(클라이언트 직렬화),
      클라이언트 DECODE 기록에 llama_decode 앞 단계 도장 4개, 서버 ZC=3 프록시 기록(PROXY)
    - 측정 도구: `tools/bench/prof2node.sh`(A 서버만 rocprofv3), `kgroup.py`(부분그래프 종류별 커널 시간·빈틈), node-ab.sh `BASE_<cfg>`·`CW_<cfg>`(클라이언트 앞 명령),
      `tools/probe/gpumetrics_ts.py` fclk·uclk·DRAM 열
  - 2026-11-04 오후: hc 블록 묶기(SCALE→SILU→hc up 행렬곱→hc_pre 한 커널, 기본 켬, 값 같음, +1.5–2%) `GGML_CUDA_NO_HC_UP_PRE=1` 끔,
    q8 캐시 그래프 사이 유지 `GGML_CUDA_Q8_CACHE_PERSIST=1`(기본 끔), AR 더하기 미루기 `GGML_CUDA_COMM_DEFER=1`(+`_WINDOW`, 기본 끔).
    halogen 과의 GPU 사용률·커널 비교는 `fixcost/halogen-compare-1104/`
  - 2026-11-04 저녁: GLU 행렬곱이 결과의 q8_1 도 씀(전문가·shared expert down 의 양자화 커널 없앰, 기본 켬) `GGML_CUDA_NO_GLU_Q8=1` 끔,
    shared expert down + 게이트 꼬리(게이트 내적·sigmoid·곱·더하기) 한 커널(기본 켬) `GGML_CUDA_NO_SHEXP_DOWN_TAIL=1` 끔,
    검증용 `GGML_CUDA_SHEXP_TAIL_VERIFY=1`(묶은 결과와 따로 돌린 결과를 비트로 비교). 커널 토큰당 비교 `tools/bench/kdiff.py`.
    GDN beta/alpha 행렬곱 + gates 한 커널(기본 켬, +2%) `GGML_CUDA_NO_GDN_MM_GATES=1` 끔, 검증 `GGML_CUDA_GDN_GATES_VERIFY=1`
  - 2026-11-04 밤: GDN conv + q/k norm 한 커널(기본 켬, +0.5–1%) `GGML_CUDA_NO_CONV_NORM_PAIR=1` 끔, 검증 `GGML_CUDA_CONV_NORM_VERIFY=1`
    AR 기다림-더하기를 처음 읽는 커널 안에서(+1.4%, 기본 켬, 미루기 포함) `GGML_CUDA_COMM_FUSE=0` 끔
    conv 상태 concat 도 conv+norm 커널에서(+0.9%, 기본 켬) `GGML_CUDA_NO_CONV_CONCAT=1` 끔
    GDN 커널 안에서 gated norm(기본 켬, 잡음 안) `GGML_CUDA_NO_GDN_NORM=1` 끔, 검증 `GGML_CUDA_GDN_NORM_VERIFY=1`
  - 2026-11-05 새벽: 어텐션 출력 게이트+q8 한 커널 `GGML_CUDA_NO_ATTN_GATE_Q8=1` 끔, q/k norm+rope(multi) 한 커널 `GGML_CUDA_NO_NORM_ROPE=1` 끔
    (검증 `GGML_CUDA_NORM_ROPE_VERIFY=1`), 둘 다 기본 켬·값 같음·속도 차이 잡음 안
    indexer key 사슬 12 커널 → 1(+1.1%, 기본 켬) `GGML_CUDA_NO_IDX_K_POOL=1` 끔, 검증 `GGML_CUDA_IDX_K_POOL_VERIFY=1`
  - 2026-11-05 오후: 서버 쪽 argmax(기본 켬, 값 같음, +3.1%) `LLAMA_TP_ARGMAX=0` 끔 — `ggml_backend_tensor_argmax_rows`(meta 는 장치 조각별로 받아 합침,
    rpc 는 새 명령 `RPC_CMD_ARGMAX_ROWS`), llama-context 가 마지막 ubatch 로짓을 장치에 남기고 `llama_get_argmax_ith` 에 답함(로짓은 물을 때 받음),
    common sampler greedy 빠른 경로가 이를 먼저 씀. 끝날 때 `LLAMA_TP_ARGMAX: N rows argmax on the devices, M logits fetches` 로그
  - 2026-11-05 저녁(MTP 검증 4토큰용): shared expert 꼬리 묶기가 1–4 토큰을 받음(기본 켬, 값 같음, MTP 잡음 안) — `GGML_CUDA_FUSE_1TOK=1` 이면 1토큰만(예전),
    검증 `GGML_CUDA_SHEXP_TAIL_VERIFY=1`(이제 COMM_FUSE 켠 채로 됨). hc 블록 묶기의 여러 토큰판은 값 같지만 느려(MTP −2.7%) 기본 1토큰,
    `GGML_CUDA_HC_UP_PRE_NTOK=<2..4>` 로 켬, 검증 `GGML_CUDA_HC_UP_PRE_VERIFY=1`. 디버그 `GGML_CUDA_DUMP_NTOK=<n>`(n 토큰 서브그래프 노드 출력)
  - 2026-11-06 새벽(고침): 묶은 커널의 출력이 다른 블록이 아직 읽는 입력과 메모리를 같이 쓰면 묶지 않는다(`ggml_cuda_overlaps_srcs`). GDN 안 gated norm 이 이 검사
    없이 다른 head 의 q 입력을 덮어, 상대 노드 GPU 를 다른 프로세스가 같이 쓸 때 출력이 바뀌었다(RESULTS.md 11-05 23:25 절). 디버그 `GGML_CUDA_FUSE_OVERLAP_LOG=1`(거부 출력).
    argmax 를 노드마다 동시에 묻기(기본), `GGML_META_ARGMAX_SERIAL=1` 이면 차례로
    서버 argmax 를 GPU 커널로(최댓값의 첫 번호, 기본 켬, 값 같음, 속도 차이 없음) `GGML_CUDA_NO_ARGMAX_ROWS=1` 이면 로짓을 호스트로 읽어 CPU argmax

- 2026-11-06 오후: MTP 초안 출력층을 일부 어휘로 — 초안 GGUF 에 `d2t`(I64) 가 있으면 qwen4exp 가 줄인 `output.weight` 를 받아 그 행만 계산하고
  나머지 로짓을 -inf 로 둔다(만들기: `tools/draft_vocab_corpus.py` → `tools/draft_vocab_select.py` → `tools/gguf_draft_vocab.py`).
  `tools/bench/srv-probe.sh` 의 `BENCH`(벤치 대신 돌릴 클라이언트, `{OUT}` = 실행 폴더).
  같은 스크립트의 시간 제한(2026-11-10): `STOP_S`(서버 등을 TERM 뒤 기다릴 초, 기본 60 — 넘으면 KILL), `BENCH_S`(벤치 클라이언트 제한 초, 기본 3600).
  KILL·시간 초과가 있었으면 실행 폴더에 `stop.txt`. rocprofv3 로 감싼 서버(`CLI_WRAP`·`CW_<cfg>`)는 SIGTERM 에 안 끝나 이 처리에 기대야 한다.
- 2026-11-06 저녁: AR 기본 경로를 스트림 안으로 — `GGML_RPC_COMM_ZC` 기본 3(예전 1), `GGML_RPC_COMM_ZC3_AHEAD` 기본 2(예전 0, 서버 스레드가 앞서는 AR 수).
  `GGML_RPC_COMM_ZC=1` 이면 예전 경로(동기화 → 보내기 → 기다림 커널).
  두 번째 케이블: `GGML_RPC_COMM_RAIL2=usb4_rdma0`(두 서버, `GGML_RDMA_RX_DEPTH=32` 와 함께)이면 ZC=3 대리 스레드가 레일마다 하나씩 절반을 주고받는다
  (`GGML_RPC_COMM_RAIL2_ZC_MIN`, 기본 4096 B). 11-06 에는 이득이 없었으나, 11-10 `RAIL2=<클라이언트 장치>` + `ZC_MIN=32768`(4토큰 AR 만)이면
  MTP +1.5%(출력 같음, RESULTS.md 11-10); 1토큰까지 나누면(4096) none −1%.
  2026-11-11: srv-probe·run_server 기본 `RAIL2=auto` — MTP 회이고 AR 장치가 정해졌으면 두 서버에 `RAIL2=<클라이언트 장치>`(tbcommdev.sh rail2)
  `ZC_MIN=32768 RX_DEPTH=32`. 확인 회 MTP 6쌍 +0.8%(4쌍 이김, AR 지연 42 → 33 µs), none −0.5% 라 none 은 끔. `RAIL2=1|0` 강제, node-ab `RAIL2_<cfg>`.
- 2026-11-06 밤(구간 커널 1a, 기본 꺼짐): `GGML_CUDA_SEG_MOE=1` — hc down → hc up/pre → BF16 행렬곱(라우터·indexer k)을 상주 커널 하나로(`k_seg_moe_head`),
  `GGML_CUDA_SEG_VERIFY=1` 비트 비교, `GGML_CUDA_SEG_PREFETCH=1` 다음 단계 가중치 앞서 읽기, `GGML_CUDA_SEG_COOP=1` 협동 실행. 디버그 `GGML_CUDA_DUMP_MOE=<n>`(MUL_MAT_ID 있는 1토큰 그래프 노드).
- 2026-11-09 저녁(구간 커널 2a, 기본 꺼짐, 접음): `GGML_CUDA_SEG_MOE=2` — MoE 구간 hc down → 가중합 + AR 내보내기를 상주 커널 하나로(장벽 6개).
  값 같음(`GGML_CUDA_SEG_VERIFY=1` 11곳), 속도 같음. **다른 GPU 부하와 겹치면 두 노드 GPU 리셋이 난 적 있음 — 켜지 말 것**(RESULTS.md 2026-11-09 19:54 절).
  `GGML_CUDA_SEG_TIMES=<n>` 은 2a 의 단계 7개·장벽 6개도 찍는다.
- 2026-11-06 밤(split-K, 기본 꺼짐): `GGML_CUDA_MMVQ_SPLITK=<2|4|8>` — 한 열·행 `GGML_CUDA_MMVQ_SPLITK_ROWS`(기본 2048) 개 이하 양자화 행렬곱
  (Q5_0·Q8_0·Q6_K·IQ4_XS·IQ4_NL, 묶기 없는 것)에서 한 행을 워프 S 개가 나눔(`mul_mat_vec_q_splitk`). 더하는 순서가 달라 출력이 비트 그대로가 아님
  (같은 설정끼리는 결정적). `GGML_CUDA_MMVQ_SPLITK_VERIFY=1` 은 같은 입력으로 기존 커널을 한 번 더 돌려 가중치별 차이를 2000번마다 출력.
  디버그 `LLAMA_DEBUG_DUMP=<파일>`(llama-eval-callback 이 `LLAMA_DEBUG_DUMP_RE`, 기본 `l_last|result_output` 에 맞는 텐서를 f32 로 덤프, 비교는
  `tools/layerdiff.py`), `tools/divergence.py`(greedy 생성 기록과 처음 갈린 자리).
- 2026-11-07 새벽: 구간 커널 디버그 `GGML_CUDA_SEG_TIMES=<n>`(상주 커널 단계별 시간, n 번 평균, 매번 동기화), `GGML_CUDA_SEG_AHEAD=<비트>`(기본 0; 1 라우터
  가중치 선읽기, 2 hc up 가중치를 1단계 동안, 4 hc down 행 고르게 — 이득 없음), `GGML_CUDA_SEG_PREFETCH` 기본을 꺼짐으로(문서와 맞춤).
  고침(기본 경로): 묶은 hc 블록 커널은 silu 가 gate·hc_pre 와 메모리를 같이 쓰면 silu 를 쓰지 않는다(`hc_up_silu_out`, 블록 사이 경쟁).
  `GGML_CUDA_COMM_PREFETCH=<MB>`(기본 16, 0 이면 끔; 읽는 워프 수 `GGML_CUDA_COMM_PREFETCH_WARPS`, 기본 128): AR 기다림을 맡은 커널(hc_post+norm, shared expert 꼬리)이 기다리는 동안 워프 0 을 뺀 워프가 이 부분그래프의
  다음 행렬곱 가중치(MUL_MAT_ID 제외) 앞부분을 읽어 L2/MALL 에 올린다(`ggml_cuda_comm_plan_prefetch`, 읽기만).
  감시기(inferwatch): ZC=3 에서 GPU 도장이 없는 AR 은 대리 스레드 기록(플래그 본 때·상대 부분합 도착)으로 GPU 계산/기다림을 나눈다.
- 2026-11-07 오전(링크 튐): `run_server.sh`·`tools/bench/srv-probe.sh` 기본 `TBPIN=1` — 두 rpc-server 와 llama-server 를 Thunderbolt NHI 인터럽트를
  받는 CPU 밖에서 돌린다(`taskset -c $(tools/bench/tbcpus.sh)`, 노드마다 시작할 때 읽음, 지금 두 노드 `0-1,7-30`). 그 CPU 의 시스템 작업 큐 kworker 가
  받은 프레임을 마무리하는데 엔진의 바쁜 대기 스레드가 같은 CPU 에 있으면 3 ms 조각으로 나눠 써 AR 이 늦는다. none +1.1%, MTP +2.1%, 출력 그대로.
  `TBPIN=0` 이면 끔, `A_WRAP`/`B_WRAP`/`CLI_WRAP`(명령 앞에 붙임)을 주면 그것을 쓴다. 회마다 쓴 목록은 실행 폴더의 `pin.txt`.
  2026-11-07 저녁: 고정은 `env HSA_OVERRIDE_CPU_AFFINITY_DEBUG=0 taskset -c <목록>` — ROCm 런타임이 자기 스레드의 affinity 를 모든 CPU 로
  되돌려 받기 CPU 에 앉던 것을 막는다(링크 늦음 389 → 56번, RESULTS.md 2026-11-07 19:50 절). `tbcpus.sh` 는 기준 없이 할당된 TB 벡터의 CPU 를 모두 뺀다
  (재부팅 직후엔 인터럽트 수가 적어 예전 기준 10만이 아무것도 빼지 못했다).
  밤(B 미사용) 재측정에선 old/def 차이 없음 — 받기 CPU 에 런타임 스레드가 앉는 운 나쁜 회만 막는다(RESULTS.md 2026-11-07 23:17 절).
  `tools/tbv_rxwq.sh on2` = tbv `rx_wq_poll=2`(받기 작업을 모듈의 WQ_UNBOUND|WQ_HIGHPRI 큐로 — 인터럽트 CPU 에 묶이지 않음). 2026-11-08 측정:
  링크 늦음 79 → 0번, none +1.2%, 출력 그대로(RESULTS.md 2026-11-08 00:05 절) → 권장. 재부팅 뒤에도 쓰려면 두 노드 `/etc/modprobe.d` 의 옵션 줄에 `rx_wq_poll=2`(sudo).
  `tools/bench/tbcpus.sh [최소 인터럽트 수, 기본 0 = 할당된 벡터 모두]`: 썬더볼트 벡터의 `effective_affinity_list` 를 뺀 CPU 목록.
  `tools/bench/node-ab.sh`: `AW_<cfg>`/`BW_<cfg>`(서버 앞 명령), `TBPIN_<cfg>=0`(그 구성만 고정 끔, 모든 구성 `TBPIN_ALL`).
  tbv 받기 마무리 패치(tbv 브랜치 `rx-highpri-poll`, 적재 전): 모듈 파라미터 `rx_wq_poll`(-1 auto · 0 기본 NHI 경로 · 1 `system_highpri_wq` · 2 tbv 큐).
  `tools/tbv_rxwq.sh install|on|on2|off|restore|status`(A 에서, 두 노드 sudo) — 설치·A/B·되돌리기.
- 2026-11-07 낮(새 tbv 드라이버 적재 뒤): `run_server.sh`·`tools/bench/srv-probe.sh` 기본 `TBDEV=1` — tbv 에 `rx_wq_poll` 이 켜져 있으면 노드마다
  클라이언트 연결이 쓰지 않는 RDMA 장치(`tools/bench/tbcommdev.sh`, 목록의 둘째, 지금 A `usb4_rdma0`·B `usb4_rdma5`)를 `GGML_RPC_COMM_DEV` 로 준다.
  옛 드라이버면 비워 둔다. none +2.0%, MTP +2.1%(같은 드라이버 같은 케이블 대비). `TBDEV=0` 이면 끔, node-ab `TBDEV_<cfg>`. 쓴 장치는 `pin.txt`.
- 2026-11-07 오후(측정 도구): `tools/bench/node-ab.sh` 는 속도 회를 기록 링 끄고(`TRACE` 기본 0, 예전 1) 잰 뒤 `WATCH=1`(기본)이면 RUNS 의 spec:cfg 마다
  기록 켠 회를 하나 더 돌려 감시기 세션을 남기고 `tools/watch/stallsum.py` 비교표를 `$OUT/watch-summary-<시각>.md` 에 쓴다(영수증 사본 `watch-receipt-*.md`).
  `stallsum.py <이름>=<세션 폴더> ...` 는 따로도 쓴다(늦음 목록은 세션의 `stalls.txt` 로 한 번 만듦). bench 스크립트들은 이제 저장소 `tools/bench` 에서 돈다(예전 scratchpad 사본 `pf/`).
  `SPEED=0` 이면 속도 회 없이 감시기 회만(11-07 저녁). 늦음 목록(`INFERWATCH_STALLS=1`)에 그 시각의 노드 사이 시계 차 `off`(B − A, µs)가 붙는다.
- 2026-11-10 밤(측정 기준 바꿈, 사용자 결정): node-ab 감시기 회는 이 저장소 `tools/watch` 대신 inferwatch 저장소의 tag 사본을 쓴다 —
  `IW`(기본 `/data/parksThink/inferwatch-iw-20261110-1`, `git -C /data/parksThink/inferwatch worktree add <사본> <tag>` 뒤 그 안에서 `cargo build --release`).
  비교표 머리에 쓴 판 한 줄. 같은 회에서 노드별 DRAM 읽기 바이트(85% 목표의 분자 실측, inferwatch docs/DRAM.md): `DRAM=auto`(기본 — 노드마다
  `amd_df`·`perf_event_paranoid ≤ 0`·perf(B 는 감시기 사본도)를 보고 준비된 노드만 잼, 안 된 노드는 이유 한 줄 뒤 값을 비움)|`1`(한 노드라도 못 하면 멈춤)|`0`(끔). 서버 전 노드마다 5 초 쉬는 몫,
  회 동안 50 ms 표본(새 세션 그룹으로 띄워 그룹째 멈춤), 회 뒤 `inferwatch dram-bytes` 를 노드마다 → `$OUT/dram/<시각>-<cfg>-w-{a,b}.json`, 비교표에
  노드별 GB/토큰·decode 중 GB/s·239.7 대비. 속도 회에는 붙이지 않는다. 준비(노드마다, 사용자 sudo, 재부팅하면 풀림): `sudo modprobe amd-uncore`,
  `sudo sysctl kernel.perf_event_paranoid=0`. 첫 2노드 회 전에는 시험하지 못함(B 꺼짐) — A 쪽 표본기 켜기·그룹째 멈추기만 확인.
- 2026-11-09 밤(MTP 검증 4토큰): `GGML_CUDA_MOE_DEDUP=1`(기본 꺼짐) — 2–4토큰 MUL_MAT_ID 에서 같은 전문가를 고른 토큰들을 한 번의 가중치 읽기로
  (`mul_mat_vec_q_moe_dedup`, 값 같음) — **MTP −23% 라 끔**(블록마다 전문가 목록을 다시 계산하는 몫, RESULTS.md 2026-11-09 22:20 절).
  `GGML_CUDA_MOE_DEDUP_VERIFY=1`(기존 커널과 비트 비교), `GGML_CUDA_MOE_OVERLAP_STATS=<n>`(디버그: 4토큰이 고른 전문가 중 서로 다른 것의 비율, 동기화).

