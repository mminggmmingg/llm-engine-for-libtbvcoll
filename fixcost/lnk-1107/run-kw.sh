#!/usr/bin/env bash
# one base none run with kworker burst logging on both nodes (sampler pinned to CPU 20, away from the TB IRQ CPUs)
S=/tmp/claude-1000/-data-parksThink-macos-reversing-claude-code/643ce5c3-138e-406c-bfc6-676a2e96b284/scratchpad/lnk
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
B=parks-zbook@10.99.0.2
scp -q $S/kwburst.py $B:/tmp/kwburst.py
taskset -c 20 python3 -I $S/kwburst.py 230 2 $S/kw-A.txt &
ssh -o BatchMode=yes $B "taskset -c 20 python3 -I /tmp/kwburst.py 230 2 /tmp/kw-B.txt" &
OUTDIR=lnk-1107 RUNS="none:base" bash $R/tools/bench/node-ab.sh
wait
scp -q $B:/tmp/kw-B.txt $S/kw-B.txt
wc -l $S/kw-A.txt $S/kw-B.txt
