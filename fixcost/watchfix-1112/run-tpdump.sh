#!/usr/bin/env bash
# 11-12 03:0x: 2노드 TP 에서 QSA 마스크 덤프 비교(원래 vs LLAMA_QSA_SHORT=2), llama-eval-callback(prefill) — 서버는 prof2node 와 같은 환경, 끝나면 PID 로 내림
set -u
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/watchfix-1112
BIN=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp/build-rocm3/bin
M=/data/parksThink/hf-models/qwen38-flash-next-gguf/UD-IQ4_XS-dense4/Qwen3.8-Flash-Next-Q8mix-q8mix-H5.gguf
B=parks-zbook@10.99.0.2; BBIN=/home/parks-zbook/engine2n/bin
ENV="LD_LIBRARY_PATH=/opt/rocm/lib GGML_RDMA_CHUNK=65536 GGML_RDMA_RX_DEPTH=48 GGML_RDMA_TX_SLOTS=4 GGML_RPC_COMM_OVERLAP=2 GGML_CUDA_DISABLE_GRAPHS=1"
P="${PROMPT:-$(python3 -I -c "import json; d=json.load(open('$R/eval/spec_prompts.json')); print(' '.join(x['text'] for x in d)*2)")}"
for v in ${VARIANTS:-0 2}; do
  scp -q "$BIN/ggml-rpc-server" "$B:$BBIN/" || exit 3
  BP=$(ssh -o BatchMode=yes $B "cd $BBIN && env $ENV setsid -f ./ggml-rpc-server -H 10.99.0.2 -p 50052 -c > rpc-server-tpdump.log 2>&1 < /dev/null; sleep 1; pgrep -nx ggml-rpc-server")
  env $ENV "$BIN/ggml-rpc-server" -H 127.0.0.1 -p 50052 > $O/tpdump-rpc-a-$v.log 2>&1 & AP=$!
  sleep 4
  env LD_LIBRARY_PATH=/opt/rocm/lib LLAMA_TP_FFN_GRAN=32 GGML_RDMA_CHUNK=65536 GGML_RDMA_RX_DEPTH=48 GGML_RDMA_TX_SLOTS=4 LLAMA_QSA_SHORT=$v EVALCB_GEN=${GEN:-0} GGML_META_MIRROR_READ=${MIRROR:-0} \
      LLAMA_DEBUG_DUMP=$O/dump-tp${GEN:-0}${NODUMP:+-nodump}-qsa$v.bin LLAMA_DEBUG_DUMP_RE="${NODUMP:+zzz_no_tensor_matches}${NODUMP:-${DUMPRE:-indexer_sel|indexer_score|indexer_top_k}}" \
      timeout 600 "$BIN/llama-eval-callback" -m $M -fa 1 -c 4096 -n 1 -p "$P" --rpc 10.99.0.2:50052,127.0.0.1:50052 -sm tensor -dev RPC0,RPC1 > $O/tpdump-evalcb-$v.log 2>&1
  echo "v=$v rc=$? dump $(stat -c %s $O/dump-tp${GEN:-0}-qsa$v.bin 2>/dev/null)"
  kill $AP 2>/dev/null; ssh -o BatchMode=yes $B "kill $BP 2>/dev/null; for i in \$(seq 20); do kill -0 $BP 2>/dev/null || exit 0; sleep 1; done; kill -KILL $BP"
  for i in $(seq 20); do kill -0 $AP 2>/dev/null || break; sleep 1; done; kill -KILL $AP 2>/dev/null
  sleep 2
done
python3 -I /tmp/claude-1000/-data-parksThink-macos-reversing-claude-code/643ce5c3-138e-406c-bfc6-676a2e96b284/scratchpad/dumpcmp.py $O/dump-tp${GEN:-0}-qsa0.bin $O/dump-tp${GEN:-0}-qsa2.bin | head -30
grep -h "EVALCB_GEN tokens" $O/tpdump-evalcb-0.log $O/tpdump-evalcb-2.log
echo ALLDONE
