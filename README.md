# llm-engine-for-libtbvcoll — 자체 LLM 엔진 (2× HP ZBook Ultra G1a, USB4 RDMA)

Strix Halo(gfx1151) 노트북 두 대를 Thunderbolt/USB4 RDMA(tbv, libtbvcoll)로 묶어 큰 MoE 모델을 돌리는 자체 엔진 작업 저장소.
첫 대상은 Qwen3.8-Flash-Next(qwen4exp). 지금 바탕은 llama.cpp 본선 `e09a78a` + 우리 패치다.

원칙: **다중 노드는 텐서 병렬(TP)만** 쓴다(층 분할·PP 는 중간 단계로도 쓰지 않음). 하드웨어·전원·펌웨어 설정은 바꾸지 않는다(소프트웨어만).
tbv·libtbvcoll 자체는 [zbook-thunderbolt-RDMA](../zbook-thunderbolt-RDMA) 저장소에 있다. 이 저장소의 앞 7개 커밋은 그 저장소 `engine2n/` 의 이력을 그대로 옮긴 것.

## 지금까지 (2026-10-30, Flash-Next, 자세한 값은 RESULTS.md)

| 구성 | PPL | 1노드 직렬 | 1노드 + MTP | 2노드 TP | 2노드 TP + MTP |
|---|---:|---:|---:|---:|---:|
| Q8_0 (원본 기준, 토큰당 7.30 GB) | 2.0660 | 한 대에 안 들어감 | — | 20.9 | **31.3** |
| unsloth UD-IQ4_XS (5.84 GB) | 2.1682 | 17.5–17.8 | 31.1–31.3 | 22.6–23.3 | 34.3–34.5 |
| **H5** (우리 배분, Q8_0 에서, 4.82 GB) | **2.1359** | 18.5 | 31.2 | **25.4** | **34.8** |
| H (halogen 식 밀집 4-bit, 4.40 GB) | 2.1477 | 19.9 | 32.6 | 25.3 | 34.1 |
| **H5 + 불러올 때 가중치 합치기** (같은 날 같은 조건 끔 → 켬) | 2.1179 | (llama-bench 19.5 → 21.0, 그래프 끔 21.8) | 32.6 → **33.4** | 24.4 → **25.9** | 34.3 → **36.4** |
| (참고) halogen 자체 체크포인트, 개발사 측정 | — | 35.4 | 55–57 | — | — |

- tok/s, llama-server 6 프롬프트. 1노드 값은 A 의 '느린 상태'(TB 활동 없음, 빠른 상태에서는 ≈+20%). 2노드는 B rank 0, 발행 겹치기 2, 서버 HIP 그래프 끔, FFN 320/320.
- 비트 배분(`tools/make_mix.py`, `quant/`): 전문가 IQ4_XS(down IQ4_NL), o_proj Q8_0, hyper-connection Q6_K/Q8_0, 몸통 4-bit(H) 또는 Q5_0(H5), imatrix.
  gfx1151 에서 IQ3_S 는 4-bit 보다 빠르지 않고 K 형식은 묶음 4 에서 1.7배 느려서(커널 표) 고른 형식.
- MTP 를 켜면 배분과 상관없이 속도가 같다 → 남은 차이는 엔진 고정비(토큰당 ≈19–28 ms).
- 고정비 분해(2026-10-30, RESULTS.md): 직렬 토큰 ≈52 ms = 가중치 읽기 ≈21 + 행렬곱이 대역폭보다 느린 몫 ≈16(hc ≈7) + 작은 연산 ≈14 + 호스트 0.3.
  토큰당 커널 ≈3200개 × ≈3 µs 발행 바닥.
- 가중치 합치기(2026-10-30, RESULTS.md): 입력이 같은 가중치 168쌍(hc down+inject, GDN qkv+gate, beta+alpha)을 불러올 때 한 텐서로 합쳐
  토큰당 커널 3201 → 2865, 1노드 직렬 −7%. TP 분할 규칙까지 넣어 2노드 TP 끔 대비 +9.5%(MTP 없음)·+9.2%(MTP, 36.6 tok/s).
  다음: 남은 같은 입력 묶음, 활성값 양자화 공유. 2노드에서는 B 가 펌웨어 CPU 우선 상태(GPU 1.7–2.2 GHz)로 남는 것이 병목.
- 작은 연산 묶기·DPP(2026-11-03, RESULTS.md): 토큰당 커널 2720 → 1806, 값 그대로. 2노드 H5(hot 폴링 끔) 디코드 27.3 → **32.2**, MTP 38.7 → **42.4**(41.5–43.3) tok/s.
  2노드에서도 커널 하나가 ≈3–4 µs 라 커널 수가 곧 시간(빈 커널 측정).
- 관측기로 다시 비교(2026-11-04 밤, RESULTS.md): async(지금 구조) 끝까지 + sync(스트림 안 AR + CPU 프록시) 적용. 채택은 greedy argmax 샘플링과
  AR 링크를 두 번째 케이블로(`GGML_RPC_COMM_DEV=usb4_rdma0`) — 2노드 디코드 32.70 → **33.60** tok/s, 값 그대로.
  스트림 안 AR(ZC=3)은 gfx1151 에서 깊은 큐의 커널이 하나하나 느려져 −1–2%. 그래프를 다시 짓는 디코드 단계(≈120 ms, 디코드의 3.5%)가 남은 큰 몫.

