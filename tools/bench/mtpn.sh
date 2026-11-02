#!/usr/bin/env bash
# MTP 초안 길이(--spec-draft-n-max) 쓸기, 2노드 H5: RUNS="3 2 4 ..." — 회마다 tok/s, 수락률, 단계당 받아들인 토큰, 두 노드 gpu_metrics·prof
S=/tmp/claude-1000/-data-parksThink-macos-reversing-claude-code/643ce5c3-138e-406c-bfc6-676a2e96b284/scratchpad/pf; cd $S
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; OUT=$R/fixcost/${OUTDIR:-mtp-ndraft-1102}; mkdir -p $OUT
export BIN=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp/build-rocm3/bin
export MODEL=/data/parksThink/hf-models/qwen38-flash-next-gguf/UD-IQ4_XS-dense4/Qwen3.8-Flash-Next-Q8mix-q8mix-H5.gguf
BASE="GGML_CUDA_DISABLE_GRAPHS=1 GGML_RPC_COMM_PROF=1000"
echo "== $(date +%T) $($R/tools/tbv_hotpoll.sh status | tr '\n' ' ')"
for n in ${RUNS:?}; do
  for i in $(seq 60); do b=$(timeout 10 ssh -o BatchMode=yes parks-zbook@10.99.0.2 "cut -d' ' -f1 /proc/loadavg"); a=$(cut -d' ' -f1 /proc/loadavg); awk "BEGIN{exit !($a<0.6 && $b<0.6)}" && break; sleep 5; done
  out=$(SPEC_EXTRA="-devd ROCm0 --spec-draft-n-max $n ${XSPEC:-}" SRV_ENV="$BASE" SRV_ENV_B="$BASE" TAG=nd$n${PTAG:-} bash srv-probe.sh 2node mtp 2>&1); d=$(echo "$out" | tail -1); nm=$(basename $d)
  for x in gm-a gm-b bench; do cp $d/$x.txt $OUT/$nm-$x.txt 2>/dev/null; done; cp $d/results.jsonl $OUT/$nm-results.jsonl 2>/dev/null
  scp -q parks-zbook@10.99.0.2:/home/parks-zbook/engine2n/bin/rpc-server.log $d/rpc-b.log; grep comm_prof $d/rpc-a.log > $OUT/$nm-prof-a.txt; grep comm_prof $d/rpc-b.log > $OUT/$nm-prof-b.txt
  acc=$(python3 -I -c "
import json
dn=da=n=0
for l in open('$d/results.jsonl'):
    j=json.loads(l); dn+=j.get('draft_n') or 0; da+=j.get('draft_acc') or 0; n+=j['n']
steps=max(1, n-da)  # 단계마다 목표 모델이 1개를 직접 내고 받아들인 초안을 더한다
print(f'drafted {dn} accepted {da} ({100*da/max(1,dn):.0f}%) tokens/step {n/steps:.2f}')" 2>/dev/null)
  echo "n=$n${PTAG:-} rdma=$(grep -c "RDMA activated" $d/rpc-a.log): $(echo "$out" | grep TOTAL) | $acc | $nm"
  for x in a b; do echo "   $x: $(python3 -I gmsum.py $d/gm-$x.txt | cut -d'|' -f1)"; done
  echo "   cyc: $(python3 -I profsum.py $OUT/$nm-prof-a.txt | grep -o 'cycle *[0-9.]*')"
done
echo "== done $(date +%T)"
