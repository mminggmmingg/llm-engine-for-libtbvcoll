#!/usr/bin/env bash
# quality.sh 의 2노드 TP 판(운영 설정, 서버 환경은 srv-probe.sh 와 같음) + 이미 받아들인 반올림 차이와의 비교:
#   TP 끔 로짓 저장 → TP 끔 vs Q8_0, TP 끔 vs 1노드 끔(= TP 자체의 차이), TP S=2 vs Q8_0, TP S=2 vs TP 끔, 1노드 끔 -ub 4 vs 1노드 끔 -ub 1
S=/tmp/claude-1000/-data-parksThink-macos-reversing-claude-code/643ce5c3-138e-406c-bfc6-676a2e96b284/scratchpad
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/splitk-1106/kld; mkdir -p $O
BIN=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp/build-rocm3/bin; B=parks-zbook@10.99.0.2; BBIN=/home/parks-zbook/engine2n/bin
H5=/data/parksThink/hf-models/qwen38-flash-next-gguf/UD-IQ4_XS-dense4/Qwen3.8-Flash-Next-Q8mix-q8mix-H5.gguf
export LD_LIBRARY_PATH=/opt/rocm/lib GGML_RDMA_CHUNK=65536 GGML_RDMA_RX_DEPTH=48 GGML_RDMA_TX_SLOTS=4 GGML_RPC_COMM_OVERLAP=2 LLAMA_TP_FFN_GRAN=32
A=(-f $R/eval/ppl_text.txt -c 512 -b 512 --chunks ${CHUNKS:-4} -ngl 99 -fa on)
TP=(--rpc 10.99.0.2:50052,127.0.0.1:50052 -sm tensor -dev RPC0,RPC1)
sm() { grep -E "Mean PPL\(Q\)  |Mean    KLD|Maximum KLD|99.0%   KLD|RMS Δp|Same top" $1 | tr -s ' ' | tr '\n' ' '; }
up() {   # $1: 두 서버 환경
  env GGML_CUDA_DISABLE_GRAPHS=1 $1 "$BIN/ggml-rpc-server" -H 127.0.0.1 -p 50052 > $O/rpc-a-$2.log 2>&1 & APID=$!
  ssh -o BatchMode=yes $B "pkill -x ggml-rpc-server; sleep 1"; scp -q "$BIN/ggml-rpc-server" "$B:$BBIN/" || exit 3
  ssh -o BatchMode=yes $B "cd $BBIN && LD_LIBRARY_PATH=/opt/rocm/lib GGML_RDMA_RX_DEPTH=48 GGML_RDMA_CHUNK=65536 GGML_RDMA_TX_SLOTS=4 GGML_RPC_COMM_OVERLAP=2 GGML_CUDA_DISABLE_GRAPHS=1 $1 setsid -f ./ggml-rpc-server -H 10.99.0.2 -p 50052 -c > rpc-server.log 2>&1 < /dev/null"
  sleep 3
}
down() { kill $APID; ssh -o BatchMode=yes $B "pkill -x ggml-rpc-server"; wait $APID 2>/dev/null; sleep 5; }
run() {  # $1 이름, $2 서버 환경, 나머지: llama-perplexity 인자
  local n=$1 e=$2; shift 2
  up "$e" $n; "$BIN/llama-perplexity" -m $H5 "${A[@]}" -ub 1 "${TP[@]}" "$@" > $O/$n.log 2>&1; echo "$n rc=$? rdma=$(grep -c 'RDMA activated' $O/rpc-a-$n.log) $(sm $O/$n.log) $(grep -E 'Final' $O/$n.log)"; down
}
[ -f $S/kld-tpoff.bin ] || run tp-off-base "" --kl-divergence-base $S/kld-tpoff.bin
run tp-off-vs-q8     ""                        --kl-divergence-base $S/kld-q8.bin    --kl-divergence
run tp-off-vs-1node  ""                        --kl-divergence-base $S/kld-h5off.bin --kl-divergence
run tp-s2-vs-q8      "GGML_CUDA_MMVQ_SPLITK=2" --kl-divergence-base $S/kld-q8.bin    --kl-divergence
run tp-s2-vs-tpoff   "GGML_CUDA_MMVQ_SPLITK=2" --kl-divergence-base $S/kld-tpoff.bin --kl-divergence
for b in h5off q8; do
  GGML_CUDA_DISABLE_GRAPHS=1 "$BIN/llama-perplexity" -m $H5 "${A[@]}" -ub 4 --kl-divergence-base $S/kld-$b.bin --kl-divergence > $O/h5-off-ub4-vs-$b.log 2>&1
  echo "1node off ub4 vs $b: $(sm $O/h5-off-ub4-vs-$b.log)"
done
