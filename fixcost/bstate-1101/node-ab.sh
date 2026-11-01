#!/usr/bin/env bash
# 노드별 서버 환경 A/B, 2노드 H5: RUNS="none:<cfg> ..." — cfg 마다 A 환경(SA)·B 환경(SB). 회마다 두 노드 gpu_metrics·스레드·prof
S=/tmp/claude-1000/-data-parksThink-macos-reversing-claude-code/643ce5c3-138e-406c-bfc6-676a2e96b284/scratchpad/pf; cd $S
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; OUT=$R/fixcost/bstate-1101; mkdir -p $OUT
export BIN=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp/build-rocm3/bin
export MODEL=/data/parksThink/hf-models/qwen38-flash-next-gguf/UD-IQ4_XS-dense4/Qwen3.8-Flash-Next-Q8mix-q8mix-H5.gguf SPEC_EXTRA="-devd ROCm0"
BASE="GGML_CUDA_DISABLE_GRAPHS=1 GGML_RPC_COMM_PROF=1000"
for run in ${RUNS:?}; do
  spec=${run%:*}; cfg=${run#*:}
  case $cfg in
    base)    SA="";                                   SB="" ;;
    b2s)     SA="";                                   SB="GGML_RPC_COMM_ZC=2 GGML_RPC_SPIN_US=20" ;;
    b2)      SA="";                                   SB="GGML_RPC_COMM_ZC=2" ;;
    b1s)     SA="";                                   SB="GGML_RPC_SPIN_US=20" ;;
    ab2s)    SA="GGML_RPC_COMM_ZC=2 GGML_RPC_SPIN_US=20"; SB="GGML_RPC_COMM_ZC=2 GGML_RPC_SPIN_US=20" ;;
    *) SA=$(eval echo \${SA_$cfg}); SB=$(eval echo \${SB_$cfg}) ;;
  esac
  for i in $(seq 60); do b=$(timeout 10 ssh -o BatchMode=yes parks-zbook@10.99.0.2 "cut -d' ' -f1 /proc/loadavg"); a=$(cut -d' ' -f1 /proc/loadavg); awk "BEGIN{exit !($a<0.6 && $b<0.6)}" && break; sleep 5; done
  out=$(SRV_ENV="$BASE $SA" SRV_ENV_B="$BASE $SB" TAG=bs-$cfg bash srv-probe.sh 2node $spec 2>&1); d=$(echo "$out" | tail -1); n=$(basename $d)
  for x in gm-a gm-b bench thr-a thr-b; do cp $d/$x.txt $OUT/$n-$x.txt 2>/dev/null; done
  scp -q parks-zbook@10.99.0.2:/home/parks-zbook/engine2n/bin/rpc-server.log $d/rpc-b.log; grep comm_prof $d/rpc-a.log > $OUT/$n-prof-a.txt; grep comm_prof $d/rpc-b.log > $OUT/$n-prof-b.txt
  echo "$spec $cfg load A=$a B=$b rdma=$(grep -c "RDMA activated" $d/rpc-a.log) zc=$(grep -o 'ZC=[0-9]' $d/rpc-a.log | head -1)/$(grep -o 'ZC=[0-9]' $d/rpc-b.log | head -1): $(echo "$out" | grep TOTAL) | $n"
  for x in a b; do echo "   $x: $(python3 -I gmsum.py $d/gm-$x.txt | cut -d'|' -f1)"; done
  echo "   cyc: $(python3 -I profsum.py $OUT/$n-prof-a.txt | grep -o 'cycle *[0-9.]*')"
done
