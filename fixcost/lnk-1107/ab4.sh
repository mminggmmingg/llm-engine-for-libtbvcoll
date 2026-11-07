#!/usr/bin/env bash
# new script default (TBPIN=1, CPUs from tools/bench/tbcpus.sh) vs off, none once + MTP 2 rounds, trace off
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
export TBPIN_off=0 TRACE=0 OUTDIR=lnk-1107 RUNS="none:def mtp:off mtp:def mtp:off mtp:def"
bash $R/tools/bench/node-ab.sh
