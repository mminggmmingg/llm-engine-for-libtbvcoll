#!/usr/bin/env bash
# 11-11: 4토큰 묶음 단계(MTP 검증과 같은 -p 4) A 커널 기록 — 새 바이너리와 예전 바이너리(bin-1109-2242), 단계당 커널 수·빈 시간
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
for b in bin bin-1109-2242; do
  BIN=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp/build-rocm3/$b BARGS="-p 4 -n 0 -r 30" timeout 900 bash $R/tools/bench/prof2node.sh pp4-$b 2>&1 | tail -2
done
