#!/usr/bin/env bash
# 11-11 11:0x: dd2 워프당 행 수·적용 범위 바꿔 pp4 프로파일(커널 시간만) — 기준 runs/prof2node-pp4def-1111-105900
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/dd2-1111
DEF=$(ls -1dt $R/runs/prof2node-pp4def-1111* | head -1)
for v in "r21:GGML_CUDA_MOE_DEDUP_R=2,1" "dn2:GGML_CUDA_MOE_DEDUP_R=2,1 GGML_CUDA_MOE_DEDUP_ONLY=down" "dn4:GGML_CUDA_MOE_DEDUP_R=4,1 GGML_CUDA_MOE_DEDUP_ONLY=down"; do
  tag=${v%%:*}; env=${v#*:}
  SRVX="GGML_CUDA_MOE_DEDUP=2 $env" BARGS="-p 4 -n 0 -r 40" timeout 900 bash $R/tools/bench/prof2node.sh pp4$tag > $O/prof-pp4$tag.log 2>&1
  echo "== $tag ($env)"; python3 -I $R/tools/bench/kdiff.py $DEF $(ls -1dt $R/runs/prof2node-pp4$tag-* | head -1) > $O/kdiff-pp4$tag.txt
  head -2 $O/kdiff-pp4$tag.txt | sed 's/.*runs\///'; grep -E "moe" $O/kdiff-pp4$tag.txt
done
echo "== done $(date +%T)"
