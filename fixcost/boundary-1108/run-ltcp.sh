#!/usr/bin/env bash
# 11-08 오후: (1) node-ab.sh RDMA 확인 고치기(돌고 있지 않을 때) (2) 빌드(GGML_RPC_LOCAL_TCP) (3) none sp1 / lt(sp1 + 같은 노드 연결 TCP) 3바퀴,
# MTP def / sp1 2바퀴 + 감시기 회. $1 = 앞 측정 PID.
LL=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/boundary-1108
[ -n "$1" ] && while kill -0 $1 2>/dev/null; do sleep 10; done
python3 -I $O/fix-nodeab.py || exit 1
echo "== build $(date +%T)"
nice cmake --build $LL/build-rocm3 -j 30 --target ggml-rpc-server llama-server llama-bench > $O/build5.log 2>&1 || { echo "build failed"; exit 1; }
echo "== built $(date +%T)"
sleep 30
export CL_sp1="GGML_RPC_SYNC_SPIN=1" CL_lt="GGML_RPC_SYNC_SPIN=1 GGML_RPC_LOCAL_TCP=1" CL_lt0="GGML_RPC_LOCAL_TCP=1"
cd $O
WATCH=1 OUTDIR=boundary-1108 RUNS="none:sp1 none:lt none:lt0 none:sp1 none:lt none:lt0 none:sp1 none:lt none:lt0" bash $R/tools/bench/node-ab.sh
WATCH=1 OUTDIR=boundary-1108 RUNS="mtp:def mtp:sp1 mtp:def mtp:sp1" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-none-bs-*-bench.txt | head -12)
