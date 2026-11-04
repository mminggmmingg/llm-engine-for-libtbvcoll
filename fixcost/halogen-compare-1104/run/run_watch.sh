#!/usr/bin/env bash
# halogen(A 단독)을 우리 관측 방식으로: 우리 엔진과 같은 6 프롬프트(chat, temperature 0)를 serial·mtp 로 보내며 GPU 사용률을 20 ms 마다 기록.
#   KTRACE=1 이면 flash_serve 를 rocprofv3 커널 기록 아래에서(GPU 시각) 돌리고 프롬프트·토큰을 줄인다(NP 프롬프트, NTOK 토큰).
# 기본 설정 그대로. HALOGEN_DOWNLOAD·HALOGEN_NPU_MODELS 없음, --privileged 없음. 아무것도 지우지 않는다.
set -uo pipefail
D=$(cd "$(dirname "$0")" && pwd)
IMG=ghcr.io/peonist-ai/halogen-flash-server:0.18.17
MODELS=/data/parksThink/hf-models/halogen-qwen3.8-flash-next
PROMPTS=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll/eval/spec_prompts.json
KTRACE=${KTRACE:-0}; NTOK=${NTOK:-256}; NP=${NP:-6}
TS=$(date +%Y%m%d-%H%M%S)
OUT=$D/../runs/watch-$([ $KTRACE = 1 ] && echo ktrace-)$TS; mkdir -p "$OUT"
NAME=halogen-watch-$TS
gtt() { cat /sys/class/drm/card*/device/mem_info_gtt_used 2>/dev/null | awk '{s+=$1} END {printf "%.2f", s/2^30}'; }
log() { echo "[run $(date +%T)] $*" | tee -a "$OUT/run.log"; }

if docker ps --format '{{.Names}}' | grep -q .; then log "다른 컨테이너가 돌고 있음 — 중단"; exit 2; fi
if pgrep -x ggml-rpc-server >/dev/null || pgrep -x llama-server >/dev/null; then log "우리 엔진이 돌고 있음 — 중단"; exit 2; fi
python3 -I -c "import json; p=json.load(open('$PROMPTS')); json.dump(p[:$NP], open('$OUT/prompts.json','w'), ensure_ascii=False)"
WRAP=(); [ $KTRACE = 1 ] && WRAP=(-e _hg_flash_serve=/hrun/fs_ktrace.sh -e HALOGEN_ENGINE_WATCHDOG_S=0
  -v /usr/lib/x86_64-linux-gnu/libatomic.so.1.2.0:/usr/lib/x86_64-linux-gnu/libatomic.so.1:ro)
log "이미지 $(docker image inspect -f '{{.Id}}' $IMG) KTRACE=$KTRACE NTOK=$NTOK NP=$NP GTT $(gtt) GiB"
t0=$(date +%s)
docker run -d --name "$NAME" -p 127.0.0.1:8731:8731 \
  --device /dev/kfd --device /dev/dri --group-add "$(getent group video | cut -d: -f3)" --group-add "$(getent group render | cut -d: -f3)" \
  --ipc=host --ulimit memlock=-1:-1 "${WRAP[@]}" \
  -v "$MODELS":/models:ro -v "$D":/hrun:ro -v "$OUT":/out \
  "$IMG" > "$OUT/container.id" 2>>"$OUT/run.log" || { log "docker run 실패"; exit 3; }
docker logs -f "$NAME" > "$OUT/container.log" 2>&1 &
LOGPID=$!
up=0
for _ in $(seq 1 480); do
  curl -sf http://127.0.0.1:8731/health >/dev/null && { up=1; break; }
  [ "$(docker inspect -f '{{.State.Running}}' "$NAME" 2>/dev/null)" = true ] || break
  sleep 5
done
if [ $up = 0 ]; then log "기동 실패"; tail -40 "$OUT/container.log" | tee -a "$OUT/run.log"
else
  log "READY $(( $(date +%s) - t0 ))s, GTT $(gtt) GiB"
  python3 -I "$D/hg_bench.py" http://127.0.0.1:8731 "$OUT/prompts.json" 8 serial > "$OUT/warmup.jsonl" 2>&1   # 첫 실행 준비 비용 흡수
  python3 -I "$D/gpu_fast.py" 1800 20 > "$OUT/gpu.txt" 2>&1 & GPID=$!
  for dr in serial mtp; do
    log "bench $dr"; echo "$(date +%s%N | cut -c1-19) $dr start" >> "$OUT/marks.txt"
    python3 -I "$D/hg_bench.py" http://127.0.0.1:8731 "$OUT/prompts.json" $NTOK $dr > "$OUT/bench-$dr.jsonl" 2>&1
    sleep 2
  done
  kill $GPID 2>/dev/null
fi
grep -E 'serve_api: \w+ [0-9]+ tok in' "$OUT/container.log" > "$OUT/ledger.txt"
if [ $KTRACE = 1 ]; then
  log "flash_serve 에 TERM(추적 기록 flush)"
  docker exec "$NAME" bash -c 'for p in /proc/[0-9]*; do [ "$(cat $p/comm 2>/dev/null)" = flash_serve ] && kill -TERM ${p#/proc/}; done'
  for _ in $(seq 1 120); do [ "$(docker inspect -f '{{.State.Running}}' "$NAME")" = true ] || break
    n=$(find "$OUT/prof" -name '*kernel_trace.csv' 2>/dev/null | head -1); [ -n "$n" ] && sleep 20 && break; sleep 5; done
fi
log "정지"; docker stop -t 120 "$NAME" >/dev/null; sleep 2; kill $LOGPID 2>/dev/null
log "정지 후 GTT $(gtt) GiB"
find "$OUT/prof" -type f -printf '%s\t%p\n' 2>/dev/null | sort -k2 | tee -a "$OUT/run.log"
log "RUN_DONE $OUT"
