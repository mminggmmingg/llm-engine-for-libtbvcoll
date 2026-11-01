#!/usr/bin/env bash
# TP FFN 분할 비율(B 몫) 쓸기, 2노드 H5: RUNS="none:0.5 none:0.4 ..." 매회 두 노드 gpu_metrics, RDMA 확인
S=/tmp/claude-1000/-data-parksThink-macos-reversing-claude-code/643ce5c3-138e-406c-bfc6-676a2e96b284/scratchpad/pf; cd $S
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; OUT=$R/fixcost/zc-allreduce-1101; mkdir -p $OUT
export BIN=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp/build-rocm3/bin
export MODEL=/data/parksThink/hf-models/qwen38-flash-next-gguf/UD-IQ4_XS-dense4/Qwen3.8-Flash-Next-Q8mix-q8mix-H5.gguf SPEC_EXTRA="-devd ROCm0"
for run in ${RUNS:?}; do
  spec=${run%:*}; cfg=${run#*:}; f=0.5; case $cfg in off) ZC= ;; on|zc2) ZC=GGML_RPC_COMM_ZC=2 ;; zc1) ZC=GGML_RPC_COMM_ZC=1 ;; zc2s) ZC="GGML_RPC_COMM_ZC=2 GGML_RPC_SPIN_US=20" ;; tl) ZC="GGML_RPC_COMM_PROF_TL=tl-node.txt" ;; tlzc1) ZC="GGML_RPC_COMM_ZC=1 GGML_RPC_COMM_PROF_TL=tl-node.txt" ;; esac
  for i in $(seq 60); do b=$(timeout 10 ssh -o BatchMode=yes parks-zbook@10.99.0.2 "cut -d' ' -f1 /proc/loadavg"); a=$(cut -d' ' -f1 /proc/loadavg); awk "BEGIN{exit !($a<0.6 && $b<0.6)}" && break; sleep 5; done
  out=$(SRV_ENV="GGML_CUDA_DISABLE_GRAPHS=1 GGML_RPC_COMM_PROF=1000 $ZC" CLI_ENV="LLAMA_TP_FFN_SPLIT=$f LLAMA_TP_SPLIT_DEBUG=1 ${XENV:-}" TAG=zc-$cfg bash srv-probe.sh 2node $spec 2>&1); d=$(echo "$out" | tail -1); n=$(basename $d)
  for x in gm-a gm-b bench; do cp $d/$x.txt $OUT/$n-$x.txt 2>/dev/null; done
  scp -q parks-zbook@10.99.0.2:/home/parks-zbook/engine2n/bin/rpc-server.log $d/rpc-b.log; true && { grep comm_prof $d/rpc-a.log > $OUT/$n-prof-a.txt; grep comm_prof $d/rpc-b.log > $OUT/$n-prof-b.txt; }
  grep "tp split" $d/server.log | grep -E "blk\.[0-3]\.ffn_(up|gate|down)(_exps|_shexp)?\.weight|blk\.[0-3]\.ffn_gate_up" | head -12 > $OUT/$n-split.txt
  echo "$spec $cfg load A=$a B=$b rdma=$(grep -c "RDMA activated" $d/rpc-a.log) zc=$(grep -c zero-copy $d/rpc-a.log)/$(grep -c zero-copy $d/rpc-b.log): $(echo "$out" | grep TOTAL) | $n"
  for x in a b; do echo "   $x: $(python3 -I gmsum.py $d/gm-$x.txt)"; done
done
