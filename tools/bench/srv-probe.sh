#!/usr/bin/env bash
# llama-server 로 실제 생성 속도 측정(추측 디코딩 포함): 서버를 띄우고 tools/spec_bench.py 를 돌린 뒤 내린다.
#   run_server.sh <1node|2node> <none|mtp> [max_tokens=256]
# 2node 는 run_tp.sh 와 같은 구성(B rank 0, A 127.0.0.1, OVERLAP=2, 그래프 끔, FFN 320/320). 결과: runs/srv-<topo>-<spec>-<시각>/
set -uo pipefail
D=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; TOPO=${1:?1node|2node}; SPEC=${2:?none|mtp}; NMAX=${3:-256}
# ssh 가 끊긴 링크에서 영영 기다리지 않게(2026-11-10 재발 방지)
SSHO="-o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=15 -o ServerAliveCountMax=4"
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
  [ "$TOPO" = 2node ] && PIN_B="env HSA_OVERRIDE_CPU_AFFINITY_DEBUG=0 taskset -c $(ssh $SSHO $B "bash -s" < "$D/tools/bench/tbcpus.sh")"
fi
# TBDEV=1(기본): tbv 가 받은 프레임을 높은 우선순위 작업에서 마무리하면(rx_wq_poll, tbv 브랜치 rx-highpri-poll) AR 링크를 그 노드에서
# 클라이언트 연결이 쓰지 않는 RDMA 장치로(tools/bench/tbcommdev.sh, 노드마다 읽음 — 장치 이름은 재부팅 때 바뀔 수 있다). none +2.0%, MTP +2.1%.
# 기본 tbv 경로면 비워 둔다(그때는 이득 없음). SRV_ENV / SRV_ENV_B 에 GGML_RPC_COMM_DEV 를 주면 그것이 이긴다. TBDEV=0 이면 끔
DEV_A=""; DEV_B=""
if [ "${TBDEV:-1}" != 0 ]; then
  DEV_A=$(bash "$D/tools/bench/tbcommdev.sh")
  [ "$TOPO" = 2node ] && DEV_B=$(ssh $SSHO $B "bash -s" < "$D/tools/bench/tbcommdev.sh")
fi
# RAIL2=auto(기본, 2026-11-11): MTP 회이고 AR 장치가 정해졌으면(위 TBDEV) 클라이언트 연결의 장치를 AR 의 둘째 레일로 — 32 KB 이상 부분합
# (MTP 4토큰 검증의 40 KB AR)만 반씩 두 케이블로(GGML_RPC_COMM_RAIL2_ZC_MIN 기본 32768, 1토큰 10 KB 는 나누면 −1%), 두 서버 GGML_RDMA_RX_DEPTH=32.
# MTP 6쌍 57.71 vs 57.27(+0.8%, 4쌍 이김, AR 지연 A→B 42 → 33 µs), none 2쌍 −0.5% → MTP 에서만(RESULTS.md 2026-11-10 00:50, 2026-11-11 00:17).
# RAIL2=1 이면 none 에서도, 0 이면 끔. 두 노드 모두 장치가 있어야 켠다. SRV_ENV(_B) 가 이긴다.
R2_A=""; R2_B=""
if { [ "${RAIL2:-auto}" = 1 ] || { [ "${RAIL2:-auto}" = auto ] && [ "$SPEC" = mtp ]; }; } && [ "$TOPO" = 2node ] && [ -n "$DEV_A" ] && [ -n "$DEV_B" ]; then
  r2a=$(bash "$D/tools/bench/tbcommdev.sh" rail2); r2b=$(ssh $SSHO $B "bash -s rail2" < "$D/tools/bench/tbcommdev.sh")
  if [ -n "$r2a" ] && [ -n "$r2b" ]; then Z="GGML_RPC_COMM_RAIL2_ZC_MIN=${GGML_RPC_COMM_RAIL2_ZC_MIN:-32768} GGML_RDMA_RX_DEPTH=32"
    R2_A="GGML_RPC_COMM_RAIL2=$r2a $Z"; R2_B="GGML_RPC_COMM_RAIL2=$r2b $Z"; fi
