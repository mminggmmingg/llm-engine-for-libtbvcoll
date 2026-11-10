#!/usr/bin/env bash
# 11-11: 지금 바이너리의 4토큰 서브그래프 노드 목록(A 서버 GGML_CUDA_DUMP_NTOK=4) — llama-bench -p 4 -n 0 -r 2, 2노드. 시간 제한 있음.
BIN=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp/build-rocm3/bin; M=/data/parksThink/hf-models/qwen38-flash-next-gguf/UD-IQ4_XS-dense4/Qwen3.8-Flash-Next-Q8mix-q8mix-H5.gguf
B=parks-zbook@10.99.0.2; BBIN=/home/parks-zbook/engine2n/bin; O=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll/fixcost/ntok-1111
ENV="LD_LIBRARY_PATH=/opt/rocm/lib GGML_RDMA_CHUNK=65536 GGML_RDMA_RX_DEPTH=48 GGML_RDMA_TX_SLOTS=4 GGML_RPC_COMM_OVERLAP=2 GGML_CUDA_DISABLE_GRAPHS=1"
if pgrep -x ggml-rpc-server > /dev/null || pgrep -x llama-server > /dev/null; then echo "A 에 서버가 돌고 있음"; exit 1; fi
scp -q "$BIN/ggml-rpc-server" "$B:$BBIN/" || exit 3
ssh -o BatchMode=yes $B "pkill -x ggml-rpc-server; sleep 1; cd $BBIN && env $ENV setsid -f ./ggml-rpc-server -H 10.99.0.2 -p 50052 -c > rpc-server-dump.log 2>&1 < /dev/null"
env $ENV GGML_CUDA_DUMP_NTOK=4 "$BIN/ggml-rpc-server" -H 127.0.0.1 -p 50052 > $O/dump-a.log 2>&1 & APID=$!
sleep 5
env LD_LIBRARY_PATH=/opt/rocm/lib LLAMA_TP_FFN_GRAN=32 GGML_RDMA_CHUNK=65536 GGML_RDMA_RX_DEPTH=48 GGML_RDMA_TX_SLOTS=4 timeout 600 \
    "$BIN/llama-bench" -m "$M" -fa 1 -p 4 -n 0 -r 2 --rpc 10.99.0.2:50052,127.0.0.1:50052 -sm tensor -dev RPC0/RPC1 -o md > $O/dump-bench.txt 2>&1
kill -TERM $APID 2>/dev/null; ssh -o BatchMode=yes $B "pkill -TERM -x ggml-rpc-server"
for i in $(seq 30); do kill -0 $APID 2>/dev/null || break; sleep 1; done
kill -KILL $APID 2>/dev/null; ssh -o BatchMode=yes $B "pkill -KILL -x ggml-rpc-server; true"
grep -c "^ntok" $O/dump-a.log
