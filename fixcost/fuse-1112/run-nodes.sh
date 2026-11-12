#!/usr/bin/env bash
# 11-12 12:2x (진단): 서버가 받은 부분그래프의 노드 목록(GGML_CUDA_NODES_DUMP) — PLE·QSA 마스크 융합 패턴을 쓰려고. llama-bench 2노드 decode 몇 토큰.
set -u
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/fuse-1112
BIN=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp/build-rocm3/bin
M=/data/parksThink/hf-models/qwen38-flash-next-gguf/UD-IQ4_XS-dense4/Qwen3.8-Flash-Next-Q8mix-q8mix-H5.gguf
B=parks-zbook@10.99.0.2; BBIN=/home/parks-zbook/engine2n/bin
ENV="LD_LIBRARY_PATH=/opt/rocm/lib GGML_RDMA_CHUNK=65536 GGML_RDMA_RX_DEPTH=48 GGML_RDMA_TX_SLOTS=4 GGML_RPC_COMM_OVERLAP=2 GGML_CUDA_DISABLE_GRAPHS=1"
if pgrep -x ggml-rpc-server > /dev/null || pgrep -x llama-server > /dev/null; then echo "A 에 서버가 돌고 있음"; exit 1; fi
scp -q "$BIN/ggml-rpc-server" "$B:$BBIN/" || exit 3
ssh -o BatchMode=yes $B "pkill -x ggml-rpc-server; sleep 1; cd $BBIN && env $(echo $ENV) setsid -f ./ggml-rpc-server -H 10.99.0.2 -p 50052 -c > rpc-server-nodes.log 2>&1 < /dev/null"
env $(echo $ENV) GGML_CUDA_NODES_DUMP="${DUMP:-ple_gate,indexer_sel-3}" "$BIN/ggml-rpc-server" -H 127.0.0.1 -p 50052 > $O/nodes-${TAG:-tg}.log 2>&1 & APID=$!
sleep 5
env LD_LIBRARY_PATH=/opt/rocm/lib LLAMA_TP_FFN_GRAN=32 GGML_RDMA_CHUNK=65536 GGML_RDMA_RX_DEPTH=48 GGML_RDMA_TX_SLOTS=4 \
    timeout 600 "$BIN/llama-bench" -m "$M" -fa 1 ${BARGS:--p 0 -n 4 -r 1} --rpc 10.99.0.2:50052,127.0.0.1:50052 -sm tensor -dev RPC0/RPC1 -o md > $O/nodes-${TAG:-tg}-bench.txt 2>&1
grep -E "^\|" $O/nodes-${TAG:-tg}-bench.txt | tail -1
kill $APID; ssh -o BatchMode=yes $B "pkill -x ggml-rpc-server"
for i in $(seq 30); do kill -0 $APID 2>/dev/null || break; sleep 1; done; kill -0 $APID 2>/dev/null && kill -KILL $APID
echo DONE
