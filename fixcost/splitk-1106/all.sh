#!/usr/bin/env bash
# split-K 정리 실험 차례: 층별 덤프(1노드) → 답변 비교(2노드) → KLD/PPL(Q8_0 기준 2노드 + H5 1노드)
F=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll/fixcost/splitk-1106
echo "== layers $(date +%T)"; bash $F/layers.sh
echo "== answers $(date +%T)"; bash $F/answers.sh
echo "== quality $(date +%T)"; VERIFY=1 bash $F/quality.sh
echo "== done $(date +%T)"
