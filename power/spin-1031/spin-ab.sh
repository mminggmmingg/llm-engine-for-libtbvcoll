#!/usr/bin/env bash
# rpc-server 바쁜 대기 줄이기: 4설정 × 2회(ABCD DCBA), 2노드 H5 MTP 없음, 매회 두 노드 gpu_metrics·스레드 기록
S=/tmp/claude-1000/-data-parksThink-macos-reversing-claude-code/643ce5c3-138e-406c-bfc6-676a2e96b284/scratchpad/pf; cd $S
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; OUT=$R/power/spin-1031; mkdir -p $OUT
export BIN=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp/build-rocm3/bin MODEL=/data/parksThink/hf-models/qwen38-flash-next-gguf/UD-IQ4_XS-dense4/Qwen3.8-Flash-Next-Q8mix-q8mix-H5.gguf
declare -A ENVS=([base]="GGML_CUDA_DISABLE_GRAPHS=1" [spin]="GGML_CUDA_DISABLE_GRAPHS=1 GGML_RPC_SPIN_US=20"
                 [block]="GGML_CUDA_DISABLE_GRAPHS=1 GGML_CUDA_BLOCKING_SYNC=1" [both]="GGML_CUDA_DISABLE_GRAPHS=1 GGML_RPC_SPIN_US=20 GGML_CUDA_BLOCKING_SYNC=1")
for cfg in ${ORDER:-base both spin block block spin both base}; do
  for i in $(seq 60); do b=$(timeout 10 ssh -o BatchMode=yes parks-zbook@10.99.0.2 "cut -d' ' -f1 /proc/loadavg"); a=$(cut -d' ' -f1 /proc/loadavg); awk "BEGIN{exit !($a<0.6 && $b<0.6)}" && break; sleep 5; done
  out=$(SRV_ENV="${ENVS[$cfg]}" TAG=spin-$cfg bash srv-probe.sh 2node none 2>&1); d=$(echo "$out" | tail -1); n=$(basename $d)
  for f in gm-a gm-b thr-a thr-b bench; do cp $d/$f.txt $OUT/$n-$f.txt 2>/dev/null; done; cp $d/rpc-a.log $OUT/$n-rpc-a.log
  echo "$cfg load A=$a B=$b: $(echo "$out" | grep TOTAL) | $n"
  for x in a b; do echo "   $x: $(python3 -I gmsum.py $d/gm-$x.txt)"; done
  for x in a b; do echo "   thr-$x: $(awk '/^ *[0-9]+ /{k=$1" "$12; s[k]+=$9; c[k]++} END{for(k in s) if (s[k]/c[k] > 3) printf "%s %.0f%%, ", k, s[k]/c[k]}' $d/thr-$x.txt)"; done
done