fi
echo "A ${A_WRAP:-$PIN_A} | B ${B_WRAP:-$PIN_B} | client ${CLI_WRAP:-$PIN_A} | AR dev A ${DEV_A:--} B ${DEV_B:--} | rail2 A ${R2_A:--} B ${R2_B:--}" > "$OUT/pin.txt"
# 추론 감시(tools/watch/inferwatch.sh)용 기록 링: 서버 GGML_RPC_TRACE, 클라이언트 GGML_RPC_TRACE_CLIENT. TRACE=0 이면 끔
TRACE_SRV=""; TRACE_CLI=""
if [ "${TRACE:-1}" != 0 ]; then TRACE_SRV="GGML_RPC_TRACE=/dev/shm/ggml-rpc-trace-{port}.bin"; TRACE_CLI="GGML_RPC_TRACE_CLIENT=/dev/shm/ggml-rpc-trace-client.bin"; fi
ARGS=(-m "$M" -ngl 99 -fa on -c 8192 -np 1 --port $PORT --host 127.0.0.1 ${SRV_EXTRA:-})
[ "$SPEC" = mtp ] && ARGS+=(-md "$MTP" --spec-type draft-mtp -ngld 99 ${SPEC_EXTRA:-})
if [ "$TOPO" = 2node ]; then
  env ${DEV_A:+GGML_RPC_COMM_DEV=$DEV_A} $R2_A $SRV_ENV $TRACE_SRV nohup ${A_WRAP:-$PIN_A} "$BIN/ggml-rpc-server" -H 127.0.0.1 -p 50052 > "$OUT/rpc-a.log" 2>&1 & echo $! >> "$OUT/pids"
  ssh $SSHO $B "mkdir -p $BBIN; pkill -x ggml-rpc-server; sleep 1"; scp -q -o ConnectTimeout=10 "$BIN/ggml-rpc-server" "$B:$BBIN/" || exit 3
  ssh $SSHO $B "cd $BBIN && LD_LIBRARY_PATH=/opt/rocm/lib GGML_RDMA_RX_DEPTH=$GGML_RDMA_RX_DEPTH GGML_RDMA_CHUNK=$GGML_RDMA_CHUNK GGML_RDMA_TX_SLOTS=$GGML_RDMA_TX_SLOTS GGML_RPC_COMM_OVERLAP=$GGML_RPC_COMM_OVERLAP ${DEV_B:+GGML_RPC_COMM_DEV=$DEV_B} $R2_B ${SRV_ENV_B-$SRV_ENV} $TRACE_SRV ${B_WRAP:-$PIN_B} setsid -f ./ggml-rpc-server -H 10.99.0.2 -p 50052 -c > rpc-server.log 2>&1 < /dev/null"
  ARGS+=(--rpc 10.99.0.2:50052,127.0.0.1:50052 -sm tensor -dev RPC0,RPC1)
  sleep 3
