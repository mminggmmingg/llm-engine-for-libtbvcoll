#!/usr/bin/env bash
# 11-10: MTP 초안(클라이언트 GPU) 커널 기록 — run-r2b 가 끝난 뒤, 클라이언트(llama-server)만 rocprofv3 아래에서 MTP 1회
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/mtpv-1110
while pgrep -f "^bash /data.*run-r2b.sh" > /dev/null; do sleep 10; done
P=$O/cprof-$(date +%m%d-%H%M%S); mkdir -p $P
export CW_cp="env HSA_OVERRIDE_CPU_AFFINITY_DEBUG=0 taskset -c 0-1,7-20,25-30 /opt/rocm/bin/rocprofv3 --kernel-trace --output-format csv -d $P -o c --"
cd $O
WATCH=0 OUTDIR=mtpv-1110 RUNS="mtp:cp" bash $R/tools/bench/node-ab.sh
find $P -name "*kernel_trace.csv" | head -3
