#!/usr/bin/env bash
# 11-11 13:1x: 추론 중 클라이언트(llama-server)가 다시 짓기 때 어디서 시간을 쓰는가 — perf record(호출 그래프) 120 s, MTP 한 회
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/ahead-1111
export BENCH_S=600 WATCH=0
(
  for i in $(seq 300); do P=$(pgrep -x llama-server | head -1); [ -n "$P" ] && break; sleep 1; done
  [ -z "$P" ] && { echo "no llama-server"; exit 1; }
  # 모델 적재가 끝날 때까지(health) 기다린 뒤 120 s 기록
  for i in $(seq 600); do curl -sf http://127.0.0.1:8077/health > /dev/null && break; sleep 1; done
  timeout 150 perf record -F 999 -g -p $P -o $O/perf-client.data -- sleep 120 > $O/perf-record.log 2>&1
) &
OUTDIR=ahead-1111 RUNS="mtp:pf" bash $R/tools/bench/node-ab.sh
wait
perf report -i $O/perf-client.data --no-children --sort comm,dso,sym --stdio 2>/dev/null | head -60 > $O/perf-top.txt
perf report -i $O/perf-client.data --no-children --sort sym --stdio -S serialize_graph -G 2>/dev/null | head -80 > $O/perf-serialize.txt
ls -la $O/perf-client.data
