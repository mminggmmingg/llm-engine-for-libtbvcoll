#!/usr/bin/env bash
# 11-12 00:3x: 재사용 셋째 판(슬롯이 바뀌기 전 내용 하나를 더 기억 — 다음 프롬프트의 첫 decode 가 앞 decode 모양을 다시 씀).
# (1) 바이트 비교 검증 MTP·none(감시기 없음, 진단), (2) 번갈아: 재사용 끔/켬 MTP 3쌍 + none 1쌍 + 감시기, 해시
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/rebuild-1111
export BENCH_S=900 WATCH=0 CL_rv3="GGML_META_REUSE=1 GGML_META_REUSE_VERIFY=1 GGML_META_CACHE_STATS=1"
OUTDIR=rebuild-1111 RUNS="mtp:rv3 none:rv3" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -2)
for d in $(ls -td $R/runs/srv-2node-*-bs-rv3-1* | head -2); do echo "== $d"; grep -E "simple tensors reused" $d/server.log | tail -1 | cut -c1-200; echo "verify mismatch lines: $(grep -c 'VERIFY reused' $d/server.log)"; grep 'VERIFY reused' $d/server.log | head -3; done
echo VERIFYDONE
export BENCH_S=600 WATCH=1 CL_u0="GGML_META_REUSE=0" CL_u1="GGML_META_REUSE=1"
OUTDIR=rebuild-1111 RUNS="mtp:u0 mtp:u1 mtp:u0 mtp:u1 mtp:u0 mtp:u1 none:u0 none:u1" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -12)
for s in $(grep -o "| 2026111[0-9]-[0-9]* |" $(ls -1t $O/watch-summary-*.md | head -1) | tr -d "| "); do python3 $R/tools/bench/rebuilds.py $R/runs/watch/$s; python3 -I /tmp/claude-1000/-data-parksThink-macos-reversing-claude-code/643ce5c3-138e-406c-bfc6-676a2e96b284/scratchpad/afterrb.py $R/runs/watch/$s | grep -E "k=0|k=9"; done
echo ALLDONE
