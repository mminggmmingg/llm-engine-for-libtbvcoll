#!/usr/bin/env bash
# 11-12 13:5x: MTP 에서는 GDN·PLE conv 상태를 되돌리기 칸(n_rs_seq+1)마다 저장해서 상태 꼬리 묶음이 여러 번 → PLE conv 융합이 MTP 에서 0회였음(FUSE_COUNT, stops #9).
# 여러 칸을 받게 고친 빌드: (1) 해시 관문 + 융합 횟수(진단) → (2) MTP 번갈아 끔/켬 3쌍 + 감시기
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/fuse-1112
export BENCH_S=600 WATCH=0 SA_fg2="GGML_CUDA_FUSE_COUNT=1" SB_fg2="GGML_CUDA_FUSE_COUNT=1"
OUTDIR=fuse-1112 RUNS="mtp:fg2 none:fg2" bash $R/tools/bench/node-ab.sh
H=$(python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-fg2-*-bench.txt | head -2)); echo "$H"
for d in $(ls -1dtr $R/runs/srv-2node-*-fg2-* | tail -2); do echo "== $d"; grep "e2n fuse" $d/rpc-a.log | tail -4; done
ok=$(echo "$H" | grep -c "6/6 same"); echo "gate: $ok of 2 runs 6/6"
if [ "$ok" != 2 ]; then echo "GATE FAILED — no A/B"; echo ALLDONE; exit 0; fi
echo GATEOK
OFF="GGML_CUDA_NO_PLE_FUSE=1 GGML_CUDA_NO_QSA_MASK_FUSE=1"
export BENCH_S=600 WATCH=1 SA_g0="$OFF" SB_g0="$OFF"
OUTDIR=fuse-1112 RUNS="mtp:g0 mtp:g1 mtp:g0 mtp:g1 mtp:g0 mtp:g1" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1tr $O/srv-2node-*-g[01]*-bench.txt)
IW=/data/parksThink/inferwatch-iw-20261110-1/target/release/inferwatch
for s in $(grep -o "| 2026111[0-9]-[0-9]* |" $(ls -1t $O/watch-summary-*.md | head -1) | tr -d "| "); do
  echo "== $s"; timeout 300 $IW critical-path $R/runs/watch/$s > $O/cp-$s.json 2>/dev/null
  python3 -I -c "import json; d=json.load(open('$O/cp-$s.json')); print(round(d['latency_ns_per_step']/1e6,3), 'ms/step;', ', '.join(f\"{i['category']} {i['ns_per_step']/1e6:.2f}\" for i in d['items'][:8]))"
  python3 -I /tmp/claude-1000/-data-parksThink-macos-reversing-claude-code/643ce5c3-138e-406c-bfc6-676a2e96b284/scratchpad/arcompute.py $R/runs/watch/$s 96 2>/dev/null | tail -1
done
echo ALLDONE
