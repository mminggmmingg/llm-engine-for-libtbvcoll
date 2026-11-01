#!/usr/bin/env bash
# 묶은 hc mix 켬/끔, 2노드 H5: MTP 없음 ABBA + MTP ABBA, 매회 두 노드 gpu_metrics
S=/tmp/claude-1000/-data-parksThink-macos-reversing-claude-code/643ce5c3-138e-406c-bfc6-676a2e96b284/scratchpad/pf; cd $S
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; OUT=$R/fixcost/gdn-direct-1031; mkdir -p $OUT
export BIN=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp/build-rocm3/bin
export MODEL=/data/parksThink/hf-models/qwen38-flash-next-gguf/UD-IQ4_XS-dense4/Qwen3.8-Flash-Next-Q8mix-q8mix-H5.gguf SPEC_EXTRA="-devd ROCm0"
for run in ${RUNS:-mtp:on mtp:off mtp:off mtp:on}; do
  spec=${run%:*}; cfg=${run#*:}
  if [ $cfg = off ]; then SE="GGML_CUDA_DISABLE_GRAPHS=1 GGML_CUDA_NO_GDN_DIRECT=1"; CE="GGML_CUDA_NO_GDN_DIRECT=1"; else SE="GGML_CUDA_DISABLE_GRAPHS=1"; CE=""; fi
  for i in $(seq 60); do b=$(timeout 10 ssh -o BatchMode=yes parks-zbook@10.99.0.2 "cut -d' ' -f1 /proc/loadavg"); a=$(cut -d' ' -f1 /proc/loadavg); awk "BEGIN{exit !($a<0.6 && $b<0.6)}" && break; sleep 5; done
  out=$(SRV_ENV="$SE" CLI_ENV="$CE" TAG=gdnd-$cfg bash srv-probe.sh 2node $spec 2>&1); d=$(echo "$out" | tail -1); n=$(basename $d)
  for f in gm-a gm-b bench; do cp $d/$f.txt $OUT/$n-$f.txt 2>/dev/null; done
  echo "$spec $cfg load A=$a B=$b: $(echo "$out" | grep TOTAL) | $n"
  for x in a b; do echo "   $x: $(python3 -I gmsum.py $d/gm-$x.txt)"; done
done
