#!/usr/bin/env bash
# 11-11: 같은 회에서 FETCH_SIZE(커널별 GPU L2 밖 읽기)와 DRAM 카운터(노드 전체)를 함께 — rocprofv3 타임스탬프(디코드 첫 GDN ~ 마지막 GDN)
# 구간의 DRAM 바이트를 sample-dram(CLOCK_MONOTONIC)에서 적분해 같은 토큰으로 나눈다. 시간 제한 있음.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll/fixcost/bytes-1111
setsid -f bash -c "echo \$\$ > $O/fetch-df.pid; exec /data/parksThink/inferwatch-iw-20261110-1/target/release/inferwatch sample-dram 900 50 $O/fetch-df-a.txt" > /dev/null 2>&1 < /dev/null; sleep 0.5
PROFARGS="--pmc FETCH_SIZE" timeout 1500 bash $R/tools/bench/prof2node.sh fetchdf 32 > $O/fetch-df-prof.log 2>&1
kill -TERM -- -$(cat $O/fetch-df.pid)
tail -1 $O/fetch-df-prof.log
