#!/usr/bin/env bash
# 11-11 23:3x: 메타 단순 텐서 재사용(GGML_META_REUSE=1) — 먼저 검증 회(VERIFY: 재사용할 때마다 원래 방식으로도 만들어 바이트 비교) MTP·none, 감시기 없음(진단).
# 그다음 시간 회(재사용 vs 기본, GGML_META_TIME·LLAMA_GRAPH_TIME) + 감시기
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/rebuild-1111
export BENCH_S=900 WATCH=0 CL_rv="GGML_META_REUSE=1 GGML_META_REUSE_VERIFY=1 GGML_META_CACHE_STATS=1"
OUTDIR=rebuild-1111 RUNS="mtp:rv none:rv" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -2)
for d in $(ls -td $R/runs/srv-2node-*-bs-rv-1* | head -2); do echo "== $d"; grep -E "VERIFY|simple tensors reused" $d/server.log | tail -3 | cut -c1-220; grep -c "VERIFY reused" $d/server.log; done
echo VERIFYDONE
export BENCH_S=600 WATCH=1 CL_rt="GGML_META_REUSE=1 GGML_META_TIME=1 LLAMA_GRAPH_TIME=1" CL_rb="GGML_META_TIME=1 LLAMA_GRAPH_TIME=1"
OUTDIR=rebuild-1111 RUNS="mtp:rb mtp:rt" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -4)
for d in $(ls -td $R/runs/srv-2node-mtp-bs-r[bt]-* | head -4); do echo "== $d"; grep -E "meta init_tensor|meta time" $d/server.log | tail -2 | cut -c1-220; grep "graph time over" $d/server.log | grep "7022 nodes" | tail -1 | cut -c1-220; done
for s in $(grep -o "| 2026111[0-9]-[0-9]* |" $(ls -1t $O/watch-summary-*.md | head -1) | tr -d "| "); do python3 $R/tools/bench/rebuilds.py $R/runs/watch/$s; done
echo ALLDONE
