#!/usr/bin/env bash
# llama-server 로 실제 생성 속도 측정(추측 디코딩 포함): 서버를 띄우고 tools/spec_bench.py 를 돌린 뒤 내린다.
#   run_server.sh <1node|2node> <none|mtp> [max_tokens=256]
# 2node 는 run_tp.sh 와 같은 구성(B rank 0, A 127.0.0.1, OVERLAP=2, 그래프 끔, FFN 320/320). 결과: runs/srv-<topo>-<spec>-<시각>/
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd); TOPO=${1:?1node|2node}; SPEC=${2:?none|mtp}; NMAX=${3:-256}
B=parks-zbook@10.99.0.2; BIN=${BIN:-$D/llama.cpp/build-rocm/bin}; BBIN=/home/parks-zbook/engine2n/bin
M=${MODEL:-/data/parksThink/hf-models/qwen38-flash-next-gguf/UD-IQ4_XS/Qwen3.8-Flash-Next-UD-IQ4_XS-00001-of-00003.gguf}
# 공유형 MTP 파일에 본 모델의 token_embd·output 을 붙인 파일(tools/gguf_merge_mtp.py) — 이 llama.cpp 는 공유형을 단독으로 못 연다 —
# 의 출력층을 어휘 104459개로 줄이고(tools/gguf_draft_vocab.py) 본 모델과 같은 낮은 비트로 다시 양자화한 판(2026-11-06, 출력 그대로).
# 예전 판: ...-merged-IQ4embd.gguf(전체 어휘), ...-dv96k-ko.gguf(어휘만 줄임)
MTP=${MTP:-/data/parksThink/hf-models/qwen38-flash-next-gguf/MTP/mtp-Qwen3.8-Flash-Next-merged-IQ4embd-dv96k-ko-qmix.gguf}
OUT=$D/runs/srv-$TOPO-$SPEC${TAG:+-$TAG}-$(date +%m%d-%H%M%S); mkdir -p "$OUT"; PORT=8077
export LD_LIBRARY_PATH=/opt/rocm/lib
export GGML_RDMA_CHUNK=${GGML_RDMA_CHUNK:-65536} GGML_RDMA_RX_DEPTH=${GGML_RDMA_RX_DEPTH:-48} GGML_RDMA_TX_SLOTS=${GGML_RDMA_TX_SLOTS:-4}
export GGML_RPC_COMM_OVERLAP=${GGML_RPC_COMM_OVERLAP:-2} LLAMA_TP_FFN_GRAN=${LLAMA_TP_FFN_GRAN:-32}
SRV_ENV=${SRV_ENV-GGML_CUDA_DISABLE_GRAPHS=1}
# TBPIN=1(기본): 두 rpc-server 와 llama-server 를 Thunderbolt 인터럽트를 받는 CPU 밖에서 돌린다(tools/bench/tbcpus.sh, 노드마다 읽음).
# 그 CPU 의 kworker 가 받은 메시지를 마무리하는데, 거기서 엔진의 바쁜 대기 스레드가 3 ms 단위로 CPU 를 나눠 쓰면 AR 이 ms 단위로 늦는다
# (fixcost/lnk-1107, none +1.1%, 출력 그대로). A_WRAP / B_WRAP / CLI_WRAP 을 주면 그것을 쓴다. TBPIN=0 이면 끔
# HSA_OVERRIDE_CPU_AFFINITY_DEBUG=0: ROCm 런타임(ROCr)은 자기 스레드를 만들 때 affinity 를 모든 CPU(0-31)로 되돌린다. 그 스레드가
# 받기 CPU 에 앉으면 tbv 의 높은 우선순위 받기 작업이 3–4 ms 줄을 섰다(fixcost/tx-1107: 링크 늦음 389 → 56번, 1 ms 넘는 기다림
# 1.42 → 0.36 ms/단계). 0 이면 런타임 스레드도 taskset 범위를 물려받는다.
PIN_A=""; PIN_B=""
if [ "${TBPIN:-1}" != 0 ]; then
  PIN_A="env HSA_OVERRIDE_CPU_AFFINITY_DEBUG=0 taskset -c $(bash "$D/tools/bench/tbcpus.sh")"
  [ "$TOPO" = 2node ] && PIN_B="env HSA_OVERRIDE_CPU_AFFINITY_DEBUG=0 taskset -c $(ssh -o BatchMode=yes $B "bash -s" < "$D/tools/bench/tbcpus.sh")"
