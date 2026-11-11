#!/usr/bin/env bash
# 11-12 01:0x: 재사용 셋째 판(직전 내용 기억)을 검증 없이 켜면 출력이 바뀌고 클라이언트가 죽음 — gdb 로 감싸 죽는 곳 잡기(진단, 감시기 없음)
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/rebuild-1111
export BENCH_S=600 WATCH=0 CL_dbg="GGML_META_REUSE=1 GGML_META_CACHE_STATS=1"
export CW_dbg="env HSA_OVERRIDE_CPU_AFFINITY_DEBUG=0 taskset -c 0-1,7-20,25-29,31 gdb -q -batch -x /data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll/fixcost/rebuild-1111/gdb-dbg.cmds --args"
OUTDIR=rebuild-1111 RUNS="mtp:dbg" bash $R/tools/bench/node-ab.sh
d=$(ls -td $R/runs/srv-2node-mtp-bs-dbg-1* | head -1); grep -nE "SIGSEGV|SIGABRT|signal|^#[0-9]" $d/server.log | head -40 | cut -c1-200; head -3 $d/bench.txt | cut -c1-160
echo ALLDONE
