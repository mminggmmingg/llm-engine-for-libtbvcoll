#!/usr/bin/env bash
# split-K(GGML_CUDA_MMVQ_SPLITK) 품질: H5 1노드 -ub 1(한 토큰씩 → 한 열 mmvq 경로를 탐) 로짓을
#   (1) Q8_0 원본(2노드 TP, -ub 512) 로짓 기준 KLD — 품질이 나빠지는지
#   (2) 같은 H5 split-K 끔 로짓 기준 KLD — split-K 자체가 얼마나 바꾸는지(끔 vs 끔 = 16비트 저장 바닥)
# 와 비교한다. 기준 로짓 파일은 scratchpad(tmpfs)에 둔다.
S=/tmp/claude-1000/-data-parksThink-macos-reversing-claude-code/643ce5c3-138e-406c-bfc6-676a2e96b284/scratchpad
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/splitk-1106/kld; mkdir -p $O
BIN=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp/build-rocm3/bin; B=parks-zbook@10.99.0.2; BBIN=/home/parks-zbook/engine2n/bin
Q8=/data/parksThink/hf-models/qwen38-flash-next-gguf/Q8_0/Qwen3.8-Flash-Next-Q8_0-00001-of-00006.gguf
H5=/data/parksThink/hf-models/qwen38-flash-next-gguf/UD-IQ4_XS-dense4/Qwen3.8-Flash-Next-Q8mix-q8mix-H5.gguf
export LD_LIBRARY_PATH=/opt/rocm/lib GGML_RDMA_CHUNK=65536 GGML_RDMA_RX_DEPTH=48 GGML_RDMA_TX_SLOTS=4 GGML_CUDA_DISABLE_GRAPHS=1
A=(-f $R/eval/ppl_text.txt -c 512 -b 512 --chunks ${CHUNKS:-4} -ngl 99 -fa on)
sm() { grep -E "Mean PPL\(Q\)  |Mean    KLD|Maximum KLD|99.0%   KLD|RMS Δp|Same top" $1 | tr -s ' ' | tr '\n' ' '; }
if [ ! -f $S/kld-q8.bin ]; then
  "$BIN/ggml-rpc-server" -H 127.0.0.1 -p 50052 > $O/rpc-a.log 2>&1 & APID=$!
  ssh -o BatchMode=yes $B "pkill -x ggml-rpc-server; sleep 1"; scp -q "$BIN/ggml-rpc-server" "$B:$BBIN/" || exit 3
  ssh -o BatchMode=yes $B "cd $BBIN && LD_LIBRARY_PATH=/opt/rocm/lib GGML_RDMA_RX_DEPTH=48 GGML_RDMA_CHUNK=65536 GGML_RDMA_TX_SLOTS=4 GGML_CUDA_DISABLE_GRAPHS=1 setsid -f ./ggml-rpc-server -H 10.99.0.2 -p 50052 -c > rpc-server.log 2>&1 < /dev/null"
  sleep 3
  "$BIN/llama-perplexity" -m $Q8 "${A[@]}" -ub 512 --rpc 10.99.0.2:50052,127.0.0.1:50052 -sm tensor -dev RPC0,RPC1 --kl-divergence-base $S/kld-q8.bin > $O/q8-base.log 2>&1
  echo "q8 base rc=$? $(grep -E 'Final' $O/q8-base.log)"
  kill $APID; ssh -o BatchMode=yes $B "pkill -x ggml-rpc-server"; wait $APID 2>/dev/null; sleep 3
fi
if [ ! -f $S/kld-h5off.bin ]; then
  "$BIN/llama-perplexity" -m $H5 "${A[@]}" -ub 1 --kl-divergence-base $S/kld-h5off.bin > $O/h5-off-base.log 2>&1
  echo "h5 off base rc=$? $(grep -E 'Final' $O/h5-off-base.log)"
fi
for c in ${LIST:-off s2 s4 s8}; do
  E="GGML_CUDA_MMVQ_SPLITK=0"; [ $c != off ] && E="GGML_CUDA_MMVQ_SPLITK=${c#s}"
  env $E "$BIN/llama-perplexity" -m $H5 "${A[@]}" -ub 1 --kl-divergence-base $S/kld-q8.bin --kl-divergence > $O/h5-$c-vs-q8.log 2>&1
  echo "$c vs q8: $(sm $O/h5-$c-vs-q8.log)"
  env $E ${VERIFY:+GGML_CUDA_MMVQ_SPLITK_VERIFY=1} "$BIN/llama-perplexity" -m $H5 "${A[@]}" -ub 1 --kl-divergence-base $S/kld-h5off.bin --kl-divergence > $O/h5-$c-vs-off.log 2>&1
  echo "$c vs off: $(sm $O/h5-$c-vs-off.log)"
done
