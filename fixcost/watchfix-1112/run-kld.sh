#!/usr/bin/env bash
# 11-12 05:3x: LLAMA_QSA_SHORT 품질 — Q8_0 원본(2노드 TP, -ub 4) logits 를 KLD 기준으로 다시 만들고(10-31 의 /tmp 기준은 재부팅으로 사라짐),
# H5 끔/켬을 그 기준과 비교. 예전 방법(fixcost/hcmix-1031/q8ref2.sh): ppl_text 4청크 × 512, -ub 4. 서버는 PID 로 내림. 기준 파일은 커밋하지 않음(≈1 GB).
set -u
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/watchfix-1112
BIN=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp/build-rocm3/bin; B=parks-zbook@10.99.0.2; BBIN=/home/parks-zbook/engine2n/bin
Q8=/data/parksThink/hf-models/qwen38-flash-next-gguf/Q8_0/Qwen3.8-Flash-Next-Q8_0-00001-of-00006.gguf
H5=/data/parksThink/hf-models/qwen38-flash-next-gguf/UD-IQ4_XS-dense4/Qwen3.8-Flash-Next-Q8mix-q8mix-H5.gguf
export LD_LIBRARY_PATH=/opt/rocm/lib GGML_RDMA_CHUNK=65536 GGML_RDMA_RX_DEPTH=48 GGML_RDMA_TX_SLOTS=4 LLAMA_TP_FFN_GRAN=32 GGML_CUDA_DISABLE_GRAPHS=1
A=(-f $R/eval/ppl_text.txt -c 512 -b 512 --chunks 4 -ngl 99 -fa on -ub 4 --rpc 10.99.0.2:50052,127.0.0.1:50052 -sm tensor -dev RPC0,RPC1)
BASE=$O/kld-q8-ub4.bin
start() {
  scp -q "$BIN/ggml-rpc-server" "$B:$BBIN/" || exit 3
  BP=$(ssh -o BatchMode=yes $B "cd $BBIN && LD_LIBRARY_PATH=/opt/rocm/lib GGML_RDMA_RX_DEPTH=48 GGML_RDMA_CHUNK=65536 GGML_RDMA_TX_SLOTS=4 GGML_CUDA_DISABLE_GRAPHS=1 setsid -f ./ggml-rpc-server -H 10.99.0.2 -p 50052 -c > rpc-server-kld.log 2>&1 < /dev/null; sleep 1; pgrep -nx ggml-rpc-server")
  "$BIN/ggml-rpc-server" -H 127.0.0.1 -p 50052 > $O/kld-rpc-a.log 2>&1 & AP=$!
  sleep 4
}
stop() {
  kill $AP 2>/dev/null; ssh -o BatchMode=yes $B "kill $BP 2>/dev/null; for i in \$(seq 30); do kill -0 $BP 2>/dev/null || exit 0; sleep 1; done; kill -KILL $BP"
  for i in $(seq 30); do kill -0 $AP 2>/dev/null || break; sleep 1; done; kill -KILL $AP 2>/dev/null; sleep 2
}
start
if [ ! -f $BASE ]; then
  timeout 1800 "$BIN/llama-perplexity" -m $Q8 "${A[@]}" --kl-divergence-base $BASE > $O/kld-q8-base.log 2>&1
  echo "q8 base rc=$? $(grep -E 'Final' $O/kld-q8-base.log)"
fi
for v in 0 1; do
  LLAMA_QSA_SHORT=$v timeout 1800 "$BIN/llama-perplexity" -m $H5 "${A[@]}" --kl-divergence-base $BASE --kl-divergence > $O/kld-h5-qsa$v.log 2>&1
  echo "H5 QSA_SHORT=$v rc=$?: $(grep -E 'Mean PPL\(Q\)  |Mean PPL\(base\)|Mean    KLD|99.0%   KLD|Same top' $O/kld-h5-qsa$v.log | tr -s ' ' | tr '\n' ' ')"
done
stop
echo ALLDONE
