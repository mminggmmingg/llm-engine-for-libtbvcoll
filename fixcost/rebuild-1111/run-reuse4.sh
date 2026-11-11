#!/usr/bin/env bash
# 11-12 01:1x: 재사용 넷째 판(재사용 판단 전에 자기 분할 상태 갱신). (1) 검증 없이 재사용 MTP·none 해시 + (2) 바이트 비교 검증 MTP — 진단(감시기 없음).
# 둘 다 통과하면 (3) 번갈아: 재사용 끔/켬 MTP 3쌍 + none 1쌍 + 감시기, 해시
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/rebuild-1111
export BENCH_S=900 WATCH=0 CL_nv4="GGML_META_REUSE=1 GGML_META_CACHE_STATS=1" CL_rv4="GGML_META_REUSE=1 GGML_META_REUSE_VERIFY=1 GGML_META_CACHE_STATS=1"
OUTDIR=rebuild-1111 RUNS="mtp:nv4 none:nv4 mtp:rv4" bash $R/tools/bench/node-ab.sh
H=$(python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -3)); echo "$H"
for d in $(ls -td $R/runs/srv-2node-*-bs-[nr]v4-1* | head -3); do echo "== $d"; grep -E "simple tensors reused|keep\)" $d/server.log | tail -2 | cut -c1-200; echo "verify mismatch lines: $(grep -c 'VERIFY reused' $d/server.log)"; done
ok=$(echo "$H" | grep -c "6/6 same"); bad=$(grep -h -c 'VERIFY reused' $(ls -td $R/runs/srv-2node-mtp-bs-rv4-1* | head -1)/server.log)
echo "gate: $ok of 3 runs 6/6, verify mismatches $bad"
if [ "$ok" != 3 ] || [ "$bad" != 0 ]; then echo "GATE FAILED — no A/B"; echo ALLDONE; exit 0; fi
echo VERIFYDONE
export BENCH_S=600 WATCH=1 CL_u0="GGML_META_REUSE=0" CL_u1="GGML_META_REUSE=1"
OUTDIR=rebuild-1111 RUNS="mtp:u0 mtp:u1 mtp:u0 mtp:u1 mtp:u0 mtp:u1 none:u0 none:u1" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -12)
for s in $(grep -o "| 2026111[0-9]-[0-9]* |" $(ls -1t $O/watch-summary-*.md | head -1) | tr -d "| "); do python3 $R/tools/bench/rebuilds.py $R/runs/watch/$s; python3 -I /tmp/claude-1000/-data-parksThink-macos-reversing-claude-code/643ce5c3-138e-406c-bfc6-676a2e96b284/scratchpad/afterrb.py $R/runs/watch/$s | grep -E "k=0|k=9"; done
echo ALLDONE
