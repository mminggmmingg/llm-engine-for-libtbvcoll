#!/usr/bin/env bash
# 11-12 12:3x: 감시기로 찾은 것 — PLE(1층) 원소별 사슬 ≈31커널과 QSA 짧은 문맥 마스크(층마다 5커널, 12층 같은 값)를 서버 CUDA 쪽 노드 패턴 융합으로
# 커널 1134 → 1060/단계(그래프는 그대로). GGML_CUDA_NO_PLE_FUSE=1 / GGML_CUDA_NO_QSA_MASK_FUSE=1 로 끔.
# (1) 해시 관문 MTP·none(진단, 감시기 없음, 새 기준 hashchk) → (2) 번갈아 끔/켬 MTP 3쌍 + none 2쌍 + 감시기, 해시
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/fuse-1112
export BENCH_S=900 WATCH=0
OUTDIR=fuse-1112 RUNS="mtp:fg none:fg" bash $R/tools/bench/node-ab.sh
H=$(python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -2)); echo "$H"
ok=$(echo "$H" | grep -c "6/6 same"); echo "gate: $ok of 2 runs 6/6"
if [ "$ok" != 2 ]; then echo "GATE FAILED — no A/B"; echo ALLDONE; exit 0; fi
echo GATEOK
OFF="GGML_CUDA_NO_PLE_FUSE=1 GGML_CUDA_NO_QSA_MASK_FUSE=1"
export BENCH_S=600 WATCH=1 SA_f0="$OFF" SB_f0="$OFF"
OUTDIR=fuse-1112 RUNS="mtp:f0 mtp:f1 mtp:f0 mtp:f1 mtp:f0 mtp:f1 none:f0 none:f1 none:f0 none:f1" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1tr $O/srv-2node-*-f[01]*-bench.txt)
IW=/data/parksThink/inferwatch-iw-20261110-1/target/release/inferwatch
for s in $(grep -o "| 2026111[0-9]-[0-9]* |" $(ls -1t $O/watch-summary-*.md | head -1) | tr -d "| "); do
  echo "== $s"; timeout 300 $IW critical-path $R/runs/watch/$s > $O/cp-$s.json 2>/dev/null
  python3 -I -c "import json; d=json.load(open('$O/cp-$s.json')); print(round(d['latency_ns_per_step']/1e6,3), 'ms/step;', ', '.join(f\"{i['category']} {i['ns_per_step']/1e6:.2f}\" for i in d['items'][:8]))"
  python3 -I /tmp/claude-1000/-data-parksThink-macos-reversing-claude-code/643ce5c3-138e-406c-bfc6-676a2e96b284/scratchpad/arcompute.py $R/runs/watch/$s 96 2>/dev/null | tail -1
done
echo ALLDONE
