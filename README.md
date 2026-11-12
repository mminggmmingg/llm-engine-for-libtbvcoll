# llm-engine-for-libtbvcoll

노트북 두 대로 큰 MoE 언어 모델을 **텐서 병렬(TP)** 로 돌리는 llama.cpp 기반 엔진이다.
HP ZBook Ultra G1a(AMD Strix Halo, Radeon 8060S gfx1151, 메모리 128 GB) 두 대를 Thunderbolt/USB4 케이블로 잇고,
층마다 두 GPU 의 부분합을 USB4 RDMA([tbv](https://github.com/mminggmmingg/thunderbolt-ibverbs-zbook))로 주고받는다.
대상 모델은 Qwen3.8-Flash-Next(qwen4exp — 512 전문가 MoE, 48층, hyper-connection, 최대 문맥 262,144)이고, 가중치는 우리 비트 배분 H5(92 GiB)다.

## 결과 (2026-11-12)

| 구성 | 디코드 t/s | 비고 |
|---|---:|---|
| 2노드 TP | **46.4** | 토큰마다 노드 하나가 가중치 2.83 GB 를 읽음 → 노드당 131 GB/s, 메모리 대역폭의 55%(DRAM 실측 읽기 A 3.18 · B 3.17 GB/토큰 기준 61.6 · 61.4%). 11-12 오후 번갈아 2쌍 평균(46.43) |
| 2노드 TP + MTP 추측 디코딩 | **63.6** | 초안 3토큰(모델의 MTP 층), 채택률 0.64. 11-12 오후 번갈아 3쌍 평균(63.62) |
| (참고) 1노드, 같은 모델 | 18.5 / MTP 31.2 | 2026-10-30 엔진, A 의 느린 상태. 그 뒤 개선은 2노드로만 쟀다 |

- 측정: llama-server, greedy(temperature 0), 프롬프트 6개(영어 글·코드·한국어·수학·JSON·요약) × 최대 256 토큰, 서버가 잰 디코드 속도의 토큰 가중 평균.
  프롬프트가 짧은(수백 토큰) 경우의 값이다.
- **긴 문맥:** 문맥 깊이 32k 에서 none 34.6 · MTP 40.5, 128k 에서 21.7 · 20.5, 최대(260,096)에서 14.9 · 13.5 t/s.
  문맥을 처음 채우는 데 128k 는 8.5 분(256 t/s), 260k 는 23.6 분(184 t/s).
  깊이에 따라 늘어나는 시간의 94% 가 전체 attention(QSA) 층 12개다 — 아래 [컨텍스트 길이별 성능](#컨텍스트-길이별-성능-2026-11-12).
- **출력 확인:** 최적화마다 같은 프롬프트의 출력 해시가 기준과 같은지 본다. 기준은 모드(none·MTP)별로 둔다 — 아래 [출력이 그대로인지 확인하는 법](#출력이-그대로인지-확인하는-법).
- **목표: 노드당 메모리 대역폭의 85% 이상.** 기준은 1노드 GPU 읽기 실측 239.7 GB/s(이론 256 GB/s). 지금 61.6 · 61.4% 이고,
  지금 읽는 바이트(≈3.18 GB/토큰)로 85% 는 none ≈64 t/s 다.
- 비효율 전수 조사(2026-11-08): 토큰 24.04 ms 중 가중치 읽기 최소 시간 11.72 ms, 나머지 12.3 ms 가 커널 사이 빈틈 3.95 · 행렬곱 대역폭 손실 3.71 ·
  행렬곱 밖 커널 2.84 · AR 기다림 1.15 · 토큰 경계 0.67 ms — [docs/INEFFICIENCY_20261108.md](docs/INEFFICIENCY_20261108.md). 그 뒤 개선은 아래 표.
- 다음 단계 설계: 구간별 큰 커널(AR 사이 부분그래프 하나 = 상주 블록 커널 하나, 동기화 0.3–0.7 µs, 가중치 앞서 읽기·MALL) — [docs/DESIGN_megakernel.md](docs/DESIGN_megakernel.md).
- 날마다 노드 상태에 따라 ±2% 흔들린다. 같은 날 번갈아 잰 끔/켬 비교는 [RESULTS.md](RESULTS.md) 의 각 절에 있다.

## 컨텍스트 길이별 성능 (2026-11-12)

문맥(KV 캐시)이 이미 d 토큰 차 있을 때의 속도. 깊이 0–128k 는 3회씩, 260,096 은 1회 쟀다. 구성은 위 결과와 같은 기본 빌드다.

| 문맥 깊이 d (토큰) | 문맥 채우기 t/s | 채우는 시간 s | pp512 @ d t/s | tg128 @ d t/s (none) | tg128 @ d t/s (MTP) | MTP 채택률 |
|---:|---:|---:|---:|---:|---:|---:|
| 0 | — | — | 407.1 ± 10.4 | **43.8 ± 0.3** | **49.5 ± 1.5** | 51% ± 4 |
| 4,096 (4k) | 450.8 ± 3.7 | 9.1 ± 0.1 | 357.7 ± 2.1 | **40.1 ± 0.2** | **51.4 ± 2.9** | 62% ± 6 |
| 8,192 (8k) | 451.7 ± 1.7 | 18.1 ± 0.1 | 342.6 ± 0.4 | **39.3 ± 0.1** | **45.8 ± 7.2** | 57% ± 15 |
| 16,384 (16k) | 434.4 ± 2.3 | 37.7 ± 0.2 | 326.0 ± 3.4 | **37.4 ± 0.1** | **55.6 ± 1.5** | 86% ± 5 |
| 32,768 (32k) | 401.6 ± 2.4 | 81.6 ± 0.5 | 284.9 ± 1.3 | **34.6 ± 0.2** | **40.5 ± 7.4** | 63% ± 19 |
| 65,536 (64k) | 334.3 ± 4.8 | 196.0 ± 2.8 | 221.3 ± 5.8 | **29.4 ± 0.2** | **27.7 ± 3.6** | 48% ± 12 |
| 131,072 (128k) | 256.2 ± 0.4 | 511.5 ± 0.9 | 157.4 ± 1.2 | **21.7 ± 0.1** | **20.5 ± 0.2** | 50% ± 1 |
| 260,096 (254k) | 183.6 (1회) | 1416.8 (1회) | 102.2 (1회) | **14.9 (1회)** | **13.5 (1회)** | 67% (1회) |

표 원본 `docs/ctx/ctx-table.md`. k = 1024 토큰. 문맥 채우기·pp512 는 none 회 값(MTP 회는 ±5% 안). 그림의 가로축은 깊이를 같은 간격으로 놓았다(대략 두 배씩).

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/ctx/ctx-decode-dark.svg">
  <img alt="문맥 깊이별 디코드 속도: none 은 깊이 0에서 43.8, 32k 34.6, 128k 21.7, 254k 14.9 t/s 로 꾸준히 내려가고, MTP 는 채택률에 따라 들쭉날쭉하다가 64k 부터 none 보다 조금 낮다" src="docs/ctx/ctx-decode-light.svg">
</picture>

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/ctx/ctx-prefill-dark.svg">
  <img alt="문맥 깊이별 프롬프트 처리 속도: 0에서 d까지 채우는 평균 속도는 4k 451, 128k 256, 254k 184 t/s로, 깊이 d 뒤 512토큰 처리 속도는 407에서 128k 157, 254k 102 t/s로 내려간다" src="docs/ctx/ctx-prefill-light.svg">
</picture>

**용어**(llama-bench 와 같은 이름)
- **문맥 채우기**: 빈 캐시에서 글 d 토큰을 처리하는 평균 속도와 걸린 시간. 긴 문서를 처음 넣을 때 첫 토큰까지 걸리는 시간에 가깝다.
- **pp512 @ d**: d 토큰이 캐시에 있는 상태에서 새 512토큰을 처리하는 속도(대화를 이어 갈 때).
- **tg128 @ d**: 그 뒤 128토큰을 greedy 로 생성하는 디코드 속도. MTP 채택률 = 받아들인 초안 / 낸 초안.
- 표의 값은 평균 ± 표준편차(3회), 그림의 세로 막대도 ±1 표준편차.

**방법**
- 기준으로 삼은 방식: llama.cpp `llama-bench` 의 `-d, --n-depth`(시험마다 KV 캐시를 d 토큰으로 먼저 채운 뒤 `pp512 @ d512` 처럼 잰다,
  [tools/llama-bench/README.md](https://github.com/ggml-org/llama.cpp/blob/master/tools/llama-bench/README.md)), 그리고 같은 방식을 OpenAI 호환 서버에 옮긴
  [llama-benchy](https://github.com/eugr/llama-benchy)(깊이 d 의 문맥을 먼저 보내 캐시에 두고, 이어서 pp·tg 를 잰다). 둘 다 2026-11-12 확인.
- 우리 엔진은 llama-server(2노드 RPC)로 돌기 때문에 llama-bench 대신 서버의 `/completion` 에 같은 순서로 보낸다(`tools/bench/ctx_bench.py`):
  1. 글 d 토큰, `n_predict 0` → 문맥 채우기(서버 `timings.prompt_n = d` 확인).
  2. 같은 d 토큰 + 이어지는 512토큰, `n_predict 128`, `cache_prompt`, temperature 0, `ignore_eos` → 서버가 앞 d 는 캐시에서 쓰고 512토큰만 처리
     (`prompt_n = 512` 를 회마다 확인) → pp512 @ d, tg128 @ d.
  - 측정마다 글의 시작 자리를 1024토큰씩 옮겨 앞 측정의 캐시를 쓰지 못하게 했다. 첫 측정 전에 기록하지 않는 데우기 요청 하나.
  - 시간은 모두 서버가 잰 값(`timings`, HTTP·토큰화 제외).
- 글: 상류 llama.cpp `e09a78a` 의 문서(docs/**/*.md, tools/server/README.md)와 src/*.cpp 를 이은 4.76 MB(`tools/bench/ctx_corpus.sh`,
  sha256 `7dccee037059a590b1bff906ac2e7c68a1205eb5f8c3f1e923020149cc50c208`, 저장소에는 없음 — 스크립트로 다시 만든다). 무작위 토큰이 아니라 실제 글이라야
  MTP 채택률이 의미가 있다.
- 서버: `-c 262144`(모델 최대 문맥 전체, KV f16), `-fa on`, `-b 2048 -ub 512`(기본), 슬롯 1, 위 결과와 같은 환경.
  깊이 260,096 은 + 512 + 128 = 260,736 이 262,144 안에 들도록 고른 최대 깊이다.
- 원자료: `fixcost/ctx-1112/`(run-ctx·run-max2 .sh·log, 회별 `*-ctx.jsonl`·bench.txt, 감시기 비교표·영수증, 실패한 회의 기록), 표·그림 `docs/ctx/`(`tools/bench/ctx_plot.py`).

**읽는 법**
- **none 디코드는 깊어질수록 느려진다**: 43.8(0) → 34.6(32k, −21%) → 21.7(128k, −50%) → 14.9 t/s(254k). 한 토큰 시간으로는 깊이에 거의 정비례한다
  (22.8 → 46.1 → 67.1 ms). 3회 편차가 ±0.3 이하라 글 내용과 상관없다.
- **늘어나는 시간은 거의 다 QSA 층 12개다.** 감시기 기록(기록 링 켠 none 회, AR 사이 구간마다 GPU 계산 시간 중앙값, 노드 A)으로 나누면:

  | 깊이 | 디코드 한 단계 | QSA 층 12개 구간 (층당) | 나머지 82구간 (GDN 36층·MoE 48층 등) | 단계 경계 구간 |
  |---:|---:|---:|---:|---:|
  | 0 | 22.83 ms | 2.85 ms (0.24) | 13.49 ms | 2.98 ms |
  | 32k | 28.93 ms | 8.54 ms (0.71) | 13.94 ms | 3.11 ms |
  | 128k | 45.76 ms | 24.38 ms (2.03) | 14.39 ms | 4.24 ms |

  0 → 128k 에서 늘어난 22.9 ms 중 21.5 ms(94%)가 QSA 층이고, QSA 층 하나의 시간은 문맥 토큰당 ≈14 ns 씩 선형으로 는다. B 노드도 같다.
  GDN(선형 attention) 층은 상태 크기가 고정이라 깊이와 상관없다.
  - 추론(커널별 분해는 아직): 문맥에 비례하는 몫은 두 가지로 본다. 하나는 인덱서가 압축 키 전부(d/4개)에 점수를 매기고 top-k 를 고르는 계산이고,
    다른 하나는 마스크를 쓴 attention 이 KV 전부를 읽는 몫이다(노드당 KV 헤드 1개 × K·V 256차원 f16 = 층마다 토큰당 1 KB → 128k 에서 12층 1.6 GB/토큰).
    - 같은 감시기 회의 DRAM 실측은 토큰당 3.85 GB(깊이 0·32k·128k 섞임)로, 짧은 문맥(3.18 GB)보다 0.67 GB 많다. KV 를 다 읽는다고 치면 세 깊이 평균 ≈0.64 GB 이므로 맞는 쪽이다.
    - 그래도 128k 에서 KV 1.6 GB 읽기는 ≈8 ms 몫이라, QSA 에서 늘어난 21.5 ms 의 나머지는 계산(인덱서·top-k·attention 커널) 쪽이다.
  - 짧은 문맥 인덱서 건너뛰기(`LLAMA_QSA_SHORT`)는 KV 가 2048칸 안일 때만 걸린다 — 깊이 4k 부터는 인덱서가 그대로 돈다.
- **MTP 는 채택률이 글에 따라 크게 바뀐다**(깊이별 평균 48–86%, 같은 깊이 3회 사이 표준편차도 최대 ±19%p). 깊이별 차이의 대부분은 생성 자리의 글이
  달라서이고, 위 표에서는 64k 부터 none 보다 느리다. 그런데 이기는 데 필요한 채택률도 깊이에 따라 오른다. 감시기 회(1회씩)로 보면:
  - MTP 한 주기(4토큰 검증 + 초안 3번)가 52.4(0) → 73.6(32k) → 124.2 ms(128k)로, none 한 단계(22.8 → 28.9 → 45.8 ms)보다 빨리 는다.
  - 검증 단계의 QSA 층은 층당 0.36 → 1.21 → 3.36 ms 로, 4토큰이라 1토큰의 1.7배다.
  - A GPU 혼자 도는 초안 쪽(초안 3번 + 따라잡기)도 21 → 28 → 51 ms 로 는다.
  - 그래서 주기당 필요한 토큰이 2.3 → 2.5 → 2.7 개로 늘고, none 을 이기는 채택률이 ≈43% → 51% → 57% 로 오른다(초안 3개 기준 어림).
  - 그 감시기 회의 128k 처럼 채택률이 94% 면 MTP 30.3 t/s 로 none 보다 40% 빠르고, 표의 128k 처럼 50% 면 조금 느리다.
- **프롬프트 처리**: 문맥 채우기 평균은 4k–8k 에서 451 t/s, 128k 에서 256 t/s(채우는 데 8.5 분). 깊이 d 뒤 512토큰은 407(0) → 157 t/s(128k).
  MTP 회는 깊을수록 조금 느리다(64k −4%, 128k −5%, 254k −6%) — 초안 쪽도 문맥을 처리하는 몫으로 본다(추론).
- **최대 깊이 260,096(1회)**: none 14.9 · MTP 13.5 t/s(채택률 67%). 문맥 채우기 183.6 t/s 로 23.6 분, pp512 @ d 102.2 t/s.
  none 의 첫 260k 회는 채우기 ≈16분째 클라이언트 ↔ B RPC 의 RDMA 연결 오류로 끊겨 같은 조건으로 다시 쟀다(아래 한계).
- 깊이 0 의 none 43.8 이 위 결과(46.4)보다 낮은 것은 조건이 달라서다(프롬프트 512토큰, 생성 128토큰, 다른 글). 같은 표 안에서만 비교한다.

## 구성

```
노드 A: llama-server (클라이언트; MTP 초안은 A GPU 에서)
          ├─ RPC → rpc-server A  (A GPU, 모든 층의 절반, rank 1)
          └─ RPC → rpc-server B  (B GPU, 모든 층의 절반, rank 0)
                   rpc-server A ⇄ rpc-server B : 층마다 all-reduce 2번 (tbv RDMA, 1토큰 ≈10 KB)
```

| | 두 노드 같음 |
|---|---|
| 기기 | HP ZBook Ultra G1a 14 — Ryzen AI MAX+ PRO 395, Radeon 8060S (gfx1151), 128 GB |
| 메모리 설정 | BIOS VRAM 4 GiB, GTT 112 GiB (`ttm.pages_limit=29360128`) |
| 소프트웨어 | Ubuntu 26.04.1, 커널 7.0.0-1015-oem, ROCm 7.2.1, llama.cpp `e09a78a` + [우리 패치](patches/llama-e09a78a-engine2n-t5.patch) |
| 링크 | Thunderbolt 케이블 2개 → RDMA 장치 `usb4_rdma0`·`usb4_rdma5`, 제어용 IP `thunderbolt0` 10.99.0.1 / 10.99.0.2 |
| 전송 | tbv `9a35117` 이상 — USB4 NHI 위의 ibverbs 드라이버. 묶음은 [zbook-thunderbolt-RDMA](https://github.com/mminggmmingg/zbook-thunderbolt-RDMA) |

원칙: 다중 노드는 TP 만 쓴다(층 분할·파이프라인 병렬은 쓰지 않음). 하드웨어·전원·펌웨어 설정은 바꾸지 않는다(소프트웨어만).

## 어떻게 빨라졌나

2노드 TP 디코드가 올라온 과정. 가중치는 모두 H5. 11-03 부터 11-11 까지의 변경은 출력이 그대로이고, 11-12 아침의 QSA 건너뛰기만
그래프 모양이 바뀌어 출력 기준을 새로 정했다(아래 출력 확인).

| 날짜 | 바뀐 것 | 토큰당 읽는 가중치 GB (노드당) | 2노드 TP | 2노드 TP + MTP | 가중치 읽기로 환산 GB/s (노드당) | 대역폭 활용 (239.7 GB/s 대비) |
|---|---|---:|---:|---:|---:|---:|
| 10-30 | 우리 비트 배분 H5 | 2.96 | 25.4 | 34.8 | 75 | 31% |
| 10-30 | 불러올 때 가중치 합치기(같은 날 끔 24.4 / 34.3) | 2.96 | 25.9 | 36.4 | 77 | 32% |
| 10-31 – 11-01 | 라우터 BF16, GDN 상태 캐시에서 바로 읽기, 받는 쪽 zero-copy AR, q8_1 활성값 캐시 등(11-03 아침 기준선) | 2.83 | 27.3 | 38.7 | 77 | 32% |
| 11-03 | 작은 연산 묶기·DPP(토큰당 커널 2720 → 1806) | 2.83 | 32.2 | 42.4 | 91 | 38% |
| 11-03 – 11-04 | 묶기 셋, 단계 시작 GPU 쉼 줄이기, greedy argmax, AR 링크를 두 번째 케이블로 | 2.83 | 33.6 | — | 95 | 40% |
| 11-04 | hc 블록 묶기(11-05 최종 비교의 '끔') | 2.83 | 34.4 | 42.9 | 97 | 40% |
| 11-05 새벽 | 값 그대로 커널 묶기 10개 더(A 노드 토큰당 커널 1886 → 1313) | 2.83 | 36.3 | 43.8 | 103 | 43% |
| 11-05 오후 | 서버 쪽 argmax — 로짓 대신 (최댓값, 번호)만 받음(같은 날 끔 35.4 / 44.2) | 2.83 | 36.5 | 45.5 | 103 | 43% |
| 11-06 | MTP 초안 출력층을 어휘 104459개로 줄임 — 초안만 바뀌고 출력은 그대로(같은 날 기준 MTP 46.7) | 2.83 | 36.3(초안 없음, 그대로) | 50.3 | 103 | 43% |
| 11-06 | 초안 가중치를 본 모델과 같은 낮은 비트로(같은 회차 어휘만 줄인 판 49.9) | 2.83 | 36.3 | 50.8 | 103 | 43% |
| 11-06 저녁 | AR 을 스트림 안에서(ZC=3 + 앞서기 2) — 호스트 왕복을 GPU 경로에서 뺌(같은 날 ZC=1 36.5 / 48.9) | 2.83 | 38.5 | 52.4 | 109 | 45% |
| 11-07 새벽 | AR 을 기다리는 동안 다음 가중치를 MALL 로 미리 읽기(같은 회차 끔 38.45 / 54.0) | 2.83 | 39.4 | 54.7 | 111 | 46% |
| 11-07 오전 | 엔진을 Thunderbolt 인터럽트 CPU 밖에서 — 받은 메시지를 마무리하는 kworker 와 CPU 를 나눠 쓰지 않게(같은 회차 고정 없음 39.15 / 54.9) | 2.83 | 39.6 | 56.0 | 112 | 47% |
| 11-07 낮 | tbv 가 받은 프레임을 높은 우선순위 작업에서 마무리(드라이버 패치) + AR 을 클라이언트가 안 쓰는 케이블로(같은 드라이버 같은 케이블 39.6 / 55.4) | 2.83 | 40.4 | 56.2 | 114 | 48% |
| 11-08 새벽 | tbv `rx_wq_poll=2` — 받기 작업을 인터럽트 CPU 에서 뗌(같은 부팅 `rx_wq_poll=1` 40.32) | 2.83 | 40.8 | 56.5 | 115 | 48% |
| 11-08 새벽 | MoE down 행렬곱을 블록당 4행으로 — 값 그대로(같은 밤 행 1 40.67 / MTP 55.5) | 2.83 | 41.4 | 55.6 | 117 | 49% |
| 11-08 저녁 | 토큰 경계: 입력 복사 앞 쓸데없는 기다림 빼기, 작은 RPC 명령 한 번에 쓰기, 클라이언트 기다림 돌기 — 값 그대로(같은 날 예전 40.86 / 돌기 끔 MTP 55.4) | 2.83 | 41.5 | 56.0 | 117 | 49% |
| 11-09 새벽 | 커널 줄이기: GDN 묶은 norm 을 36층 모두에, AR 부분합 내보내기를 만드는 커널이 같이(토큰당 커널 1308 → 1183) — 값 그대로(같은 밤 예전 41.72 / MTP 같음) | 2.83 | 42.1 | 56.5 | 119 | 50% |
| 11-09 아침 | AR 부분합 내보내기 묶음을 MTP 검증(4토큰)까지 — 작은 출력만 붙들게 고친 뒤(같은 빌드 1토큰만 56.36, 다섯 쌍) | 2.83 | 42.1 | 57.2 | 119 | 50% |
| 11-10 – 11-11 새벽 | MTP 검증 4토큰의 AR(40 KB)만 두 케이블로 반씩(같은 날 한 케이블 57.06), 4토큰 묶음 2개 — 값 그대로(11-11 아침 기준선) | 2.83 | 42.25 | 58.1 | 120 | 50% |
| 11-11 낮 | 생성 한도 직전에 초안을 줄이지 않기(그래프 다시 짓기가 줄어 MTP +2.7%), 서버 새 그래프 풀기 표 재사용 — 값 그대로 | 2.83 | 42.5 | 59.3 | 120 | 50% |
| 11-11 저녁 | 그래프 다시 짓기: 부분그래프 메시지 0.5–1.9 MB → 29 KB, 클라이언트 분할 상태 캐시 유지(다시 짓는 단계 128 → 70 ms) — 값 그대로 | 2.83 | 43.7 | 61.1 | 124 | 52% |
| 11-12 아침 | 짧은 문맥(KV ≤ 2048)에서 QSA 인덱서 건너뛰기 — **출력 기준을 새로 정함** | 2.83 | 45.5 | 61.4 | 129 | 54% |
| **11-12 오후** | **서버 쪽 노드 패턴 융합 3개(PLE 게이트·PLE conv 섞기·QSA 마스크, 토큰당 커널 1134 → 1060) — 값 그대로(같은 날 번갈아 끔 45.48 / 62.65)** | **2.83** | **46.4** | **63.6** | **131** | **55%** |

- 토큰당 읽는 가중치: 디코드 1단계에 노드 하나가 읽는 양(`tools/bytes_per_token.py 512 10 loaded tp=2`). 나뉘는 텐서(attention·GDN 투영, 활성 전문가, 출력층)는
  절반, 두 노드에 복제되는 텐서(hyper-connection, shared expert, 라우터, indexer)는 전부. KV 캐시·GDN 상태·임베딩 조회는 뺐다. MTP 는 한 단계에 여러 토큰을 검증하므로
  이 값이 생성 토큰당 양은 아니다.
- 환산 GB/s = 노드당 GB × t/s(MTP 없음). DRAM 실측(inferwatch `dram-bytes`, perf amd_df)은 이보다 노드당 ≈0.35 GB/토큰 많다 — 절반은 AR 을 기다리는 동안의
  가중치 미리 읽기(같은 바이트를 두 번 읽음), 나머지는 GDN 상태·활성값·문맥(RESULTS.md 2026-11-11 03:02).

큰 단계만 간추리면(자세한 수치·실패한 시도는 RESULTS.md):

- **불러올 때 가중치 합치기**(10-30): 입력이 같은 행렬 168쌍을 한 텐서로 — 커널 수가 줄어 2노드 +9.5%.
- **작은 연산 묶기**(11-03 – 11-05): 토큰당 커널 2720 → 1313. gfx1151 의 mmvq 는 열 수와 상관없이 워프 하나가 한 행을 같은 순서로 더하므로,
  32워프 블록이 연속 32행을 맡게 묶으면 비트가 같다. hc 블록, GLU → q8_1, shared expert 꼬리, GDN 게이트·norm, all-reduce 기다림-더하기를 처음 읽는 커널 안에서 등.
- **서버 쪽 argmax**(11-05): 클라이언트가 토큰마다 두 노드의 로짓(노드당 ≈0.5 MB)을 받던 것을 각 노드가 (최댓값, 번호)만 돌려주게 — +3.1%.
- **MTP 초안 출력층 줄이기**(11-06): 초안이 읽는 0.67 GB 중 0.52 GB 가 전체 어휘(248320행) 출력층이었다. 초안만 104459행 어휘로 계산하고
  나머지 로짓은 -inf 로 둔다. 초안 제안만 바뀌고 출력은 본 모델 검증이 정하므로 그대로 — MTP +7.6%(벤치와 겹치지 않는 프롬프트에서도 +7.7%).
  이어서 초안(Q8_0 MTP 층 + Q6_K 출력층)을 본 모델 H5 와 같은 형식(Q5_0·IQ4_XS·IQ4_NL, 출력층 Q4_K)으로 다시 양자화 — 초안이 읽는 양 0.37 → 0.24 GB, +1–2%.
- **AR 을 스트림 안에서**(11-06 저녁): AR 한 번을 GPU 도장으로 나눠 보니 252 µs 주기 중 GPU 가 호스트를 기다리는 몫(동기화에서 깨어남 7 + 보내기 9 + 다음 커널 시작 8 µs)이
  선을 기다리는 몫(17 µs)보다 컸다. GPU 가 부분합과 플래그를 호스트 메모리에 직접 쓰고 대리 스레드가 주고받는 경로(ZC=3)에 서버가 2 AR 까지만 앞서게 하니
  none +6%·MTP +7%(11-04 에는 커널이 많아 깊은 큐에서 느려져 졌던 경로).
- **AR 을 기다리는 동안 다음 가중치 미리 읽기**(11-07): 작은 단계(hc down·hc up·라우터)는 가중치가 MALL(32 MB)에 있으면 2배 빠르다.
  GPU 가 상대 부분합을 기다리는 동안(토큰당 ≈4 ms) 기다림을 맡은 커널의 워프 128개가 이 부분그래프의 다음 행렬곱 가중치 16 MB 를 읽어 MALL 에 올린다
  (읽기만, 출력 그대로) — none +2.4%, MTP +1.1%. 이 실험 중 묶은 hc 블록 커널의 숨은 경쟁(보조 출력 silu 가 hc_pre 자리에 겹침)을 찾아 고쳤다.
- **엔진을 Thunderbolt 인터럽트 CPU 밖에서**(11-07 – 11-08): 1 ms 넘게 늦은 AR 의 대부분은 선로가 아니라 받는 노드의 리눅스였다. NHI 인터럽트를 받은 CPU 의
  시스템 작업 큐 kworker 가 프레임을 마무리하는데, 엔진의 바쁜 대기 스레드가 같은 CPU 에 오면 3 ms 조각으로 나눠 쓰고(2.9 ms 튐), 1 초마다 도는 다른 커널 작업이
  그 풀에 앉으면 9–13 ms 를 기다린다(7–12 ms 튐). 스크립트가 노드마다 인터럽트 CPU 를 읽어 세 프로세스를 그 밖에 둔다(`tools/bench/tbcpus.sh`) — none +1.1%, MTP +2.1%.
  이어 tbv 드라이버가 받은 프레임을 CPU 별 높은 우선순위 작업 큐에서 마무리하게 고치고([tbv 브랜치 rx-highpri-poll](https://github.com/mminggmmingg/thunderbolt-ibverbs-zbook/tree/rx-highpri-poll),
  `tools/tbv_rxwq.sh`), AR 을 클라이언트 명령이 몰리지 않는 두 번째 케이블로 보내 1 ms 넘는 기다림이 단계당 1.7–2.4 → 0.75 ms — 둘을 합쳐 none +2.0%, MTP +2.1%.
  ROCm 런타임 스레드가 받기 CPU 에 앉는 경우는 `HSA_OVERRIDE_CPU_AFFINITY_DEBUG=0` 으로 막고, 남은 늦음은 tbv `rx_wq_poll=2` 로 받기 작업을 인터럽트 CPU 에서 떼어
  1 ms 넘는 링크 늦음이 0번이 됐다(none +1.2%).
- **작은 K 행렬곱의 블록당 행 수**(11-08): gfx1151 은 1토큰 행렬곱을 블록마다 워프 1개·행 1개로 돈다. MoE down 은 노드당 K=320 이라 워프가 한 바퀴만 돌고
  가중치보다 활성값을 더 읽어 152 GB/s 에 머물렀다. 블록당 4행이 활성값 읽기를 나눠 쓰게 하니 none +1.7%, 값 그대로. K 가 긴 Q5_0 에 같은 것을 하면 느려진다.
- **토큰 경계**(11-08 저녁): 토큰마다 첫 부분그래프 앞 입력 복사 18개 중 9개가 두 RPC 장치 큐를 한 바퀴 도는 synchronize 를 끼고 있었다. 쌓인 일이 없으면 기다리지 않게 해
  복사 합 277 → 68 µs, 같은 노드 서버로 가는 명령은 send() 3번 → 1번, 잠들어 기다리던 클라이언트를 돌며 기다리게 해 none +1.0%, MTP +1.7%.
- **두 레일**(11-10 – 11-11): MTP 검증 4토큰의 AR(40 KB)만 두 케이블로 반씩 보내 AR 지연 A→B 중앙 42 → 33 µs, MTP +0.8–1.5%.
  none 의 1토큰 AR(10 KB)은 나누면 손해라 MTP 회에서만 켠다.
- **그래프 다시 짓기**(11-11): 프롬프트 첫 decode·KV 패딩 경계마다 그래프를 다시 지어 한 번에 90–130 ms 가 들었다(벤치 decode 시간의 8–13%). 원인은 RPC 직렬화가
  부분그래프마다 앞 층들의 텐서를 끝없이 따라 올라가 메시지가 0.5–1.9 MB 까지 커진 것(노드 밖 소스는 2단계까지만 보내 29 KB)과 클라이언트 쪽 분할 상태 캐시를
  통째로 비우던 것. 다시 짓는 단계 128 → 70 → 64.5 ms, 생성 한도 직전 초안 줄이기도 없애 다시 짓기 횟수를 줄였다 — 하루에 none 42.25 → 43.7, MTP 58.1 → 61.1.
- **짧은 문맥 QSA 인덱서 건너뛰기**(11-12 아침): 추론 감시기의 critical path 로 전체 attention 층(12개)이 GDN 층보다 단계마다 140 µs 길다는 것을 찾았다.
  KV 가 인덱서 top-k 예산(2048칸) 안이면 인덱서는 언제나 모든 블록을 고르므로 그 계산을 건너뛰고 블록 가시성만으로 같은 마스크를 만든다(마스크 732개 비교 모두 같음,
  `LLAMA_QSA_SHORT`, `=0` 이면 예전 경로). 번갈아 3쌍에서 none +3.5%, MTP +2.0%. 문맥이 2048 을 넘으면 원래 경로다.
- **서버 쪽 노드 패턴 융합**(11-12 오후): 감시기의 AR 사이 구간별 GPU 시간에서 1층(GDN + PLE n-gram 갈래) 구간이 691 µs(다른 GDN 구간 ≈210 µs)였다. PLE 갈래가
  행렬곱 2개 + 원소별 커널 ≈31개였고, QSA 마스크는 12층이 같은 값을 층마다 5커널로 다시 만들었다. 그래프 모양을 바꾸면 출력이 바뀌는 엔진이라(아래)
  클라이언트 그래프는 그대로 두고 서버 CUDA 쪽이 노드 패턴을 알아보고 커널 하나로 돌린다 — PLE 게이트 8 → 1, PLE conv 섞기 ≈40 → 1
  (MTP 의 되돌리기 칸마다 저장하는 상태 꼬리까지), QSA 마스크 5 → 1. none +2.1%, MTP +1.6%, 29회 출력 모두 기준과 같음.
- MTP 한 주기(11-06, 어휘만 줄인 판) ≈54.5 ms 에 ≈2.9 토큰: 4토큰 검증(2노드) 45.7 ms + 초안 따라잡기 1.3 ms + 초안 3번 × 2.5 ms. 남은 큰 몫은 검증이다.

### 출력이 그대로인지 확인하는 법

- 기준 해시(6 프롬프트, 256 토큰)는 2026-11-12 부터 모드별이다 — `python3 -I fixcost/gluhc-1108/hashchk.py runs/.../bench.txt`(모드는 파일 이름에서 읽음).
  - none: `6c1596 ce5ae3 ecfc02 810ea2 a27f06 e0ee11`
  - MTP(초안 3): `d28991 344aad 5942d0 412ba5 a27f06 e0ee11`
  - 이전 기준(11-08, none·MTP 같음): `c400cb 40b428 572e7e 412ba5 e5be2a d67a87` — 지금 빌드도 `LLAMA_QSA_SHORT=0` 이면 그대로 낸다(`HASHREF=1108`).
- 모드별이 된 까닭: 이 엔진은 **계산에 쓰지 않는 노드 하나만 그래프에 더해도** 39층 출력에서 처음 ≈1e-3 차이가 생겨 greedy 출력이 거의 동점인 자리에서 갈린다
  (그래프 모양 민감성, 원인 미확인 — 노드 순서·할당 위치에 따른 커널 경로나 합산 순서로 봄). QSA 건너뛰기는 마스크가 같은데도 그래프 모양이 바뀌어 출력이 바뀌었고,
  1토큰 그래프와 4토큰 검증 그래프에 다르게 걸려 none·MTP 출력이 서로 달라졌다. 품질은 같다 — Q8_0 원본 기준 KLD 끔/켬 똑같음(0.067849, 1위 일치 94.706%),
  갈린 자리는 1·2위 차 0.006–0.137 nats. 그래서 그 뒤 최적화는 클라이언트 그래프를 바꾸지 않는 서버 쪽 융합으로 한다.
- 묶은 커널은 할당기가 출력을 아직 읽히는 입력 자리에 놓으면 묶지 않는다(`ggml_cuda_overlaps_srcs`). 이 검사 없이 한 번, 상대 노드 GPU 를 다른 프로세스가 같이 쓸 때만
  출력이 바뀌는 경쟁이 있었다(RESULTS.md 2026-11-05 23:25). 새 묶기는 상대 노드에 GPU 부하를 띄엄띄엄 거는 조건(`fixcost/nondet-1105/repro.sh`)에서도 확인한다.
- 묶기마다 끄는 스위치와 `*_VERIFY`(따로 돌린 결과와 비트 비교), 융합 성공 횟수 세기(`GGML_CUDA_FUSE_COUNT=1`)가 있다 — 목록은 [docs/SWITCHES.md](docs/SWITCHES.md).
- 비트를 바꾸는 변경은 이렇게 판정한다: 같은 글 2048토큰의 로짓을 끔과 비교한 KLD 를 이미 받아들인 반올림 차이(TP vs 1노드 0.0136, 한 번에 넣는 토큰 수 0.0124)와
  견주고, Q8_0 원본 로짓과의 KLD·1위 일치, 갈린 자리의 1·2위 로그확률(`tools/divergence.py`·`tools/layerdiff.py`)을 본다(RESULTS.md 2026-11-06 22:40, 2026-11-12 02:13).

## 시각 자료 — 추론 감시 보고서(inferwatch)

추론 감시기 inferwatch(11-10 까지의 판은 `tools/watch/`, 그 뒤 판은 별도 저장소의 고정 사본 — `tools/bench/node-ab.sh` 의 `IW`)를 켜 두면 실행마다 두 서버·클라이언트의
기록 링을 모아 `runs/watch/<시각>/report.html`(타임라인 + 영수증 표)과 `receipt.md` 를 만든다. 대표 넷을 `docs/watch/` 에 둔다 — HTML 은 받아서 브라우저로 연다(각 ≈11 MB).
11-05 – 11-07 의 기록이라 지금 기본보다 느리다. 최근 회의 비교표는 `fixcost/*/watch-summary-*.md`(예: [11-12 융합](fixcost/fuse-1112/watch-summary-1112-133002.md)).

| 보고서 | 상황 | 디코드 t/s (서버 측정) |
|---|---|---:|
| [none, 묶기 10개 뒤](docs/watch/20261105-0217-none-fusions.html) · [영수증](docs/watch/20261105-0217-none-fusions-receipt.md) · [그림](docs/watch/20261105-0217-none-fusions.png) | 11-05 02:17, 1토큰 디코드 | 35.4 |
| [none, 서버 쪽 argmax 뒤](docs/watch/20261105-2003-none-argmax.html) · [영수증](docs/watch/20261105-2003-none-argmax-receipt.md) · [그림](docs/watch/20261105-2003-none-argmax.png) | 11-05 20:03, AR 이 호스트 왕복(ZC=1) | 36.45 |
| [none, AR 스트림 안 + 기다리는 동안 선읽기](docs/watch/20261107-0443-none-zc3-prefetch.html) · [영수증](docs/watch/20261107-0443-none-zc3-prefetch-receipt.md) · [그림](docs/watch/20261107-0443-none-zc3-prefetch.png) | 11-07 04:43(기록 켠 탓에 ≈6% 느림) | 39.17 |
| [MTP](docs/watch/20261105-1702-mtp.html) · [영수증](docs/watch/20261105-1702-mtp-receipt.md) · [그림](docs/watch/20261105-1702-mtp.png) | 11-05 17:02, 초안 3 | 45.85 |

![2노드 추론 기록: 1토큰 디코드](docs/watch/20261107-0443-none-zc3-prefetch.png)

- 위 타임라인: 클라이언트 decode 단계, 클라이언트 → A·B 명령, 두 서버 스레드, 두 GPU, 노드 사이 부분합 전송(선, 빨강 = 1 ms 넘게 걸림), GPU 클럭·소켓 전력.
  휠 = 확대/축소, 끌기 = 이동, 단계 버튼 = 한 단계씩. 아래: 단계당 시간 영수증(GPU 계산·쉼, 클라이언트 몫), 단계 사이, AR 전송 지연, GPU 가 쉰 곳.
- 주의: MTP 는 초안 단계(A GPU 만)와 검증 단계가 섞여 평균이 나온다(나누기는 `tools/bench/mtpcycle.py`). ZC=3(스트림 안 AR)에서는 GPU 도장 대신 대리 스레드
  기록으로 나눈다: 계산 = 앞 AR 이 풀린 때 → 우리 부분합 플래그를 본 때, 상대 기다림 = 그때 → 상대 부분합 도착. 그림은 헤드리스 Chrome 으로 찍은 첫 화면.
- 깊이별 나누기(위 컨텍스트 절의 표)는 같은 기록에서 AR 을 단계(96개)로 묶고 시간 간격으로 깊이를 가른 것이다(`tools/watch/ctxseg.py`).

## 시작하기

준비(빌드는 `rocm/vllm-dev:rocm7.2.1` 컨테이너 안에서 HIP gfx1151 + RPC + RDMA):
```
git clone https://github.com/ggml-org/llama.cpp && git -C llama.cpp checkout e09a78a
git -C llama.cpp apply ../patches/llama-e09a78a-engine2n-t5.patch     # 저장소 최상위에서
./build_llama.sh                     # + llama-quantize, llama-imatrix
./eval/make_ppl_text.sh
./get_models.sh iq4                  # Qwen3.8-Flash-Next UD-IQ4_XS (93.7 GB, sha256 확인). H5 는 아래 '양자화 실험'
```
실행:
```
./run_1node.sh <q4|iq4|GGUF>                 # 1노드 기준
./run_tp.sh <GGUF|iq4> local                 # A 혼자 TP 점검(rpc-server 2개)
./run_tp.sh <GGUF|iq4> 2node [rdma|tcp]      # 2노드 TP: --rpc 10.99.0.2:50052,127.0.0.1:50052 (B = rank 0)
./eval_ppl.sh <GGUF> 1node|tplocal|tp2node   # 정합성(perplexity)
./run_server.sh 1node|2node none|mtp [N]     # llama-server 실측(추측 디코딩 포함), 프롬프트 eval/spec_prompts.json
```
컨텍스트 길이별(위 절과 같은 조건):
```
tools/bench/ctx_corpus.sh <llama.cpp 폴더> e09a78a $PWD/corpus.txt          # 글 4.76 MB, sha256 7dccee03…
export SRV_EXTRA="-c 262144" TRACE=0 BENCH_S=5400
BENCH="tools/bench/ctx_bench.py $PWD/corpus.txt 0,4096,8192,16384,32768,65536,131072 3 {OUT}/ctx.jsonl" tools/bench/srv-probe.sh 2node none   # mtp 도 같게
python3 -I tools/bench/ctx_plot.py docs/ctx none=runs/<none 회>/ctx.jsonl mtp=runs/<mtp 회>/ctx.jsonl              # 표(ctx-table.md)와 SVG
```
MTP 초안 파일: `./get_models.sh mtp` 로 받는 공유형 MTP 파일은 본 모델의 `token_embd`·`output` 을 빌려 쓰는 형식이라 이 llama.cpp 가 단독으로 못 연다.
본 모델 조각에서 두 텐서를 붙이고, 출력층을 줄인 다음 낮은 비트로 다시 양자화한다(`run_server.sh` 기본). 말뭉치는 2노드 서버를 띄워 모은다
(우리 것은 `fixcost/dvocab-1106/corpus-tokens.jsonl`):
```
python3 -I tools/gguf_merge_mtp.py <MTP/mtp-...-shared-Q8_0.gguf> <UD-IQ4_XS/...-00002-of-00003.gguf> <MTP/mtp-...-merged-IQ4embd.gguf> token_embd.weight output.weight
BENCH="tools/draft_vocab_corpus.py $PWD/eval/draft_vocab_prompts.json 384 $PWD/corpus-tokens.jsonl" MTP=<merged-IQ4embd.gguf> tools/bench/srv-probe.sh 2node mtp
python3 -I tools/draft_vocab_select.py corpus-tokens.jsonl 98304 <MTP/mtp-...-merged-IQ4embd.gguf> ids-96k-ko.txt ko
python3 -I tools/gguf_draft_vocab.py <MTP/mtp-...-merged-IQ4embd.gguf> ids-96k-ko.txt <MTP/mtp-...-merged-IQ4embd-dv96k-ko.gguf>
llama-quantize --allow-requantize --pure --tensor-type-file fixcost/dvocab-1106/draft-qmix.types <...-dv96k-ko.gguf> <MTP/mtp-...-merged-IQ4embd-dv96k-ko-qmix.gguf> Q8_0
```

## 측정 방법

- `run_server.sh`(= `tools/bench/srv-probe.sh`)가 두 rpc-server 와 llama-server 를 띄우고 `tools/spec_bench.py` 로 6 프롬프트를 돌린 뒤 내린다.
  결과는 `runs/srv-<topo>-<spec>-<시각>/results.jsonl`(프롬프트별 t/s, 초안 수·채택 수, 출력 해시)과 두 노드의 GPU 클럭·전력 기록.
  `BENCH=` 를 주면 다른 클라이언트(예: 컨텍스트 길이별 `tools/bench/ctx_bench.py`)를 같은 서버 구성으로 돌린다.
- 끔/켬 비교는 `tools/bench/node-ab.sh`: 구성마다 서버·클라이언트 환경을 주고 번갈아 돌린다. 두 노드 부하가 낮을 때 시작하고, all-reduce 링크가 RDMA 로
  안 붙은 회는 다시 돌린다. 속도 회는 기록 링을 끄고 재고, 이어서 구성마다 추론 감시 세션을 하나씩 남겨 비교표(단계 시간, AR 지연, 1 ms 넘는 기다림의 원인,
  링크 늦음 크기, 노드별 DRAM 읽기 바이트)를 `watch-summary-*.md` 로 쓴다(`WATCH=0` 이면 속도 회만).
- 재기 전에: 두 노드 `cat /sys/firmware/acpi/platform_profile` 이 performance 인지(재부팅 뒤 절전으로 켜지면 ≈10% 느림), 상대 노드에서 다른 GPU 작업이 없는지,
  측정 중에 빌드하지 않는지(돌고 있는 서버 바이너리를 덮어씀), 앞 측정 스크립트가 남아 있지 않은지(두 벤치가 서로의 서버를 내린다).
- 시간 분해: 추론 감시기(위 시각 자료), `tools/bench/prof2node.sh`(A 서버 rocprofv3 커널 표), `tools/bench/mtpcycle.py`(MTP 한 주기 나누기).

## 양자화 구성 비교 (2026-10-30 엔진)

엔진 개선 전에 잰 구성별 값. 그 뒤 엔진 개선은 H5 로만 쟀다(위 표).

| 구성 | 토큰당 읽는 가중치 GB (1노드 전체 / 2노드 노드당) | PPL | 1노드 직렬 | 1노드 + MTP | 2노드 TP | 2노드 TP + MTP |
|---|---:|---:|---:|---:|---:|---:|
| Q8_0 (원본 기준) | 7.30 / 4.28 | 2.0660 | 한 대에 안 들어감 | — | 20.9 | **31.3** |
| unsloth UD-IQ4_XS | 5.84 / 3.56 | 2.1682 | 17.5–17.8 | 31.1–31.3 | 22.6–23.3 | 34.3–34.5 |
| **H5** (우리 배분, Q8_0 에서) | 4.82 / 2.96 | **2.1359** | 18.5 | 31.2 | **25.4** | **34.8** |
| H (halogen 식 밀집 4-bit) | 4.40 / 2.73 | 2.1477 | 19.9 | 32.6 | 25.3 | 34.1 |
| **H5 + 불러올 때 가중치 합치기** (같은 날 같은 조건 끔 → 켬) | 4.82 / 2.96 | 2.1179 | (llama-bench 19.5 → 21.0, 그래프 끔 21.8) | 32.6 → **33.4** | 24.4 → **25.9** | 34.3 → **36.4** |
| (참고) halogen 자체 체크포인트, 개발사 측정 | — | — | 35.4 | 55–57 | — | — |

- t/s, llama-server 6 프롬프트. 1노드 값은 A 의 '느린 상태'(TB 활동 없음, 빠른 상태에서는 ≈+20%). 2노드는 B rank 0, 발행 겹치기 2, 서버 HIP 그래프 끔, FFN 320/320.
- 토큰당 읽는 가중치는 이때 엔진(라우터 F32) 기준 `tools/bytes_per_token.py 512 10 [tp=2]`. 합치기는 H5 에서 바이트가 거의 안 바뀐다(hc inject 만 Q8_0 → Q6_K).
  Q8_0 은 노드당 읽는 양이 H5 의 1.45배인데 2노드 디코드는 18% 만 느림 — 2노드는 가중치보다 고정비에 묶여 있었다.
- 비트 배분(`tools/make_mix.py`, `quant/`): 전문가 IQ4_XS(down IQ4_NL), o_proj Q8_0, hyper-connection Q6_K/Q8_0, 몸통 4-bit(H) 또는 Q5_0(H5), imatrix.
  gfx1151 에서 IQ3_S 는 4-bit 보다 빠르지 않고 K 형식은 묶음 4 에서 1.7배 느려서(커널 표) 고른 형식.
- MTP 를 켜면 배분과 상관없이 속도가 같다 → 남은 차이는 엔진 고정비(토큰당 ≈19–28 ms).

## 양자화 실험 (`quant/`)
```
python3 -I tools/gguf_head.py <조각.gguf> | grep '  T ' > quant/orig.tensors        # 텐서 목록
python3 -I tools/make_types.py <형식> <그룹,...> < quant/orig.tensors > quant/X.types   # 그룹: attn, gdn, hc, shexp, ple
[IMATRIX=quant/imatrix-orig.gguf] quant/run_variant.sh quant/X.types <태그>         # 변환 → 1노드 디코드 → PPL
python3 -I tools/make_mix.py <H|H5> < quant/q8.tensors > quant/q8mix-H5.types        # Q8_0 원본용 그룹별 배분
quant/run_mix_suite.sh quant/q8mix-H5.types q8mix-H5                               # Q8_0 에서 변환 → UD 와 번갈아 측정 → 서버 1·2노드 × MTP
python3 -I tools/gguf_head.py <변형.gguf> | python3 -I tools/bytes_per_token.py 512 10 [loaded] [tp=2]   # 토큰당 읽는 양(loaded: 불러올 때 바꾸는 것까지, tp=2: 노드당)
./eval/make_calib_text.sh                                                          # imatrix 보정 글(평가 글과 겹치지 않음)
```
`quant/run_variant.sh` 는 변형 디렉터리(`UD-IQ4_XS-dense4/`) 안의 이전 변형 파일만 지우고 새로 만든다(디스크 부족으로 사용자 허락, 2026-10-29).
형식별 커널 속도: `TARGETS=test-backend-ops ./build_llama.sh` 후 `test-backend-ops perf -b ROCm0 -o MUL_MAT -p 'm=10240,n=[0-9]+,k=2560,bs=\[16,1\]'`(패치에 qwen4exp 모양 추가).

## 한계와 알려진 문제

- 스크립트는 우리 두 기기의 경로·주소(`/data/parksThink/...`, `10.99.0.1/2`)를 그대로 쓴다. 다른 환경에서는 `MODEL`·`MTP`·`BIN` 같은 환경변수와 스크립트 안 주소를 바꿔야 한다.
- 긴 문맥에서는 QSA 층 12개가 문맥에 비례해 느려진다(128k 에서 디코드 한 단계의 절반이 이 층들). 인덱서·top-k·attention 커널은 아직 손대지 않았다 — 다음 개선 대상.
- MTP 는 채택률이 글에 따라 크게 달라 긴 문맥(64k 이상)에서는 none 보다 느릴 수 있다. 초안 길이를 문맥이나 채택률에 맞춰 바꾸는 기능은 없다.
- none 과 MTP 의 출력은 2026-11-12 부터 서로 조금 다르다(위 출력 확인 — 그래프 모양 민감성). 초안 길이 4 이상은 출력이 또 바뀐다
  (검증 묶음이 5토큰이 되면 반올림 순서가 달라짐). 기본 초안 길이는 3.
- 아주 긴 프롬프트 처리 중 RPC 연결이 끊긴 적이 한 번 있다(2026-11-12, 260k 문맥 채우기 ≈16분째): 클라이언트가 "RDMA CQ wc error: status=5 (Work Request Flushed Error)"
  와 함께 멈췄고 두 rpc-server 는 살아 있었다. 커널 기록에는 그 연결의 재전송만 남아 원인은 모른다. 이 벤치의 다른 서버 회 8개(다시 돌린 회, 깊이 128k·260k 포함)는 끝까지 돌았다.
- 서버 시작 때 all-reduce 링크가 안 올라오면(`[comm_init] failed to connect to peer`) TCP 로 떨어져 매우 느리고 출력 해시도 달라진다(원인 미확인, 다시 띄우면 정상).
- B 를 rank 0 으로 둔다 — A 서버를 TB 주소로 등록하면 클라이언트↔A 서버가 tbv 루프백으로 협상되는데 tbv 는 같은 노드 안 QP 를 잇지 못한다.
- 엔진 패치는 이 모델(qwen4exp)과 gfx1151 에 맞춘 묶기가 많다. 다른 모델·GPU 에서는 대부분 원래 경로로 돌아간다(묶기 조건이 안 맞음).

## 저장소 구성

- `run_*.sh`, `eval_ppl.sh`, `build_llama.sh`, `get_models.sh` + `models_manifest.json`: 빌드·모델 받기·측정 실행기
- `patches/`: llama.cpp `e09a78a` 에 대한 우리 변경 전체(diff 하나)
- `tools/`: 측정·분석(`spec_bench.py`, `bench/` — 컨텍스트 길이별 `ctx_corpus.sh`·`ctx_bench.py`·`ctx_plot.py` 포함, `watch/`, GGUF 도구, 초안 어휘 도구),
  `tools/probe/`: 노드·GPU 점검(읽기만)
- `eval/`: 평가 프롬프트, 초안 어휘용 프롬프트·확인용 프롬프트, 평가·보정 글 생성 스크립트
- `quant/`: 밀집 부분 비트 배분 실험의 형식 파일·로그
- `fixcost/`: 실험별 원자료(로그·커널 표·회별 기록) — RESULTS.md 각 절이 가리킨다
- `docs/`: [SWITCHES.md](docs/SWITCHES.md)(패치·환경변수·도구 기록), `ctx/`(컨텍스트 길이별 표·그림), `watch/`(추론 감시 보고서)

문서: [DESIGN.md](DESIGN.md)(TP 설계, 폐기한 층 분할 설계는 [DESIGN_v0_pp.md](DESIGN_v0_pp.md)), [RESULTS.md](RESULTS.md)(측정 기록, 날짜 순).
이 저장소의 앞 7개 커밋은 [zbook-thunderbolt-RDMA](https://github.com/mminggmmingg/zbook-thunderbolt-RDMA) 의 `engine2n/` 이력을 옮긴 것이다.

## 라이선스

GPL-3.0 — [LICENSE](LICENSE). Copyright (C) 2026 mminggmmingg. 고쳐서 배포할 때도 같은 GPL-3.0 으로 소스를 공개해야 한다.
`patches/` 안의 llama.cpp 원래 코드(diff 의 문맥 줄)는 llama.cpp 의 MIT 라이선스(Copyright (c) 2023-2026 The ggml authors)를 따른다.
