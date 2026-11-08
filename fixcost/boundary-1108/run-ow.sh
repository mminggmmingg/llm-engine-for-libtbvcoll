#!/usr/bin/env bash
# 11-08 오후: 작은 명령을 한 번에 쓰기(ggml-rpc.cpp send_rpc_cmd, 기본 켬; A 서버로 가는 TCP 루프백 명령의 send() 3번 → 1번) 빌드 뒤
#  ow(새 기본 + SYNC_SPIN=1) / ow0(ow + GGML_RPC_ONE_WRITE=0, 예전 쓰기) 3바퀴 + 감시기 회. $1 = 앞 측정 PID.
LL=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/boundary-1108
[ -n "$1" ] && while kill -0 $1 2>/dev/null; do sleep 10; done
echo "== build $(date +%T)"
nice cmake --build $LL/build-rocm3 -j 30 --target ggml-rpc-server llama-server llama-bench > $O/build6.log 2>&1 || { echo "build failed"; exit 1; }
echo "== built $(date +%T)"
sleep 30
export CL_ow="GGML_RPC_SYNC_SPIN=1" CL_ow0="GGML_RPC_SYNC_SPIN=1 GGML_RPC_ONE_WRITE=0"
cd $O
WATCH=1 OUTDIR=boundary-1108 RUNS="none:ow none:ow0 none:ow none:ow0 none:ow none:ow0" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-none-bs-ow*-bench.txt)
for s in $(ls -1dt $R/runs/watch/2*/ | head -2); do echo "== $s"; python3 -I $O/cring.py $s 0 300 | sed -n '/== before/,$p' | head -12; done
