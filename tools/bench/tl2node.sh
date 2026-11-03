#!/usr/bin/env bash
# 2노드 시간 명세용 기록 — A 에서 실행: tools/bench/tl2node.sh <tag> [토큰 수=64]
#   두 rpc-server 를 rocprofv3(커널·복사 기록) 아래에서 띄우고(PROF=0 이면 프로파일러 없이), AR 타임라인(GGML_RPC_COMM_PROF_TL)과
#   comm_prof, 두 노드 gpu_metrics 를 남긴 채 llama-bench 로 2노드 디코드(MTP 없음)를 돈다.
#   결과: runs/tl2node-<tag>-<시각>/{a,b}/ — a_kernel_trace.csv, a_memory_copy_trace.csv, tl.txt, rpc.log, gm.txt, clocks.txt
#   (커널 기록은 크므로 runs/ 아래(저장소에 안 올라감)에 둔다. 분석: tools/bench/tl2spec.py <그 폴더>)
# 서버 끝내기: SIGINT 로 멈춰 rocprofv3 가 기록을 쓰게 하고, 60 초 안에 안 끝나면 KILL.
set -u
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
BIN=${BIN:-/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp/build-rocm3/bin}
M=${MODEL:-/data/parksThink/hf-models/qwen38-flash-next-gguf/UD-IQ4_XS-dense4/Qwen3.8-Flash-Next-Q8mix-q8mix-H5.gguf}
B=parks-zbook@10.99.0.2; BBIN=/home/parks-zbook/engine2n/bin
tag=${1:?tag}; NTOK=${2:-64}; PROF=${PROF:-1}
O=$R/runs/tl2node-$tag-$(date +%m%d-%H%M%S); mkdir -p $O/a $O/b
BW=$BBIN/tl2node                     # B 작업 폴더
ENV="LD_LIBRARY_PATH=/opt/rocm/lib GGML_RDMA_CHUNK=65536 GGML_RDMA_RX_DEPTH=48 GGML_RDMA_TX_SLOTS=4 GGML_RPC_COMM_OVERLAP=2
     GGML_CUDA_DISABLE_GRAPHS=1 GGML_RPC_COMM_PROF=1000 GGML_RPC_COMM_PROF_TL=tl.txt ${SRVX:-}"
PRE=""; [ "$PROF" = 1 ] && PRE="/opt/rocm/bin/rocprofv3 --kernel-trace --memory-copy-trace --output-format csv -d prof -o a --"
clocks='python3 -c "import time; m=time.clock_gettime(time.CLOCK_MONOTONIC); b=time.clock_gettime(time.CLOCK_BOOTTIME); print(f\"monotonic {m:.6f} boottime {b:.6f} boot-mono {b-m:.6f}\")"'

if pgrep -x ggml-rpc-server > /dev/null || pgrep -x llama-server > /dev/null; then echo "A 에 서버가 돌고 있음"; exit 1; fi
echo "== $tag PROF=$PROF NTOK=$NTOK → $O"
$R/tools/tbv_hotpoll.sh status | tee $O/tbv.txt
scp -q "$BIN/ggml-rpc-server" "$B:$BBIN/" || exit 3
ssh -o BatchMode=yes $B "pkill -x ggml-rpc-server; sleep 1; rm -rf $BW; mkdir -p $BW; cd $BW && $clocks > clocks.txt &&
    env $(echo $ENV) setsid -f $PRE $BBIN/ggml-rpc-server -H 10.99.0.2 -p 50052 -c > rpc.log 2>&1 < /dev/null"
cd $O/a && bash -c "$clocks" > clocks.txt
env $(echo $ENV) $PRE "$BIN/ggml-rpc-server" -H 127.0.0.1 -p 50052 > rpc.log 2>&1 & APID=$!
sleep 4
# 디코드 동안 두 노드 gpu_metrics(로딩 시간 넉넉히 + 토큰)
GS=$(( 150 + NTOK ))
python3 -I $R/tools/probe/gpumetrics_ts.py $GS > $O/a/gm.txt 2>&1 & GPID=$!
ssh -o BatchMode=yes $B "cd $BW; python3 -I $BBIN/gpumetrics_ts.py $GS > gm.txt 2>&1" & BGPID=$!
env LD_LIBRARY_PATH=/opt/rocm/lib LLAMA_TP_FFN_GRAN=32 GGML_RDMA_CHUNK=65536 GGML_RDMA_RX_DEPTH=48 GGML_RDMA_TX_SLOTS=4 ${CLIX:-} \
    "$BIN/llama-bench" -m "$M" -fa 1 -p 0 -n $NTOK -r 1 --rpc 10.99.0.2:50052,127.0.0.1:50052 -sm tensor -dev RPC0/RPC1 -o md > $O/bench.txt 2>&1
grep -E "^\|" $O/bench.txt | tail -1
# 서버 끝내기(기록 쓰기)
kill -INT $APID 2>/dev/null; ssh -o BatchMode=yes $B "pkill -INT -x ggml-rpc-server"
for i in $(seq 60); do
    a=$(kill -0 $APID 2>/dev/null && echo 1 || echo 0); b=$(ssh -o BatchMode=yes $B "pgrep -x ggml-rpc-server > /dev/null && echo 1 || echo 0")
    [ $a = 0 ] && [ $b = 0 ] && break; sleep 1
done
kill -KILL $APID 2>/dev/null; ssh -o BatchMode=yes $B "pkill -KILL -x ggml-rpc-server; true"
kill $GPID 2>/dev/null; wait $BGPID 2>/dev/null
[ -d prof ] && mv prof/a_kernel_trace.csv prof/a_memory_copy_trace.csv . 2>/dev/null
scp -q "$B:$BW/clocks.txt" "$B:$BW/tl.txt" "$B:$BW/tl.txt.cal" "$B:$BW/rpc.log" "$B:$BW/gm.txt" $O/b/ 2>/dev/null
[ "$PROF" = 1 ] && scp -q "$B:$BW/prof/a_kernel_trace.csv" "$B:$BW/prof/a_memory_copy_trace.csv" $O/b/ 2>/dev/null
echo "rdma=$(grep -c 'RDMA activated' $O/a/rpc.log) | A: $(ls $O/a | tr '\n' ' ') | B: $(ls $O/b | tr '\n' ' ')"
du -sh $O
echo "$O"
