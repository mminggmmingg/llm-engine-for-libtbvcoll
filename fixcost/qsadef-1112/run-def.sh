#!/usr/bin/env bash
# 11-12 10:2x: 사용자 결정 "QSA 건너뛰기 기본으로 켜고 새 기준으로 해" — LLAMA_QSA_SHORT=1 이 기본인 빌드를 환경 없이(def) 돌려 새 기준 해시(모드별)와 감시기,
# 그리고 같은 빌드에서 LLAMA_QSA_SHORT=0(off)이 이전 기준(11-08)을 그대로 내는지(진단, 감시기 없음)
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/qsadef-1112
export BENCH_S=600 WATCH=1
OUTDIR=qsadef-1112 RUNS="mtp:def none:def" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1tr $O/srv-2node-*-def*-bench.txt)
IW=/data/parksThink/inferwatch-iw-20261110-1/target/release/inferwatch
for s in $(grep -o "| 2026111[0-9]-[0-9]* |" $(ls -1t $O/watch-summary-*.md | head -1) | tr -d "| "); do
  echo "== $s"; timeout 300 $IW critical-path $R/runs/watch/$s > $O/cp-$s.json 2>/dev/null
  python3 -I -c "import json; d=json.load(open('$O/cp-$s.json')); print(round(d['latency_ns_per_step']/1e6,3), 'ms/step;', ', '.join(f\"{i['category']} {i['ns_per_step']/1e6:.2f}\" for i in d['items'][:8]))"
  python3 -I /tmp/claude-1000/-data-parksThink-macos-reversing-claude-code/643ce5c3-138e-406c-bfc6-676a2e96b284/scratchpad/arcompute.py $R/runs/watch/$s 96 2>/dev/null | tail -1
done
echo DEFDONE
export BENCH_S=600 WATCH=0 CL_off="LLAMA_QSA_SHORT=0"
OUTDIR=qsadef-1112 RUNS="none:off" bash $R/tools/bench/node-ab.sh
HASHREF=1108 python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1tr $O/srv-2node-*-off*-bench.txt)
echo ALLDONE
