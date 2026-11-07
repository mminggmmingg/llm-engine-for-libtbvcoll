#!/usr/bin/env bash
# hot 폴링 A/B 한 덩어리: hp-block.sh <tag>  — 디코드·MTP 번갈아 2회씩 + pp512(llama-bench 3회). 결과 fixcost/${HP_OUT:-hotpoll-ab-1102}/
cd "$(dirname "$(readlink -f "$0")")"   # tools/bench 에서(srv-probe.sh·gmsum.py·profsum.py 옆). 예전에는 세션 scratchpad 의 사본 pf/
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; HP_OUT=${HP_OUT:-hotpoll-ab-1102}; O=$R/fixcost/$HP_OUT; mkdir -p $O
tag=${1:?tag}
echo "== $tag $(date +%T) $($R/tools/tbv_hotpoll.sh status | tr '\n' ' ')"
OUTDIR=$HP_OUT RUNS="none:base mtp:base none:base mtp:base" bash node-ab.sh 2>&1 | sed "s/^/[$tag] /"
r=$(timeout 900 bash tp-bench-x.sh "-p 512 -n 0 -r 3" | tail -1); cp tpb-client.log $O/pp512-$tag-client.log
echo "[$tag] pp512: $(echo "$r" | awk -F'|' '{print $(NF-1)}')"
echo "== $tag done $(date +%T)"
