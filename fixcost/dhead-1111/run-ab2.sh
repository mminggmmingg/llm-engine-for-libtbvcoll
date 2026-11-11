#!/usr/bin/env bash
# 11-11 12:0x: hx(초안 출력층 IQ4_XS) 확인 — 번갈아 2쌍 더 + 감시기 회(hx, def)
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/dhead-1111; M=/data/parksThink/hf-models/qwen38-flash-next-gguf/MTP
export BENCH_S=600 WATCH=1
export MTP_hx=$M/mtp-Qwen3.8-Flash-Next-merged-IQ4embd-dv96k-ko-qmix-hx.gguf
OUTDIR=dhead-1111 RUNS="${RUNS:-mtp:hx mtp:def mtp:hx mtp:def}" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -6)
