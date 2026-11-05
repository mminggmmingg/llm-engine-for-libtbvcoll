#!/usr/bin/env bash
P=$(dirname "$0"); cd $P
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
RUNS="${RUNS:-none:base none:base none:base}" OUTDIR=${OUTDIR:-nondet-1105} bash node-ab.sh > $P/${LOG:-repro.log} 2>&1 &
sleep 3
bash $P/hogmon.sh > $P/hogmon.log 2>&1
wait
for d in $(grep -o 'srv-2node-[a-z]*-bs-[a-z0-9]*-11[0-9]*-[0-9]*' $P/${LOG:-repro.log}); do
  echo "$d $(python3 -I -c "import json,sys; print(' '.join(json.loads(l)['sha'][:6] for l in open(sys.argv[1])))" $R/runs/$d/results.jsonl 2>&1)"
done
grep TOTAL $P/${LOG:-repro.log} | sed -E 's/ bin=bin load (A=[0-9.]+ B=[0-9.]+).*decode / \1 /; s/ \(token-weighted\).*//'
cat $P/hogmon.log