- 설계: [DESIGN.md](DESIGN.md) (v1, TP). 폐기된 층 분할(PP) 설계는 [DESIGN_v0_pp.md](DESIGN_v0_pp.md), `run_2node.sh` 에 기록용으로만 남김.
- 측정 기록: [RESULTS.md](RESULTS.md)
- 노드 점검 도구(읽기만): [tools/probe/](tools/probe/) — `gpumetrics.py`(gpu_metrics v3.0 클럭·전력·DRAM 카운터), `clkmon2.sh`, `nodeinfo.sh`,
  HIP 시험 `lat.hip`(발행·동기화 지연), `bw.hip`(메모리 대역폭), `wv.hip`(`hipStreamWaitValue32` 동작),
  `kfloor.hip`(작은 커널 하나의 바닥 비용, 그래프/직접), `bigbuf.hip`(큰 버퍼 안 창 읽기 대역폭). 빌드: `hipcc -O2 --offload-arch=gfx1151 x.hip -o x`
  `ktok.py`(rocprofv3 기록 → 토큰당 커널 수·시간), `memclk_ts.py`(FCLK·UCLK·DRAM 카운터 시계열)
- llama.cpp 패치: [patches/llama-e09a78a-engine2n-t5.patch](patches/llama-e09a78a-engine2n-t5.patch)
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

## 준비
```
git clone https://github.com/ggml-org/llama.cpp && git -C llama.cpp checkout e09a78a
git -C llama.cpp apply ../patches/llama-e09a78a-engine2n-t5.patch     # 저장소 최상위에서
./build_llama.sh                     # rocm/vllm-dev:rocm7.2.1 컨테이너에서 HIP gfx1151 + RPC + RDMA 빌드(+ llama-quantize, llama-imatrix)
./eval/make_ppl_text.sh
./get_models.sh iq4                  # Qwen3.8-Flash-Next UD-IQ4_XS (93.7 GB, sha256 확인)
```
## 실행
```
./run_1node.sh <q4|iq4|GGUF>                 # 1노드 기준
./run_tp.sh <GGUF|iq4> local                 # A 혼자 TP 점검(rpc-server 2개)
./run_tp.sh <GGUF|iq4> 2node [rdma|tcp]      # 2노드 TP: --rpc 10.99.0.2:50052,127.0.0.1:50052 (B = rank 0)
./eval_ppl.sh <GGUF> 1node|tplocal|tp2node   # 정합성(perplexity)
./run_server.sh 1node|2node none|mtp [N]      # llama-server 실측(추측 디코딩 포함), 프롬프트 eval/spec_prompts.json
```
MTP(추측 디코딩): `./get_models.sh mtp` 로 받는 공유형 MTP 파일은 본 모델의 `token_embd`·`output` 을 빌려 쓰는 형식이라 이 llama.cpp 가 단독으로 못 연다.
본 모델 조각에서 두 텐서를 붙인 파일을 만들어 쓴다:
```
python3 -I tools/gguf_merge_mtp.py <MTP/mtp-...-shared-Q8_0.gguf> <UD-IQ4_XS/...-00002-of-00003.gguf> <MTP/mtp-...-merged-IQ4embd.gguf> token_embd.weight output.weight
```
주의: B 를 rank 0 으로 둔다 — A 서버를 TB 주소로 등록하면 클라이언트↔A 서버가 tbv 루프백으로 협상되는데 tbv 는 같은 노드 안 QP 를 못 잇는다.
tbv 는 `9a35117`(여러 프레임 SEND 의 RNR 대기) 이상이어야 한다.

## 양자화 실험 (`quant/`)
```
python3 -I tools/gguf_head.py <조각.gguf> | grep '  T ' > quant/orig.tensors        # 텐서 목록
python3 -I tools/make_types.py <형식> <그룹,...> < quant/orig.tensors > quant/X.types   # 그룹: attn, gdn, hc, shexp, ple
[IMATRIX=quant/imatrix-orig.gguf] quant/run_variant.sh quant/X.types <태그>         # 변환 → 1노드 디코드 → PPL
python3 -I tools/make_mix.py <H|H5> < quant/q8.tensors > quant/q8mix-H5.types        # Q8_0 원본용 그룹별 배분
quant/run_mix_suite.sh quant/q8mix-H5.types q8mix-H5                               # Q8_0 에서 변환 → UD 와 번갈아 측정 → 서버 1·2노드 × MTP
python3 -I tools/gguf_head.py <변형.gguf> | python3 -I tools/bytes_per_token.py 512 10   # 토큰당 읽는 양
./eval/make_calib_text.sh                                                          # imatrix 보정 글(평가 글과 겹치지 않음)
```
`quant/run_variant.sh` 는 변형 디렉터리(`UD-IQ4_XS-dense4/`) 안의 이전 변형 파일만 지우고 새로 만든다(디스크 부족으로 사용자 허락, 2026-10-29).
형식별 커널 속도: `TARGETS=test-backend-ops ./build_llama.sh` 후 `test-backend-ops perf -b ROCm0 -o MUL_MAT -p 'm=10240,n=[0-9]+,k=2560,bs=\[16,1\]'`(패치에 qwen4exp 모양 추가).

## 구성
- `run_*.sh`, `eval_ppl.sh`, `build_llama.sh`, `get_models.sh` + `models_manifest.json`: 빌드·모델 받기·측정 실행기
- `patches/`: llama.cpp `e09a78a` 에 대한 우리 변경 전체(diff)
- `tools/`: 측정·분석(`spec_bench.py`, `cmp_runs.py`, `kgroups.py`, GGUF 도구), `tools/probe/`: 노드·GPU 점검
- `eval/`: 평가 프롬프트, 평가·보정 글 생성 스크립트
- `quant/`: 밀집 부분 비트 배분 실험의 형식 파일·로그

