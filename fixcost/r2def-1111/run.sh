#!/usr/bin/env bash
# 11-11 01:0x: 두 레일(r2)을 srv-probe 기본으로(RAIL2=1, 장치 자동: tbcommdev.sh rail2) — 새 기본(r2) vs 끔(off, RAIL2=0) 번갈아.
# MTP 3쌍 + none 2쌍(32 KB 미만이라 none 은 나누지 않지만 RX_DEPTH 32·둘째 연결이 생김) + 구성마다 감시기·DRAM 회.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
export RAIL2_off=0
OUTDIR=r2def-1111 RUNS="mtp:r2 mtp:off mtp:r2 mtp:off mtp:r2 mtp:off none:r2 none:off none:r2 none:off" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $R/fixcost/r2def-1111/srv-2node-*-bench.txt)
