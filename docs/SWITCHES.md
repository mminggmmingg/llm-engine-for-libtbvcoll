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
  - 추론 감시: 서버 `GGML_RPC_TRACE=/dev/shm/ggml-rpc-trace-{port}.bin`, 클라이언트 `GGML_RPC_TRACE_CLIENT=...`(run_tp.sh·srv-probe.sh 가 켬, `TRACE=0` 끔, 부담 ≈1.5%),
    `tools/watch/inferwatch.sh start` → 실행마다 `runs/watch/<시각>/report.html`·`receipt.md`. tbv 카운터를 리포트에 넣으려면 `inferwatch.sh tbv-copy`(sudo).
  - 2026-11-04 밤(자세히는 RESULTS.md "11-03 23:50 – 11-04"):
    - greedy argmax 빠른 경로(llama-server 대상 샘플러, 항상): temperature 0 이고 최댓값을 지울 수 있는 샘플러가 없을 때 후보 배열·정렬 대신 argmax. 값 같음
    - `GGML_RPC_COMM_DEV=<RDMA 장치>`(두 서버): AR 링크만 그 장치로(두 번째 케이블 `usb4_rdma0`). 권장, 스크립트 기본값에는 아직 없음(`SRV_ENV`)
    - `GGML_RPC_COMM_ZC=3`: 스트림 안 AR + 프록시 스레드(느림), `GGML_RPC_COMM_ZC3_AHEAD=K`(호스트가 앞서는 AR 수 제한)
    - `LLAMA_TP_OUTPUT_SPLIT=<f>`(output.weight 의 장치 0 몫), `LLAMA_KV_PAD=<n>`(n_kv 패딩, 256 이 아니면 출력이 바뀜 — 측정용),
      `GGML_RPC_GRAPH_DEDUP=1`(서버에 이미 있는 내용의 그래프를 다시 보내지 않음, 기본 끔), `GGML_RPC_SYNC_SPIN=1`(클라이언트 대기를 돌며, 기본 끔)
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