fi
# TBDEV=1(기본): tbv 가 받은 프레임을 높은 우선순위 작업에서 마무리하면(rx_wq_poll, tbv 브랜치 rx-highpri-poll) AR 링크를 그 노드에서
# 클라이언트 연결이 쓰지 않는 RDMA 장치로(tools/bench/tbcommdev.sh, 노드마다 읽음 — 장치 이름은 재부팅 때 바뀔 수 있다). none +2.0%, MTP +2.1%.
# 기본 tbv 경로면 비워 둔다(그때는 이득 없음). SRV_ENV / SRV_ENV_B 에 GGML_RPC_COMM_DEV 를 주면 그것이 이긴다. TBDEV=0 이면 끔
DEV_A=""; DEV_B=""
if [ "${TBDEV:-1}" != 0 ]; then
  DEV_A=$(bash "$D/tools/bench/tbcommdev.sh")
  [ "$TOPO" = 2node ] && DEV_B=$(ssh -o BatchMode=yes $B "bash -s" < "$D/tools/bench/tbcommdev.sh")
fi
echo "A ${A_WRAP:-$PIN_A} | B ${B_WRAP:-$PIN_B} | client ${CLI_WRAP:-$PIN_A} | AR dev A ${DEV_A:--} B ${DEV_B:--}" > "$OUT/pin.txt"
ARGS=(-m "$M" -ngl 99 -fa on -c 8192 -np 1 --port $PORT --host 127.0.0.1 ${SRV_EXTRA:-})
[ "$SPEC" = mtp ] && ARGS+=(-md "$MTP" --spec-type draft-mtp -ngld 99 ${SPEC_EXTRA:-})
if [ "$TOPO" = 2node ]; then
  env ${DEV_A:+GGML_RPC_COMM_DEV=$DEV_A} $SRV_ENV nohup ${A_WRAP:-$PIN_A} "$BIN/ggml-rpc-server" -H 127.0.0.1 -p 50052 > "$OUT/rpc-a.log" 2>&1 & echo $! >> "$OUT/pids"
  ssh -o BatchMode=yes $B "mkdir -p $BBIN; pkill -x ggml-rpc-server; sleep 1"; scp -q "$BIN/ggml-rpc-server" "$B:$BBIN/" || exit 3
  ssh -o BatchMode=yes $B "cd $BBIN && LD_LIBRARY_PATH=/opt/rocm/lib GGML_RDMA_RX_DEPTH=$GGML_RDMA_RX_DEPTH GGML_RDMA_CHUNK=$GGML_RDMA_CHUNK GGML_RDMA_TX_SLOTS=$GGML_RDMA_TX_SLOTS GGML_RPC_COMM_OVERLAP=$GGML_RPC_COMM_OVERLAP ${DEV_B:+GGML_RPC_COMM_DEV=$DEV_B} $SRV_ENV ${B_WRAP:-$PIN_B} setsid -f ./ggml-rpc-server -H 10.99.0.2 -p 50052 -c > rpc-server.log 2>&1 < /dev/null"
  ARGS+=(--rpc 10.99.0.2:50052,127.0.0.1:50052 -sm tensor -dev RPC0,RPC1)
  sleep 3
fi
env ${CLI_ENV:-} nohup ${CLI_WRAP:-$PIN_A} "$BIN/llama-server" "${ARGS[@]}" > "$OUT/server.log" 2>&1 & echo $! >> "$OUT/pids"
for i in $(seq 600); do curl -sf http://127.0.0.1:$PORT/health > /dev/null && break; sleep 1; done
curl -sf http://127.0.0.1:$PORT/health > /dev/null || { echo "server not ready"; tail -20 "$OUT/server.log"; }
python3 -I "$D/tools/spec_bench.py" http://127.0.0.1:$PORT "$D/eval/spec_prompts.json" "$NMAX" "$OUT/results.jsonl" | tee "$OUT/bench.txt"
grep -iE 'draft|mtp|spec' "$OUT/server.log" | grep -v '^\s*$' | head -6
# llama-server 를 먼저 내리고(끝날 때 RPC 서버에 메모리를 묻는다) 그다음 RPC 서버
SP=$(tail -1 "$OUT/pids"); kill $SP 2>/dev/null; while kill -0 $SP 2>/dev/null; do sleep 1; done
xargs -r kill < "$OUT/pids" 2>/dev/null
# 다음 실행이 메모리 부족을 겪지 않게, 프로세스가 끝나 GPU 메모리를 돌려줄 때까지 기다린다
for p in $(cat "$OUT/pids"); do while kill -0 $p 2>/dev/null; do sleep 1; done; done; sleep 3
[ "$TOPO" = 2node ] && ssh -o BatchMode=yes $B "pkill -x ggml-rpc-server"
echo "$OUT"
