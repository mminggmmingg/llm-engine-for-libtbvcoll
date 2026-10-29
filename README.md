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
| (참고) halogen 자체 체크포인트, 개발사 측정 | — | 35.4 | 55–57 | — | — |

- tok/s, llama-server 6 프롬프트. 1노드 값은 A 의 '느린 상태'(TB 활동 없음, 빠른 상태에서는 ≈+20%). 2노드는 B rank 0, 발행 겹치기 2, 서버 HIP 그래프 끔, FFN 320/320.
- 비트 배분(`tools/make_mix.py`, `quant/`): 전문가 IQ4_XS(down IQ4_NL), o_proj Q8_0, hyper-connection Q6_K/Q8_0, 몸통 4-bit(H) 또는 Q5_0(H5), imatrix.
  gfx1151 에서 IQ3_S 는 4-bit 보다 빠르지 않고 K 형식은 묶음 4 에서 1.7배 느려서(커널 표) 고른 형식.
- MTP 를 켜면 배분과 상관없이 속도가 같다 → 남은 차이는 엔진 고정비(토큰당 ≈19–28 ms). 다음: 고정비 분해·줄이기.

- 설계: [DESIGN.md](DESIGN.md) (v1, TP). 폐기된 층 분할(PP) 설계는 [DESIGN_v0_pp.md](DESIGN_v0_pp.md), `run_2node.sh` 에 기록용으로만 남김.
- 측정 기록: [RESULTS.md](RESULTS.md)
- 노드 점검 도구(읽기만): [tools/probe/](tools/probe/) — `gpumetrics.py`(gpu_metrics v3.0 클럭·전력·DRAM 카운터), `clkmon2.sh`, `nodeinfo.sh`,
  HIP 시험 `lat.hip`(발행·동기화 지연), `bw.hip`(메모리 대역폭), `wv.hip`(`hipStreamWaitValue32` 동작). 빌드: `hipcc -O2 --offload-arch=gfx1151 x.hip -o x`
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
  - `GGML_RPC_COMM_RAIL2=<RDMA 장치>` (+`GGML_RPC_COMM_RAIL2_MIN`): 두 번째 케이블로 큰 부분합을 반씩 교환. 지금 tbv 에서는 이득 없음, 기본 꺼짐

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

