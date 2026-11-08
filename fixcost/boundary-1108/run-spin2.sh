#!/usr/bin/env bash
# 11-08 낮: 클라이언트 기다림을 끝 무렵에만 돌기(GGML_RPC_SYNC_SPIN=2, 긴 기다림 평균 − 꼬리 1 ms 까지 자고 나머지 돎) 빌드 뒤
#  def(새 입력 복사) / sp1(SYNC_SPIN=1 내내 돎) / sp2(=2) / sp2t(=2, 꼬리 300 µs) 3바퀴 + 감시기 회. $1 = 앞 측정 PID.
LL=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/boundary-1108
[ -n "$1" ] && while kill -0 $1 2>/dev/null; do sleep 10; done
echo "== build $(date +%T)"
nice cmake --build $LL/build-rocm3 -j 30 --target ggml-rpc-server llama-server llama-bench > $O/build4.log 2>&1 || { echo "build failed"; exit 1; }
echo "== built $(date +%T)"
sleep 30
export CL_sp1="GGML_RPC_SYNC_SPIN=1" CL_sp2="GGML_RPC_SYNC_SPIN=2" CL_sp2t="GGML_RPC_SYNC_SPIN=2 GGML_RPC_SYNC_SPIN_TAIL_US=300"
cd $O
WATCH=1 OUTDIR=boundary-1108 RUNS="none:def none:sp1 none:sp2 none:sp2t none:def none:sp1 none:sp2 none:sp2t none:def none:sp1 none:sp2 none:sp2t" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-none-bs-*-bench.txt | head -16)
