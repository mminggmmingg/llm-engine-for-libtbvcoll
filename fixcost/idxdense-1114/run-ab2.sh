#!/usr/bin/env bash
# 11-14 03:55: run-ab 의 mtp:dn 속도 회가 64k 프리필 도중 RPC 오류("Remote RPC server crashed", 11-04 부터 같은 문구 15회, 두 rpc 서버는 살아 있었음)로 끊김.
# 그 칸(64k·128k)만 다시: mtp dn/do 번갈아, 깊이 0·64k·128k(같은 글 자리), 속도 회만(감시기 회는 run-ab 에 있음).
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; C=$R/fixcost/ctx-1112/corpus-llamacpp-e09a78a.txt
export SA_dn="" SB_dn="" SA_do="GGML_CUDA_NO_IDX_DENSE=1" SB_do="GGML_CUDA_NO_IDX_DENSE=1"
SRV_EXTRA="-c 262144" BENCH_S=1500 WATCH=0 BENCH="tools/bench/ctx_bench.py $C 0,65536,131072 1 {OUT}/ctx.jsonl" OUTDIR=idxdense-1114 \
  RUNS="mtp:dn mtp:do" bash $R/tools/bench/node-ab.sh
for d in $(ls -1dtr $R/runs/srv-2node-mtp-bs-d[no]-1114-* | tail -2); do echo "== $d"; cat $d/ctx.jsonl 2>/dev/null; grep -c "Remote RPC server crashed" $d/server.log; done
echo ALLDONE
