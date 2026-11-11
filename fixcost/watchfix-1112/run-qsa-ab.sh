#!/usr/bin/env bash
# 11-12 04:0x: LLAMA_QSA_SHORT=1 — 마스크는 원래와 같음(덤프 732개), 출력은 그래프 모양 민감성 때문에 바뀜(쓰지 않는 노드 하나로도 40층에서 1.5e-3, 확인).
# (1) 갈리는 자리의 1·2위 로그확률(tools/divergence.py, none, 진단) (2) 속도 번갈아 MTP 3쌍 + none 1쌍 + 감시기
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/watchfix-1112
export BENCH_S=900 WATCH=0 CL_d0="LLAMA_QSA_SHORT=0" CL_d1="LLAMA_QSA_SHORT=1"
BENCH="tools/divergence.py eval/spec_prompts.json 256 $O/div-q0.jsonl" OUTDIR=watchfix-1112 RUNS="none:d0" bash $R/tools/bench/node-ab.sh
BENCH="tools/divergence.py eval/spec_prompts.json 256 $O/div-q1.jsonl" OUTDIR=watchfix-1112 RUNS="none:d1" bash $R/tools/bench/node-ab.sh
python3 -I $R/tools/divergence.py diff $O/div-q0.jsonl $O/div-q1.jsonl
echo DIVDONE
export BENCH_S=600 WATCH=1 CL_q0="LLAMA_QSA_SHORT=0" CL_q1="LLAMA_QSA_SHORT=1"
OUTDIR=watchfix-1112 RUNS="mtp:q0 mtp:q1 mtp:q0 mtp:q1 mtp:q0 mtp:q1 none:q0 none:q1" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -12)
IW=/data/parksThink/inferwatch-iw-20261110-1/target/release/inferwatch
for s in $(grep -o "| 2026111[0-9]-[0-9]* |" $(ls -1t $O/watch-summary-*.md | head -1) | tr -d "| "); do
  echo "== $s"; timeout 300 $IW critical-path $R/runs/watch/$s > $O/cp-$s.json 2>/dev/null
  python3 -I -c "import json; d=json.load(open('$O/cp-$s.json')); print(round(d['latency_ns_per_step']/1e6,3), 'ms/step;', ', '.join(f\"{i['category']} {i['ns_per_step']/1e6:.2f}\" for i in d['items'][:8]))"
  python3 -I /tmp/claude-1000/-data-parksThink-macos-reversing-claude-code/643ce5c3-138e-406c-bfc6-676a2e96b284/scratchpad/arcompute.py $R/runs/watch/$s 96 2>/dev/null | tail -1
done
echo ALLDONE
