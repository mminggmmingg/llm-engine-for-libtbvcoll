#!/usr/bin/env bash
# prof2node.sh 의 B 판: 2노드 디코드에서 B 서버만 rocprofv3(커널 기록) 아래 — A 에서: tools/bench/prof2node_b.sh <tag> [토큰 수=32]
#   A 서버는 평소대로. B 의 서버는 SIGINT 로 멈춰 기록을 쓰게 하고, 기록 크기가 멈추면(최대 120 초) KILL. 기록은 A 로 가져온다.
#   결과: runs/prof2node-b-<tag>-<시각>/ (b_kernel_trace.csv → a_kernel_trace.csv 이름으로도 복사해 kdiff.py·fetchsum 류가 그대로 읽게)
set -u
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
BIN=${BIN:-/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp/build-rocm3/bin}
M=${MODEL:-/data/parksThink/hf-models/qwen38-flash-next-gguf/UD-IQ4_XS-dense4/Qwen3.8-Flash-Next-Q8mix-q8mix-H5.gguf}
B=parks-zbook@10.99.0.2; BBIN=/home/parks-zbook/engine2n/bin; SSHO="-o BatchMode=yes -o ConnectTimeout=10"
tag=${1:?tag}; NTOK=${2:-32}
O=$R/runs/prof2node-b-$tag-$(date +%m%d-%H%M%S); mkdir -p $O; BO=$BBIN/prof-b-$(basename $O)
ENV="LD_LIBRARY_PATH=/opt/rocm/lib GGML_RDMA_CHUNK=65536 GGML_RDMA_RX_DEPTH=48 GGML_RDMA_TX_SLOTS=4 GGML_RPC_COMM_OVERLAP=2 GGML_CUDA_DISABLE_GRAPHS=1 ${SRVX:-}"
if pgrep -x ggml-rpc-server > /dev/null || pgrep -x llama-server > /dev/null; then echo "A 에 서버가 돌고 있음"; exit 1; fi
scp -q "$BIN/ggml-rpc-server" "$B:$BBIN/" || exit 3
ssh $SSHO $B "pkill -x ggml-rpc-server; sleep 1; mkdir -p $BO; cd $BBIN && env $ENV setsid -f /opt/rocm/bin/rocprofv3 --kernel-trace --output-format csv -d $BO/prof -o b -- ./ggml-rpc-server -H 10.99.0.2 -p 50052 -c > $BO/rpc-b.log 2>&1 < /dev/null"
env $(echo $ENV) "$BIN/ggml-rpc-server" -H 127.0.0.1 -p 50052 > $O/rpc-a.log 2>&1 & APID=$!
sleep 8
env LD_LIBRARY_PATH=/opt/rocm/lib LLAMA_TP_FFN_GRAN=32 GGML_RDMA_CHUNK=65536 GGML_RDMA_RX_DEPTH=48 GGML_RDMA_TX_SLOTS=4 timeout 900 \
    "$BIN/llama-bench" -m "$M" -fa 1 ${BARGS:--p 0 -n $NTOK -r 1} --rpc 10.99.0.2:50052,127.0.0.1:50052 -sm tensor -dev RPC0/RPC1 -o md > $O/bench.txt 2>&1
grep -E "^\|" $O/bench.txt | tail -1
kill -TERM $APID 2>/dev/null
ssh $SSHO $B "pkill -INT -x ggml-rpc-server; last=-1; for i in \$(seq 120); do pgrep -x ggml-rpc-server > /dev/null || break; sz=\$(stat -c %s $BO/prof/b_kernel_trace.csv 2>/dev/null || echo 0); [ \"\$sz\" -gt 0 ] && [ \"\$sz\" = \"\$last\" ] && break; last=\$sz; sleep 1; done; pkill -KILL -x ggml-rpc-server; true"
for i in $(seq 30); do kill -0 $APID 2>/dev/null || break; sleep 1; done; kill -KILL $APID 2>/dev/null
scp -q $B:$BO/prof/b_kernel_trace.csv $B:$BO/rpc-b.log $O/ && cp $O/b_kernel_trace.csv $O/a_kernel_trace.csv
ls $O; echo "$O"
