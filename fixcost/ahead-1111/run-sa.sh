#!/usr/bin/env bash
# 11-11 13:4x: 다시 짓기 때 부분그래프 직렬화를 서버별 디스패처 스레드로(GGML_RPC_SER_ASYNC=1, 클라이언트) + 직렬화 안 할당 줄임(새 빌드 공통)
# 번갈아 2쌍 + 감시기(sa, def)
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/ahead-1111
export BENCH_S=600 WATCH=1 CL_sa="GGML_RPC_SER_ASYNC=1"
OUTDIR=ahead-1111 RUNS="${RUNS:-mtp:sa mtp:def mtp:sa mtp:def}" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -6)
