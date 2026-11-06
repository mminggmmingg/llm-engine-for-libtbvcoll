#!/usr/bin/env bash
# where.sh 를 운영과 같은 split-K 범위로: 덤프 때문에 묶기가 풀리면 shared expert gate/up(640행)처럼 운영에서는 묶여 split-K 가
# 안 걸리는 행렬곱에도 걸린다 → GGML_CUDA_MMVQ_SPLITK_ROWS=324(1노드에서 hc down + inject 324행·출력 hc down 320행만). 0–5층 모든 텐서.
S=/tmp/claude-1000/-data-parksThink-macos-reversing-claude-code/643ce5c3-138e-406c-bfc6-676a2e96b284/scratchpad
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/splitk-1106/layers
BIN=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp/build-rocm3/bin; GP=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp/gguf-py
H5=/data/parksThink/hf-models/qwen38-flash-next-gguf/UD-IQ4_XS-dense4/Qwen3.8-Flash-Next-Q8mix-q8mix-H5.gguf
export LD_LIBRARY_PATH=/opt/rocm/lib GGML_CUDA_DISABLE_GRAPHS=1
for c in off s2r; do
  k=2; [ $c = off ] && k=0
  env GGML_CUDA_MMVQ_SPLITK=$k GGML_CUDA_MMVQ_SPLITK_ROWS=324 LLAMA_DEBUG_DUMP=$S/wh2-$c.bin LLAMA_DEBUG_DUMP_RE='-[0-5]$' "$BIN/llama-eval-callback" -m $H5 \
    -ngl 99 -fa on -c 256 -b 256 -ub 1 -f $S/wh-prompt.txt > $O/wh2-$c.log 2>&1
  echo "where2 $c rc=$? $(ls -la $S/wh2-$c.bin | awk '{print $5}') bytes"
done
for p in 0 1 4; do
  python3 -I $R/tools/layerdiff.py ops $S/wh2-off.bin $S/wh2-s2r.bin $p > $O/where2-pos$p.txt
  python3 -I $R/fixcost/splitk-1106/amplify.py $GP flips $S/wh2-off.bin $S/wh2-s2r.bin $p > $O/where2-flips-pos$p.txt
done
grep -E "^l_last" $O/where2-pos0.txt
