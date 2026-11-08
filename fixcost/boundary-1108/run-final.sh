#!/usr/bin/env bash
# 11-08 저녁: 새 기본(입력 복사 기다림 생략 + 한 번에 쓰기 + 클라이언트 돌기 기본 켬) 빌드 뒤 확인 — none / MTP 2바퀴씩 + 감시기 회, 해시. $1 = 앞 측정 PID.
LL=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/boundary-1108
[ -n "$1" ] && while kill -0 $1 2>/dev/null; do sleep 10; done
echo "== build $(date +%T)"
nice cmake --build $LL/build-rocm3 -j 30 --target ggml-rpc-server llama-server llama-bench > $O/build7.log 2>&1 || { echo "build failed"; exit 1; }
echo "== built $(date +%T)"
sleep 30
cd $O
WATCH=1 OUTDIR=boundary-1108 RUNS="none:fin mtp:fin none:fin mtp:fin" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-none-bs-fin*-bench.txt)
