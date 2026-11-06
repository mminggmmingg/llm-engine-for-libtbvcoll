#!/usr/bin/env bash
# 답변 비교: 2노드 TP(MTP 없음 — MTP 검증은 여러 토큰 묶음이라 split-K 를 타지 않음)로 18개 프롬프트(벤치 6 + holdout 12)를
# 최대 2048 토큰 greedy 생성, split-K 끔(aoff) / 켬 S=2(as2). 처음 갈린 자리와 정답이 정해진 문항의 채점을 남긴다.
S=/tmp/claude-1000/-data-parksThink-macos-reversing-claude-code/643ce5c3-138e-406c-bfc6-676a2e96b284/scratchpad/pf
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; F=$R/fixcost/splitk-1106
python3 -I -c "import json; a=json.load(open('$R/eval/spec_prompts.json'))+json.load(open('$R/eval/draft_vocab_holdout.json')); json.dump(a, open('$F/answers_prompts.json','w'), ensure_ascii=False, indent=1)"
cd $S && OUTDIR=splitk-1106 TRACE=0 RUNS="none:aoff none:as2" SA_as2="GGML_CUDA_MMVQ_SPLITK=2" SB_as2="GGML_CUDA_MMVQ_SPLITK=2" \
  BENCH="tools/divergence.py $F/answers_prompts.json ${NMAX:-2048} {OUT}/div.jsonl" bash node-ab.sh 2>&1 | grep -v '^ [ab]:' > $F/answers.log
for c in aoff as2; do d=$(ls -td $R/runs/srv-2node-none-bs-$c-* | head -1); cp $d/div.jsonl $F/answers-$c.jsonl; done
python3 -I $R/tools/divergence.py diff $F/answers-aoff.jsonl $F/answers-as2.jsonl > $F/answers-divergence.txt
python3 -I $F/check_answers.py $F/answers-aoff.jsonl $F/answers-as2.jsonl > $F/answers-check.txt
cat $F/answers-check.txt
