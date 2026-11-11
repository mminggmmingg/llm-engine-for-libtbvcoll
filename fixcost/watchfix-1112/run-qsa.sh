#!/usr/bin/env bash
# 11-12 02:5x: 감시기 critical path 로 찾은 것 — 전체 attention(QSA) 층이 GDN 층보다 단계마다 ≈140 µs 김. KV 가 top-k 예산(2048칸) 안이면 인덱서가 모든 블록을 고르므로
# LLAMA_QSA_SHORT=1: 인덱서 점수 대신 pool_mask 로 같은 마스크를 만듦(인덱서 q 사영·norm/rope·풀 키 모으기·인덱서 커널 생략, 캐시 쓰기는 그대로).
# (1) 해시 관문 MTP·none(진단, 감시기 없음) → (2) 번갈아 끔/켬 MTP 3쌍 + none 1쌍 + 감시기, 해시
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/watchfix-1112
export BENCH_S=900 WATCH=0 CL_qg="LLAMA_QSA_SHORT=1"
OUTDIR=watchfix-1112 RUNS="mtp:qg none:qg" bash $R/tools/bench/node-ab.sh
H=$(python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -2)); echo "$H"
ok=$(echo "$H" | grep -c "6/6 same"); echo "gate: $ok of 2 runs 6/6"
if [ "$ok" != 2 ]; then echo "GATE FAILED — no A/B"; echo ALLDONE; exit 0; fi
echo GATEOK
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
