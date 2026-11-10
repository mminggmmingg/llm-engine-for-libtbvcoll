#!/usr/bin/env bash
# 11-10 23:59: B 다시 연결 뒤 상태 확인 — 2노드 none 기본(def) 속도 회 1 + 감시기 회 1(새 node-ab: inferwatch tag 사본 iw-20261110-1, DRAM=auto 노드별 바이트)
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
OUTDIR=bchk-1110 RUNS="none:def" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $R/fixcost/bchk-1110/srv-2node-*-bench.txt | head -2)
