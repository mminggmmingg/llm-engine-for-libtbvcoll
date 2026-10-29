#!/usr/bin/env bash
# 배분 하나 전체 측정: 변환(run_variant.sh) → 1노드 tg128 을 UD-IQ4_XS 와 번갈아 ×2 → llama-server 1노드·2노드 × MTP 없음/있음(UD 도 같이)
#   quant/run_mix_suite.sh <types 파일> <태그>      (Q8_0 원본, imatrix-orig, 32 스레드)
set -uo pipefail
D=$(cd "$(dirname "$0")/.." && pwd); TYPES=$1 TAG=$2; cd "$D"
G=/data/parksThink/hf-models/qwen38-flash-next-gguf; export LD_LIBRARY_PATH=/opt/rocm/lib
UD=$G/UD-IQ4_XS/Qwen3.8-Flash-Next-UD-IQ4_XS-00001-of-00003.gguf; M=$G/UD-IQ4_XS-dense4/Qwen3.8-Flash-Next-Q8mix-$TAG.gguf
SRC=$G/Q8_0/Qwen3.8-Flash-Next-Q8_0-00001-of-00006.gguf NAME=Qwen3.8-Flash-Next-Q8mix IMATRIX=quant/imatrix-orig.gguf THREADS=32 \
  quant/run_variant.sh "$TYPES" "$TAG" || exit 1
for m in UD $TAG UD $TAG; do f=$UD; [ $m = UD ] || f=$M
  echo "$(date +%T) $m $(llama.cpp/build-rocm/bin/llama-bench -m $f -ngl 99 -fa on -p 0 -n 128 -r 5 -o md 2>/dev/null | grep tg128 | awk -F'|' '{print $(NF-1)}')"
done | tee "quant/ab-UD-$TAG.log"
for topo in 1node 2node; do
  [ $topo = 2node ] && ssh -o BatchMode=yes parks-zbook@10.99.0.2 'echo "B: $(uptime)"; pgrep -a "llama|rpc-server|ib_" | grep -v kworker'
  for spec in none mtp; do for m in UD $TAG; do f=$UD; [ $m = UD ] || f=$M
    echo "=== $(date +%T) $topo $spec $m"
    MODEL=$f TAG=$m SPEC_EXTRA="-devd ROCm0" ./run_server.sh $topo $spec 2>&1 | grep -E 'TOTAL|runs/|not ready|rror'
  done; done
done
