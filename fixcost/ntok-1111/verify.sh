#!/usr/bin/env bash
# 11-11: 새 4토큰 묶음 비트 검증 — 2노드 MTP 1회, 두 서버에 VERIFY(묶은 커널 뒤 원래 노드를 다시 돌려 비트 비교), 기록 링 끔
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll/fixcost/ntok-1111
export BENCH_S=900 STOP_S=60 TRACE=0 BIN=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp/build-rocm3/bin MODEL=/data/parksThink/hf-models/qwen38-flash-next-gguf/UD-IQ4_XS-dense4/Qwen3.8-Flash-Next-Q8mix-q8mix-H5.gguf
V="GGML_CUDA_DISABLE_GRAPHS=1 GGML_RPC_COMM_PROF=0 GGML_CUDA_GLU_NTOK_VERIFY=1 GGML_CUDA_CONV_NORM_VERIFY=1"
out=$(SRV_ENV="$V" SRV_ENV_B="$V" SPEC_EXTRA="-devd ROCm0" TAG=verify bash $R/tools/bench/srv-probe.sh 2node mtp 2>&1); d=$(echo "$out" | tail -1)
echo "$out" | grep TOTAL; echo "run: $d"
scp -q parks-zbook@10.99.0.2:/home/parks-zbook/engine2n/bin/rpc-server.log $d/rpc-b.log
for x in a b; do echo "== $x"; grep -h -E "verify" $d/rpc-$x.log | sed -E 's/blk\.[0-9]+/blk.N/' | sort | uniq -c | sort -rn | head -12; echo "DIFFER lines: $(grep -c DIFFER $d/rpc-$x.log)"; done
cp $d/bench.txt $O/verify-bench.txt; python3 -I $R/fixcost/gluhc-1108/hashchk.py $O/verify-bench.txt
