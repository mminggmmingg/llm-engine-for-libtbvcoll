#!/usr/bin/env bash
# 11-11: 초안 어휘 80k + 한글(K=81920) 판 만들기 — 11-06 dv96k-ko-qmix 와 같은 절차(README "초안 어휘"), 말뭉치·qmix 형식 그대로
set -e
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; M=/data/parksThink/hf-models/qwen38-flash-next-gguf/MTP; O=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll/fixcost/dvocab-1111
cd $R
python3 -I tools/draft_vocab_select.py fixcost/dvocab-1106/corpus-tokens.jsonl 81920 $M/mtp-Qwen3.8-Flash-Next-merged-IQ4embd.gguf $O/ids-80k-ko.txt ko
wc -l $O/ids-80k-ko.txt
python3 -I tools/gguf_draft_vocab.py $M/mtp-Qwen3.8-Flash-Next-merged-IQ4embd.gguf $O/ids-80k-ko.txt $M/mtp-Qwen3.8-Flash-Next-merged-IQ4embd-dv80k-ko.gguf
timeout 1800 /data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp/build-rocm3/bin/llama-quantize --allow-requantize --pure --tensor-type-file fixcost/dvocab-1106/draft-qmix.types \
    $M/mtp-Qwen3.8-Flash-Next-merged-IQ4embd-dv80k-ko.gguf $M/mtp-Qwen3.8-Flash-Next-merged-IQ4embd-dv80k-ko-qmix.gguf Q8_0 > $O/quant-qmix.log 2>&1
ls -la $M/mtp-Qwen3.8-Flash-Next-merged-IQ4embd-dv80k-ko*.gguf; sha256sum $M/mtp-Qwen3.8-Flash-Next-merged-IQ4embd-dv80k-ko-qmix.gguf
