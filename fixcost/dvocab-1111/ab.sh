#!/usr/bin/env bash
# 11-11: 초안 어휘 80k + 한글(dv80, 행 수는 ids-80k-ko.txt) vs 지금 기본 96k + 한글(dv96, 104459행) — MTP 3쌍 번갈아 + 감시기·DRAM 회. r2 기본, 새 바이너리.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
export MTP_dv80=/data/parksThink/hf-models/qwen38-flash-next-gguf/MTP/mtp-Qwen3.8-Flash-Next-merged-IQ4embd-dv80k-ko-qmix.gguf MTP_dv96=/data/parksThink/hf-models/qwen38-flash-next-gguf/MTP/mtp-Qwen3.8-Flash-Next-merged-IQ4embd-dv96k-ko-qmix.gguf BENCH_S=600
OUTDIR=dvocab-1111 RUNS="mtp:dv80 mtp:dv96 mtp:dv80 mtp:dv96 mtp:dv80 mtp:dv96" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $R/fixcost/dvocab-1111/srv-2node-*-bench.txt)
