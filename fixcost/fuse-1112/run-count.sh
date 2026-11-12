#!/usr/bin/env bash
# 11-12 13:4x (진단, 감시기 없음): A/B 에서 MTP 이득이 안 보여서 — 검증(4토큰) 그래프에서도 융합이 걸리는지 GGML_CUDA_FUSE_COUNT=1 로 센다
# 13:5x 둘째 판: ple_conv 가 어느 검사에서 멈추는지(stops #n = ggml-cuda.cu ggml_cuda_try_ple_conv_mix 의 n번째 return) — RUNS=mtp:fc NLAST=1
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/fuse-1112
export BENCH_S=600 WATCH=0 SA_fc="GGML_CUDA_FUSE_COUNT=1" SB_fc="GGML_CUDA_FUSE_COUNT=1"
OUTDIR=fuse-1112 RUNS="${RUNS:-mtp:fc none:fc}" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1tr $O/srv-2node-*-fc-*-bench.txt)
for d in $(ls -1dtr $R/runs/srv-2node-*-fc-* | tail -${NLAST:-2}); do echo "== $d"; for n in a b; do echo "-- $n"; grep "e2n fuse" $d/rpc-$n.log | tail -4; done; done
echo ALLDONE
