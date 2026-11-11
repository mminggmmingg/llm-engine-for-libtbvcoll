#!/usr/bin/env bash
# 11-11 11:3x: 초안 출력층만 더 작게 — 기본 qmix(출력층 Q4_K 143 MB) / h3(Q3_K 110 MB) / hx(IQ4_XS ≈136 MB), 번갈아 2바퀴
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/dhead-1111; M=/data/parksThink/hf-models/qwen38-flash-next-gguf/MTP
export BENCH_S=600 WATCH=0
export MTP_h3=$M/mtp-Qwen3.8-Flash-Next-merged-IQ4embd-dv96k-ko-qmix-h3.gguf MTP_hx=$M/mtp-Qwen3.8-Flash-Next-merged-IQ4embd-dv96k-ko-qmix-hx.gguf
OUTDIR=dhead-1111 RUNS="${RUNS:-mtp:h3 mtp:def mtp:hx mtp:h3 mtp:def mtp:hx}" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bench.txt | head -6)
for d in $(ls -td $R/runs/srv-2node-mtp-bs-h3-1111* $R/runs/srv-2node-mtp-bs-hx-1111* $R/runs/srv-2node-mtp-bs-def-1111* | head -12); do python3 -c "
import json; n=a=0
for l in open('$d/results.jsonl'):
    j=json.loads(l); n+=j['draft_n']; a+=j['draft_acc']
print('$d'.split('/')[-1], n, a, round(a/n,3))" 2>/dev/null; done | sort | tail -8
sha256sum $MTP_h3 $MTP_hx
