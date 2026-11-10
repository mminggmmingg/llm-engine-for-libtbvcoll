#!/usr/bin/env bash
# 11-11: 2노드 none 디코드 중 같은 30 초 창에서 노드 전체 DRAM 읽기(perf amd_df, inferwatch sample-dram)와 CPU 코어의 DRAM 채움
# (l2_fill_rsp_src.dram_io_near × 64 B: 노드 전체 -a, 프로세스별 A rpc-server·llama-server, B rpc-server) → DRAM 읽기 중 CPU 몫. 시간 제한 있음.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll/fixcost/bytes-1111; B=parks-zbook@10.99.0.2
IWB=/data/parksThink/inferwatch-iw-20261110-1/target/release/inferwatch; BIW=/home/parks-zbook/inferwatch/bin/inferwatch
export BENCH_S=600 STOP_S=60 TRACE=0 MODEL=/data/parksThink/hf-models/qwen38-flash-next-gguf/UD-IQ4_XS-dense4/Qwen3.8-Flash-Next-Q8mix-q8mix-H5.gguf
EV=l2_fill_rsp_src.dram_io_near,l2_fill_rsp_src.all
( SRV_ENV="GGML_CUDA_DISABLE_GRAPHS=1 GGML_RPC_COMM_PROF=0" TAG=cpufill timeout 1200 bash $R/tools/bench/srv-probe.sh 2node none > $O/cpufill-probe.log 2>&1 ) & SP=$!
for i in $(seq 600); do curl -sf http://127.0.0.1:8077/health > /dev/null && break; sleep 1; done
sleep 3
AR=$(pgrep -x ggml-rpc-server | head -1); CL=$(pgrep -x llama-server | head -1); BR=$(timeout 10 ssh -o BatchMode=yes $B "pgrep -x ggml-rpc-server | head -1")
echo "pids A rpc $AR client $CL B rpc $BR" > $O/cpufill-pids.txt
D=30
timeout 60 perf stat -x, -e $EV -a -o $O/cpufill-a-all.txt -- sleep $D &
timeout 60 perf stat -x, -e $EV -p $AR -o $O/cpufill-a-rpc.txt -- sleep $D &
timeout 60 perf stat -x, -e $EV -p $CL -o $O/cpufill-a-client.txt -- sleep $D &
timeout 60 $IWB sample-dram $D 100 $O/cpufill-a-df.txt > /dev/null 2>&1 &
timeout 70 ssh -n -o BatchMode=yes $B "timeout 60 perf stat -x, -e $EV -a -o /tmp/cpufill-b-all.txt -- sleep $D & timeout 60 perf stat -x, -e $EV -p $BR -o /tmp/cpufill-b-rpc.txt -- sleep $D & timeout 60 $BIW sample-dram $D 100 /tmp/cpufill-b-df.txt > /dev/null 2>&1; wait" &
wait $(jobs -p | grep -v "^$SP$") 2>/dev/null
sleep 2
scp -q $B:/tmp/cpufill-b-all.txt $B:/tmp/cpufill-b-rpc.txt $B:/tmp/cpufill-b-df.txt $O/
wait $SP; grep TOTAL $O/cpufill-probe.log
