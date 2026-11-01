#!/usr/bin/env bash
# Q8_0 원본(2노드 TP, -ub 512)의 로짓을 KLD 기준으로 저장한 뒤, H5 1노드 켬/끔 × ub 1/4 를 그 기준과 비교
S=/tmp/claude-1000/-data-parksThink-macos-reversing-claude-code/643ce5c3-138e-406c-bfc6-676a2e96b284/scratchpad/pf
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/hcmix-1031/q8ref; mkdir -p $O
BIN=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp/build-rocm3/bin; B=parks-zbook@10.99.0.2; BBIN=/home/parks-zbook/engine2n/bin
Q8=/data/parksThink/hf-models/qwen38-flash-next-gguf/Q8_0/Qwen3.8-Flash-Next-Q8_0-00001-of-00006.gguf
H5=/data/parksThink/hf-models/qwen38-flash-next-gguf/UD-IQ4_XS-dense4/Qwen3.8-Flash-Next-Q8mix-q8mix-H5.gguf
export LD_LIBRARY_PATH=/opt/rocm/lib GGML_RDMA_CHUNK=65536 GGML_RDMA_RX_DEPTH=48 GGML_RDMA_TX_SLOTS=4 LLAMA_TP_FFN_GRAN=32 GGML_CUDA_DISABLE_GRAPHS=1
A=(-f $R/eval/ppl_text.txt -c 512 -b 512 --chunks ${CHUNKS:-4} -ngl 99 -fa on)
if [ ! -f $S/kld-q8.bin ]; then
  "$BIN/ggml-rpc-server" -H 127.0.0.1 -p 50052 > $O/rpc-a.log 2>&1 & APID=$!
  ssh -o BatchMode=yes $B "pkill -x ggml-rpc-server; sleep 1"; scp -q "$BIN/ggml-rpc-server" "$B:$BBIN/" || exit 3
  ssh -o BatchMode=yes $B "cd $BBIN && LD_LIBRARY_PATH=/opt/rocm/lib GGML_RDMA_RX_DEPTH=48 GGML_RDMA_CHUNK=65536 GGML_RDMA_TX_SLOTS=4 GGML_CUDA_DISABLE_GRAPHS=1 setsid -f ./ggml-rpc-server -H 10.99.0.2 -p 50052 -c > rpc-server.log 2>&1 < /dev/null"
  sleep 3
  "$BIN/llama-perplexity" -m $Q8 "${A[@]}" -ub 512 --rpc 10.99.0.2:50052,127.0.0.1:50052 -sm tensor -dev RPC0,RPC1 --kl-divergence-base $S/kld-q8.bin > $O/q8-base.log 2>&1
  echo "q8 base rc=$? $(grep -E 'Final' $O/q8-base.log)"
  kill $APID; ssh -o BatchMode=yes $B "pkill -x ggml-rpc-server"; wait $APID 2>/dev/null; sleep 3
fi
for c in ${LIST:-off-ub4 on-ub4 off-ub1 on-ub1}; do
  E=""; [[ $c == off* ]] && E="GGML_CUDA_NO_HC_MIX=1"; ub=${c##*-ub}
  env $E "$BIN/llama-perplexity" -m $H5 "${A[@]}" -ub $ub --kl-divergence-base $S/kld-q8.bin --kl-divergence > $O/h5-$c${SUF:-}-vs-q8.log 2>&1
  echo "$c vs q8: $(grep -E "Mean PPL\(Q\)  |Mean    KLD|99.0%   KLD|Same top" $O/h5-$c${SUF:-}-vs-q8.log | tr -s ' ' | tr '\n' ' ')"
done
