#!/usr/bin/env bash
# 11-11 20:4x: 메타 분할 상태 캐시를 바뀐 항목만 다시(GGML_META_CACHE_KEEP=1).
# (20:0x 첫 검증 모드는 적중마다 소스를 재귀로 다시 계산해 끝나지 않아 멈춤 — run-keep-v1-stopped.log; 20:1x 둘째 판은 단계 첫 조회에서 조상 전체를 재귀로 따라가 클라이언트가
#  로그 없이 죽음 — run-keep-v2-crashed.log, 스택 넘침으로 봄.) 이번: 바깥 호출자에게 돌려준 분할 상태의 누적 해시(GGML_META_CACHE_DIGEST=1)를 기준·KEEP 회에서 비교,
# (20:25 판은 20:13 판 스크립트가 아직 시간 회를 돌던 중에 겹쳐 띄워 서로 서버를 내림 — run-keep-v3-overlapped.log, 무효.)
# 그다음 시간 회(기준 vs keep, LLAMA_GRAPH_TIME·GGML_META_TIME) + 감시기, 해시
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/rebuild-1111
export BENCH_S=900 WATCH=0
export CL_dgb="GGML_META_CACHE_DIGEST=1" CL_dgk="GGML_META_CACHE_DIGEST=1 GGML_META_CACHE_KEEP=1 GGML_META_CACHE_STATS=1"
OUTDIR=rebuild-1111 RUNS="mtp:dgb mtp:dgk" bash $R/tools/bench/node-ab.sh
db=$(ls -td $R/runs/srv-2node-mtp-bs-dgb-1* | head -1); dk=$(ls -td $R/runs/srv-2node-mtp-bs-dgk-1* | head -1)
grep "split digest" $db/server.log > $O/digest-base.txt; grep "split digest" $dk/server.log > $O/digest-keep.txt
echo "digest lines base $(wc -l < $O/digest-base.txt) keep $(wc -l < $O/digest-keep.txt); first difference:"; diff $O/digest-base.txt $O/digest-keep.txt | head -4; echo "(end diff)"
grep -E "keep\)|split state cache:.*hits" $dk/server.log | tail -2 | cut -c1-220
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -2)
export BENCH_S=600 WATCH=1
export CL_tk="GGML_META_CACHE_KEEP=1 LLAMA_GRAPH_TIME=1 GGML_META_TIME=1" CL_tb="LLAMA_GRAPH_TIME=1 GGML_META_TIME=1"
OUTDIR=rebuild-1111 RUNS="mtp:tb mtp:tk" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -4)
for d in $(ls -td $R/runs/srv-2node-mtp-bs-t[bk]-* | head -4); do echo "== $d"; grep -E "graph time over|meta time" $d/server.log | tail -3 | cut -c1-260; done
for s in $(ls -td $R/runs/watch/2026111[1-9]-* | head -2); do python3 $R/tools/bench/rebuilds.py $s; done
echo ALLDONE