fi
# A_WRAP / B_WRAP: A·B rpc-server 앞에 붙일 명령, CLI_WRAP: 클라이언트 앞 명령(예: "taskset -c 0-1,7-30"). 비면 위 TBPIN 고정
env ${CLI_ENV:-} $TRACE_CLI nohup ${CLI_WRAP:-$PIN_A} "$BIN/llama-server" "${ARGS[@]}" > "$OUT/server.log" 2>&1 & echo $! >> "$OUT/pids"
for i in $(seq 600); do curl -sf http://127.0.0.1:$PORT/health > /dev/null && break; sleep 1; done
curl -sf http://127.0.0.1:$PORT/health > /dev/null || { echo "server not ready"; tail -20 "$OUT/server.log"; }
PS=${PROBE_S:-80}
python3 -I $D/tools/probe/gpumetrics_ts.py $PS > "$OUT/gm-a.txt" 2>&1 &
APID=$(pgrep -x ggml-rpc-server | head -1); top -H -b -d 2 -n $((PS/2)) -p $APID > "$OUT/thr-a.txt" 2>&1 &
ssh $SSHO $B "cd $BBIN; (python3 -I gpumetrics_ts.py $PS > gm-b.txt 2>&1 &); top -H -b -d 2 -n $((PS/2)) -p \$(pgrep -x ggml-rpc-server) > thr-b.txt 2>&1 &" &
# BENCH: 벤치 대신 돌릴 클라이언트("<저장소 안 스크립트> <서버 URL 뒤 인자들>", 인자는 절대 경로 — 이 스크립트는 다른 곳에서 돈다),
#   예: BENCH="tools/draft_vocab_corpus.py $D/eval/draft_vocab_prompts.json 384 $D/fixcost/x/corpus-tokens.jsonl". {OUT} 은 이 실행의 폴더
# BENCH_S: 벤치(클라이언트) 시간 제한 초(기본 3600). 넘으면 멈추고 stop.txt 에 남긴다
BENCH_S=${BENCH_S:-3600}
if [ -n "${BENCH:-}" ]; then
  BENCH=${BENCH//\{OUT\}/$OUT}
  timeout -k 30 $BENCH_S python3 -I "$D/${BENCH%% *}" http://127.0.0.1:$PORT ${BENCH#* } | tee "$OUT/bench.txt"
else
  timeout -k 30 $BENCH_S python3 -I "$D/tools/spec_bench.py" http://127.0.0.1:$PORT "$D/eval/spec_prompts.json" "$NMAX" "$OUT/results.jsonl" | tee "$OUT/bench.txt"
fi
[ "${PIPESTATUS[0]}" = 124 ] && echo "$(date +%T) bench did not finish in ${BENCH_S}s -> stopped" | tee -a "$OUT/stop.txt"
grep -iE 'draft|mtp|spec' "$OUT/server.log" | grep -v '^\s*$' | head -6
# llama-server 를 먼저 내리고(끝날 때 RPC 서버에 메모리를 묻는다) 그다음 RPC 서버
# stop_pid <pid> [sent]: TERM 뒤 STOP_S 초(기본 60) 안에 안 끝나면 KILL 하고 stop.txt 에 남긴다. rocprofv3 로 감싼 llama-server(CW_/CLI_WRAP)는
# SIGTERM 에 기록을 다 쓴 뒤 rocprofv3 와 llama-server 의 신호 처리기가 서로를 부르며 끝나지 않는다 — 2026-11-10 밤 이 기다림에서 7시간 멈춤.
# prof2node.sh 와 같은 처리(기록은 TERM 때 이미 써져 있어 KILL 해도 잃지 않음)
stop_pid() {
  local p=$1 i
  [ "${2:-}" = sent ] || kill $p 2>/dev/null
  for i in $(seq ${STOP_S:-60}); do kill -0 $p 2>/dev/null || return 0; sleep 1; done
  echo "$(date +%T) pid $p ($(ps -o comm= -p $p 2>/dev/null)) did not exit ${STOP_S:-60}s after TERM -> KILL" | tee -a "$OUT/stop.txt"
  kill -KILL $p 2>/dev/null
  for i in $(seq 20); do kill -0 $p 2>/dev/null || return 0; sleep 1; done
  echo "$(date +%T) pid $p still alive 20s after KILL" | tee -a "$OUT/stop.txt"; return 1
}
SP=$(tail -1 "$OUT/pids"); stop_pid $SP
xargs -r kill < "$OUT/pids" 2>/dev/null
# 다음 실행이 메모리 부족을 겪지 않게, 프로세스가 끝나 GPU 메모리를 돌려줄 때까지 기다린다(위와 같은 시간 제한)
for p in $(cat "$OUT/pids"); do stop_pid $p sent; done; sleep 3
[ "$TOPO" = 2node ] && { sleep 2; scp -q -o ConnectTimeout=10 $B:$BBIN/gm-b.txt $B:$BBIN/thr-b.txt "$OUT/"; r=$(ssh $SSHO $B "pkill -x ggml-rpc-server; for i in \$(seq 30); do pgrep -x ggml-rpc-server > /dev/null || exit 0; sleep 1; done; pkill -KILL -x ggml-rpc-server; echo B rpc-server did not exit 30s after TERM -> KILL"); [ -n "$r" ] && echo "$(date +%T) $r" | tee -a "$OUT/stop.txt"; }
echo "$OUT"
