#!/usr/bin/env bash
# Q8_0 기준 두 개(-ub 4, 2노드): hc 를 q8_1(묶기 끔)로 / f32(묶기 켬 + GGML_CUDA_HC_MIX_F32) 로 계산. H5 끔·f32 를 둘 다와 비교
S=/tmp/claude-1000/-data-parksThink-macos-reversing-claude-code/643ce5c3-138e-406c-bfc6-676a2e96b284/scratchpad/pf
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/hcmix-1031/q8ref2; mkdir -p $O
BIN=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp/build-rocm3/bin; B=parks-zbook@10.99.0.2; BBIN=/home/parks-zbook/engine2n/bin
Q8=/data/parksThink/hf-models/qwen38-flash-next-gguf/Q8_0/Qwen3.8-Flash-Next-Q8_0-00001-of-00006.gguf
H5=/data/parksThink/hf-models/qwen38-flash-next-gguf/UD-IQ4_XS-dense4/Qwen3.8-Flash-Next-Q8mix-q8mix-H5.gguf
export LD_LIBRARY_PATH=/opt/rocm/lib GGML_RDMA_CHUNK=65536 GGML_RDMA_RX_DEPTH=48 GGML_RDMA_TX_SLOTS=4 LLAMA_TP_FFN_GRAN=32 GGML_CUDA_DISABLE_GRAPHS=1
A=(-f $R/eval/ppl_text.txt -c 512 -b 512 --chunks 4 -ngl 99 -fa on -ub 4)
scp -q "$BIN/ggml-rpc-server" "$B:$BBIN/" || exit 3
for base in q81 f32; do
  [ -f $S/kld-q8-ub4-$base.bin ] && continue
  if [ $base = q81 ]; then E="GGML_CUDA_NO_HC_MIX=1"; else E="GGML_CUDA_HC_MIX_F32=1"; fi
  env $E "$BIN/ggml-rpc-server" -H 127.0.0.1 -p 50052 > $O/rpc-a-$base.log 2>&1 & APID=$!
  ssh -o BatchMode=yes $B "pkill -x ggml-rpc-server; sleep 1; cd $BBIN && LD_LIBRARY_PATH=/opt/rocm/lib GGML_RDMA_RX_DEPTH=48 GGML_RDMA_CHUNK=65536 GGML_RDMA_TX_SLOTS=4 GGML_CUDA_DISABLE_GRAPHS=1 $E setsid -f ./ggml-rpc-server -H 10.99.0.2 -p 50052 -c > rpc-server.log 2>&1 < /dev/null"
  sleep 3
  env $E "$BIN/llama-perplexity" -m $Q8 "${A[@]}" --rpc 10.99.0.2:50052,127.0.0.1:50052 -sm tensor -dev RPC0,RPC1 --kl-divergence-base $S/kld-q8-ub4-$base.bin > $O/q8-base-$base.log 2>&1
  echo "q8 base $base rc=$? $(grep -E 'Final' $O/q8-base-$base.log) fused-a=$(grep -c 'fused hc mix' $O/rpc-a-$base.log)"
  kill $APID; ssh -o BatchMode=yes $B "pkill -x ggml-rpc-server"; wait $APID 2>/dev/null; sleep 3
done
for h in off f32; do
  if [ $h = off ]; then E="GGML_CUDA_NO_HC_MIX=1"; else E="GGML_CUDA_HC_MIX_F32=1"; fi
  for base in q81 f32; do
    env $E "$BIN/llama-perplexity" -m $H5 "${A[@]}" --kl-divergence-base $S/kld-q8-ub4-$base.bin --kl-divergence > $O/h5-$h-vs-q8$base.log 2>&1
    echo "H5 $h vs Q8-$base: $(grep -E 'Mean PPL\(Q\)  |Mean PPL\(base\)|Mean    KLD|Same top' $O/h5-$h-vs-q8$base.log | tr -s ' ' | tr '\n' ' ')"
  done
done
