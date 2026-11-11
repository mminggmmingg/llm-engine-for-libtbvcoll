#!/usr/bin/env bash
# 11-12 00:0x: 재사용 둘째 판 — (1) UNKNOWN(원소 0개) 바뀜에 캐시 안 비우기: 분할 상태 누적 해시를 20:37 기준과 비교, (2) GGML_META_REUSE 바이트 비교 검증 MTP·none,
# (3) 시간 한 쌍(재사용 끔/켬, GGML_META_TIME·LLAMA_GRAPH_TIME) + 감시기
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/rebuild-1111
export BENCH_S=900 WATCH=0 CL_dge="GGML_META_CACHE_DIGEST=1 GGML_META_CACHE_STATS=1" CL_rv2="GGML_META_REUSE=1 GGML_META_REUSE_VERIFY=1 GGML_META_CACHE_STATS=1"
OUTDIR=rebuild-1111 RUNS="mtp:dge mtp:rv2 none:rv2" bash $R/tools/bench/node-ab.sh
d=$(ls -td $R/runs/srv-2node-mtp-bs-dge-1* | head -1); grep "split digest" $d/server.log > $O/digest-empty.txt
echo "digest lines base $(wc -l < $O/digest-base.txt) empty-exempt $(wc -l < $O/digest-empty.txt); diff:"; diff $O/digest-base.txt $O/digest-empty.txt | head -4; echo "(end diff)"
grep -E "keep\)" $d/server.log | tail -3 | cut -c1-200
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -3)
for d in $(ls -td $R/runs/srv-2node-*-bs-rv2-1* | head -2); do echo "== $d"; grep -E "simple tensors reused" $d/server.log | tail -1 | cut -c1-200; echo "verify mismatch lines: $(grep -c 'VERIFY reused' $d/server.log)"; grep 'VERIFY reused' $d/server.log | head -3; done
echo VERIFYDONE
export BENCH_S=600 WATCH=1 CL_rt2="GGML_META_REUSE=1 GGML_META_TIME=1 LLAMA_GRAPH_TIME=1" CL_rb2="GGML_META_TIME=1 LLAMA_GRAPH_TIME=1"
OUTDIR=rebuild-1111 RUNS="mtp:rb2 mtp:rt2" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -4)
for d in $(ls -td $R/runs/srv-2node-mtp-bs-r[bt]2-* | head -4); do echo "== $d"; grep -E "meta init_tensor|meta time" $d/server.log | tail -2 | cut -c1-260; grep "graph time over" $d/server.log | grep "7022 nodes" | tail -1 | cut -c1-220; done
for s in $(grep -o "| 2026111[0-9]-[0-9]* |" $(ls -1t $O/watch-summary-*.md | head -1) | tr -d "| "); do python3 $R/tools/bench/rebuilds.py $R/runs/watch/$s; done
echo ALLDONE
