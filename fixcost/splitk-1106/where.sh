#!/usr/bin/env bash
# 한 층 안에서 어디서 커지나: 같은 글 앞 40바이트(토큰 ≈9개)를 -ub 1 로, 0–2층의 모든 텐서를 덤프(이름 끝이 -0/-1/-2), split-K 끔 vs S=2.
# 덤프한 텐서마다 그래프가 끊겨 이 층들에서는 묶기(fusion)가 풀린다 — 두 실행 모두 같은 조건.
S=/tmp/claude-1000/-data-parksThink-macos-reversing-claude-code/643ce5c3-138e-406c-bfc6-676a2e96b284/scratchpad
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/splitk-1106/layers; mkdir -p $O
BIN=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp/build-rocm3/bin
H5=/data/parksThink/hf-models/qwen38-flash-next-gguf/UD-IQ4_XS-dense4/Qwen3.8-Flash-Next-Q8mix-q8mix-H5.gguf
export LD_LIBRARY_PATH=/opt/rocm/lib GGML_CUDA_DISABLE_GRAPHS=1
head -c 40 $R/eval/ppl_text.txt > $S/wh-prompt.txt
for c in off s2; do
  k=${c#s}; [ $c = off ] && k=0
  env GGML_CUDA_MMVQ_SPLITK=$k LLAMA_DEBUG_DUMP=$S/wh-$c.bin LLAMA_DEBUG_DUMP_RE='-[0-2]$' "$BIN/llama-eval-callback" -m $H5 -ngl 99 -fa on \
    -c 256 -b 256 -ub 1 -f $S/wh-prompt.txt > $O/wh-$c.log 2>&1
  echo "$c rc=$? $(ls -la $S/wh-$c.bin | awk '{print $5}') bytes"
done
for p in 0 1 4; do python3 -I $R/tools/layerdiff.py ops $S/wh-off.bin $S/wh-s2.bin $p > $O/where-pos$p.txt; done
# 같은 149토큰 글에서 모든 층의 전문가 선택(ffn_moe_topk)만 덤프: 라우팅이 어디서 뒤바뀌는지
for c in off s2; do
  k=${c#s}; [ $c = off ] && k=0
  env GGML_CUDA_MMVQ_SPLITK=$k LLAMA_DEBUG_DUMP=$S/tk-$c.bin LLAMA_DEBUG_DUMP_RE='ffn_moe_topk-[0-9]+$' "$BIN/llama-eval-callback" -m $H5 -ngl 99 -fa on \
    -c 1024 -b 1024 -ub 1 -f $S/ld-prompt.txt > $O/tk-$c.log 2>&1
  echo "topk $c rc=$?"
done
python3 -I $R/tools/layerdiff.py topk $S/tk-off.bin $S/tk-s2.bin > $O/topk-off-vs-s2.txt; tail -1 $O/topk-off-vs-s2.txt
# 대조: split-K 끔 그대로 -ub 4(4토큰씩 — 이미 받아들이는 다른 반올림 순서, 1노드 KLD 0.012)와 -ub 1 의 층별 차이
env GGML_CUDA_MMVQ_SPLITK=0 LLAMA_DEBUG_DUMP=$S/ld-ub4.bin "$BIN/llama-eval-callback" -m $H5 -ngl 99 -fa on -c 1024 -b 1024 -ub 4 \
  -f $S/ld-prompt.txt > $O/ld-ub4.log 2>&1
echo "ub4 rc=$?"
python3 -I $R/tools/layerdiff.py $S/ld-off.bin $S/ld-ub4.bin 0,1,8,32,64,last > $O/off-vs-ub4.txt; tail -1 $O/off-vs-ub4.txt
