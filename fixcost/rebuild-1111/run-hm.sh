#!/usr/bin/env bash
# 11-11 21:2x: 메타 백엔드의 두 표(분할 상태 캐시, 단순 텐서 표)를 std::map → unordered_map. KEEP=1 과 함께, 분할 상태 누적 해시를 20:37 기준 회와 비교 + 시간 계측, MTP 한 회 + 감시기
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/rebuild-1111
export BENCH_S=600 WATCH=1 CL_hm="GGML_META_CACHE_KEEP=1 GGML_META_CACHE_DIGEST=1 GGML_META_TIME=1 LLAMA_GRAPH_TIME=1"
OUTDIR=rebuild-1111 RUNS="mtp:hm" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -2)
d=$(ls -td $R/runs/srv-2node-mtp-bs-hm-1* | head -1); grep "split digest" $d/server.log > $O/digest-hm.txt
echo "digest lines base $(wc -l < $O/digest-base.txt) hm $(wc -l < $O/digest-hm.txt); diff:"; diff $O/digest-base.txt $O/digest-hm.txt | head -4; echo "(end diff)"
for d in $(ls -td $R/runs/srv-2node-mtp-bs-hm* | head -2); do echo "== $d"; grep -E "meta init_tensor|meta time" $d/server.log | tail -2 | cut -c1-220; grep "graph time over" $d/server.log | grep "7022 nodes" | tail -1 | cut -c1-220; done
echo ALLDONE
