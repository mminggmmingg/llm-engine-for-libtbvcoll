#!/usr/bin/env bash
# 층별로 차이가 어떻게 커지는지: H5 1노드, 같은 글 앞 600바이트를 -ub 1(토큰 하나씩, split-K 가 타는 한 열 경로)로 넣고
# 층 출력(l_last-<층>)과 마지막 로짓을 덤프(LLAMA_DEBUG_DUMP, common/debug.cpp)해 split-K 끔 vs 끔(결정성 대조)·끔 vs S=2·4·8 비교.
S=/tmp/claude-1000/-data-parksThink-macos-reversing-claude-code/643ce5c3-138e-406c-bfc6-676a2e96b284/scratchpad
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/splitk-1106/layers; mkdir -p $O
BIN=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp/build-rocm3/bin
H5=/data/parksThink/hf-models/qwen38-flash-next-gguf/UD-IQ4_XS-dense4/Qwen3.8-Flash-Next-Q8mix-q8mix-H5.gguf
export LD_LIBRARY_PATH=/opt/rocm/lib GGML_CUDA_DISABLE_GRAPHS=1
head -c 600 $R/eval/ppl_text.txt > $S/ld-prompt.txt
for c in ${LIST:-off off2 s2 s4 s8}; do
  k=${c#s}; [[ $c == off* ]] && k=0
  env GGML_CUDA_MMVQ_SPLITK=$k LLAMA_DEBUG_DUMP=$S/ld-$c.bin "$BIN/llama-eval-callback" -m $H5 -ngl 99 -fa on -c 1024 -b 1024 -ub 1 \
    -f $S/ld-prompt.txt > $O/ld-$c.log 2>&1
  echo "$c rc=$? $(ls -la $S/ld-$c.bin | awk '{print $5}') bytes"
done
for c in off2 s2 s4 s8; do
  python3 -I $R/tools/layerdiff.py $S/ld-off.bin $S/ld-$c.bin 0,1,8,32,64,last > $O/off-vs-$c.txt
done
cat $O/off-vs-off2.txt | tail -3; cat $O/off-vs-s2.txt
