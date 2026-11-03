#!/usr/bin/env bash
# 2노드 디코드에서 A 서버만 rocprofv3(커널 기록) 아래 — A 에서: tools/bench/prof2node.sh <tag> [토큰 수=32]
#   B 서버는 평소대로. 클라이언트는 llama-bench(-p 0 -n N). 서버는 SIGINT 로 멈춰 rocprofv3 가 기록을 쓰게 한다(60 초 안에 안 끝나면 KILL).
#   결과: runs/prof2node-<tag>-<시각>/ (a_kernel_trace.csv, a_memory_copy_trace.csv, bench.txt, rpc-a.log). 아무것도 지우지 않는다.
#   분석: tools/bench/kgroup.py <그 폴더>
set -u
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
BIN=${BIN:-/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp/build-rocm3/bin}
M=${MODEL:-/data/parksThink/hf-models/qwen38-flash-next-gguf/UD-IQ4_XS-dense4/Qwen3.8-Flash-Next-Q8mix-q8mix-H5.gguf}
B=parks-zbook@10.99.0.2; BBIN=/home/parks-zbook/engine2n/bin
tag=${1:?tag}; NTOK=${2:-32}
O=$R/runs/prof2node-$tag-$(date +%m%d-%H%M%S); mkdir -p $O
ENV="LD_LIBRARY_PATH=/opt/rocm/lib GGML_RDMA_CHUNK=65536 GGML_RDMA_RX_DEPTH=48 GGML_RDMA_TX_SLOTS=4 GGML_RPC_COMM_OVERLAP=2 GGML_CUDA_DISABLE_GRAPHS=1 ${SRVX:-}"
if pgrep -x ggml-rpc-server > /dev/null || pgrep -x llama-server > /dev/null; then echo "A 에 서버가 돌고 있음"; exit 1; fi
scp -q "$BIN/ggml-rpc-server" "$B:$BBIN/" || exit 3
ssh -o BatchMode=yes $B "pkill -x ggml-rpc-server; sleep 1; cd $BBIN && env $(echo $ENV) setsid -f ./ggml-rpc-server -H 10.99.0.2 -p 50052 -c > rpc-server-prof2node.log 2>&1 < /dev/null"
cd $O || exit 1
env $(echo $ENV) /opt/rocm/bin/rocprofv3 --kernel-trace --memory-copy-trace --output-format csv -d $O/prof -o a -- "$BIN/ggml-rpc-server" -H 127.0.0.1 -p 50052 > rpc-a.log 2>&1 & APID=$!   # APID = 서버(셸 아님)
sleep 5
env LD_LIBRARY_PATH=/opt/rocm/lib LLAMA_TP_FFN_GRAN=32 GGML_RDMA_CHUNK=65536 GGML_RDMA_RX_DEPTH=48 GGML_RDMA_TX_SLOTS=4 ${CLIX:-} \
    "$BIN/llama-bench" -m "$M" -fa 1 -p 0 -n $NTOK -r 1 --rpc 10.99.0.2:50052,127.0.0.1:50052 -sm tensor -dev RPC0/RPC1 -o md > $O/bench.txt 2>&1
grep -E "^\|" $O/bench.txt | tail -1
kill -INT $APID 2>/dev/null; ssh -o BatchMode=yes $B "pkill -INT -x ggml-rpc-server"
# rocprofv3 는 SIGINT 뒤 기록을 쓰고 나서도 서버가 안 끝날 때가 있다: 기록 파일 크기가 멈추면(최대 120 초) KILL
last=-1
for i in $(seq 120); do
    kill -0 $APID 2>/dev/null || break
    sz=$(stat -c %s $O/prof/a_kernel_trace.csv 2>/dev/null || echo 0)
    [ "$sz" -gt 0 ] && [ "$sz" = "$last" ] && break
    last=$sz; sleep 1
done
kill -KILL $APID 2>/dev/null; pkill -KILL -x ggml-rpc-server; ssh -o BatchMode=yes $B "pkill -KILL -x ggml-rpc-server; true"
[ -d $O/prof ] && cp $O/prof/a_kernel_trace.csv $O/prof/a_memory_copy_trace.csv $O/ 2>/dev/null
ls $O; echo "$O"
