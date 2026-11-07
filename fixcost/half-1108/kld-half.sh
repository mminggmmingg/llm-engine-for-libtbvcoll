#!/usr/bin/env bash
# 16-bit decode AR(GGML_RPC_COMM_HALF) 품질: 2노드 TP, -ub 4(부분합 4×2560 f32 = 40 KB ≤ 64 KB → ZC=3 경로), 같은 빌드(build-half)에서
# HALF=0(f32) 로짓을 기준으로 저장하고 HALF=1(bf16)·2(f16) 의 KLD. 비교용 잡음: 같은 HALF=0 을 -ub 1 로(배치 모양만 다름 — 지난 측정 ub1 vs ub4 ≈0.012).
S=/tmp/claude-1000/-data-parksThink-macos-reversing-claude-code/643ce5c3-138e-406c-bfc6-676a2e96b284/scratchpad/half
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/half-1108; mkdir -p $S
BIN=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp/build-half2/bin; B=parks-zbook@10.99.0.2; BBIN=/home/parks-zbook/engine2n/bin
H5=/data/parksThink/hf-models/qwen38-flash-next-gguf/UD-IQ4_XS-dense4/Qwen3.8-Flash-Next-Q8mix-q8mix-H5.gguf
# GGML_RPC_COMM_OVERLAP=2 as srv-probe.sh: without it the servers take the f32 copy path, not ZC=3 (first try 01:10 measured nothing)
export LD_LIBRARY_PATH=/opt/rocm/lib GGML_RDMA_CHUNK=65536 GGML_RDMA_RX_DEPTH=48 GGML_RDMA_TX_SLOTS=4 LLAMA_TP_FFN_GRAN=32 GGML_CUDA_DISABLE_GRAPHS=1 GGML_RPC_COMM_OVERLAP=2
A=(-m $H5 -f $R/eval/ppl_text.txt -c 512 -b 512 --chunks ${CHUNKS:-4} -ngl 99 -fa on --rpc 10.99.0.2:50052,127.0.0.1:50052 -sm tensor -dev RPC0,RPC1)
scp -q "$BIN/ggml-rpc-server" "$B:$BBIN/" || exit 3
servers() {  # $1 = HALF
  env GGML_RPC_COMM_HALF=$1 "$BIN/ggml-rpc-server" -H 127.0.0.1 -p 50052 > $O/rpc-a-h$1${SUF:-}.log 2>&1 & APID=$!
  ssh -o BatchMode=yes $B "pkill -x ggml-rpc-server; sleep 1; cd $BBIN && LD_LIBRARY_PATH=/opt/rocm/lib GGML_RDMA_RX_DEPTH=48 GGML_RDMA_CHUNK=65536 GGML_RDMA_TX_SLOTS=4 GGML_CUDA_DISABLE_GRAPHS=1 GGML_RPC_COMM_OVERLAP=2 GGML_RPC_COMM_HALF=$1 setsid -f ./ggml-rpc-server -H 10.99.0.2 -p 50052 -c > rpc-server.log 2>&1 < /dev/null"
  sleep 3
}
stop() { kill $APID; ssh -o BatchMode=yes $B "pkill -x ggml-rpc-server"; wait $APID 2>/dev/null; sleep 3; }
servers 0
"$BIN/llama-perplexity" "${A[@]}" -ub 4 --kl-divergence-base $S/kld-h0-ub4${SUF:-}.bin > $O/ppl-h0-ub4-base${SUF:-}.log 2>&1
echo "base h0 ub4 rc=$? $(grep -E 'Final' $O/ppl-h0-ub4-base${SUF:-}.log)"
"$BIN/llama-perplexity" "${A[@]}" -ub 1 --kl-divergence-base $S/kld-h0-ub4${SUF:-}.bin --kl-divergence > $O/kld-h0-ub1-vs-h0-ub4${SUF:-}.log 2>&1
echo "h0 ub1 vs h0 ub4 (noise ref): $(grep -E 'Mean PPL\(Q\)  |Mean    KLD|99.0%   KLD|Maximum KLD|Same top' $O/kld-h0-ub1-vs-h0-ub4${SUF:-}.log | tr -s ' ' | tr '\n' ' ')"
stop
for h in 1 2; do
  servers $h
  "$BIN/llama-perplexity" "${A[@]}" -ub 4 --kl-divergence-base $S/kld-h0-ub4${SUF:-}.bin --kl-divergence > $O/kld-h$h-ub4-vs-h0-ub4${SUF:-}.log 2>&1
  echo "h$h ub4 vs h0 ub4: $(grep -E 'Mean PPL\(Q\)  |Mean    KLD|99.0%   KLD|Maximum KLD|Same top' $O/kld-h$h-ub4-vs-h0-ub4${SUF:-}.log | tr -s ' ' | tr '\n' ' ') | A: $(grep -c 'partials in' $O/rpc-a-h$h${SUF:-}.log) B: $(ssh -o BatchMode=yes $B "grep -c 'partials in' $BBIN/rpc-server.log") zc A: $(grep -c 'zero-copy decode' $O/rpc-a-h$h${SUF:-}.log)"
  stop
done
