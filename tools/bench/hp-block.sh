#!/usr/bin/env bash
# hot 폴링 A/B 한 덩어리: hp-block.sh <tag>  — 디코드·MTP 번갈아 2회씩 + pp512(llama-bench 3회). 결과 fixcost/hotpoll-ab-1102/
S=/tmp/claude-1000/-data-parksThink-macos-reversing-claude-code/643ce5c3-138e-406c-bfc6-676a2e96b284/scratchpad/pf; cd $S
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/hotpoll-ab-1102; mkdir -p $O
tag=${1:?tag}
echo "== $tag $(date +%T) $($R/tools/tbv_hotpoll.sh status | tr '\n' ' ')"
OUTDIR=hotpoll-ab-1102 RUNS="none:base mtp:base none:base mtp:base" bash node-ab.sh 2>&1 | sed "s/^/[$tag] /"
r=$(timeout 900 bash tp-bench-x.sh "-p 512 -n 0 -r 3" | tail -1); cp tpb-client.log $O/pp512-$tag-client.log
echo "[$tag] pp512: $(echo "$r" | awk -F'|' '{print $(NF-1)}')"
echo "== $tag done $(date +%T)"
