#!/usr/bin/env bash
# 16-bit AR 2단계: KLD 다시(ZC=3 경로, SUF=-zc) → MTP A/B(h0 / bf, 2바퀴 + 감시기 회)
D=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll/fixcost/half-1108
SUF=-zc bash $D/kld-half.sh > $D/kld-half-zc.log 2>&1
cat $D/kld-half-zc.log
RUNS="${MTP_RUNS:-mtp:h0 mtp:bf mtp:h0 mtp:bf}" bash $D/ab-half.sh > $D/ab-half-mtp.log 2>&1
grep -v '^   [ab]:' $D/ab-half-mtp.log | grep -v '^\s*$' | tail -12
