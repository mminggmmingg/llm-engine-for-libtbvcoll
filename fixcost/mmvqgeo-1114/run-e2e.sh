#!/usr/bin/env bash
# 11-14 06:5x: mmvq 형식별 2행(3–4열, Q6_K·Q5_0·IQ4_NL·IQ4_XS) 새 빌드(g) / 바로 전 빌드(b, build-rocm3/bin-1114-sk) 번갈아, MTP 6 프롬프트, 감시기 회 포함.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; L=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp
export SA_g="" SB_g="" SA_b="" SB_b="" BIN_b=$L/build-rocm3/bin-1114-sk
BENCH_S=600 WATCH=1 OUTDIR=mmvqgeo-1114 RUNS="mtp:g mtp:b mtp:g mtp:b" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1tr $R/fixcost/mmvqgeo-1114/srv-2node-mtp-bs-*-1114-*-bench.txt | grep -v -- '-w-' | tail -4)
echo ALLDONE
