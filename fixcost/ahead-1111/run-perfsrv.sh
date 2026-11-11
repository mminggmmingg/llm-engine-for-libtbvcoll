#!/usr/bin/env bash
# 11-11 16:3x: A rpc-server 의 새 그래프 처리(첫 발행 265–360 µs)가 어디서 시간을 쓰는가 — perf record(호출 그래프) 90 s, MTP 한 회
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/ahead-1111
export BENCH_S=600 WATCH=0
(
  for i in $(seq 600); do curl -sf http://127.0.0.1:8077/health > /dev/null && break; sleep 1; done
  P=$(pgrep -x ggml-rpc-server | head -1); [ -z "$P" ] && exit 1
  timeout 120 perf record -F 1999 -g -p $P -o $O/perf-srv.data -- sleep 90 > $O/perf-srv-record.log 2>&1
) &
OUTDIR=ahead-1111 RUNS="mtp:ps" bash $R/tools/bench/node-ab.sh
wait
