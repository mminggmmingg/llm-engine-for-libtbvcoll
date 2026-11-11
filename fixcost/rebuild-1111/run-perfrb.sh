#!/usr/bin/env bash
# 11-12 00:0x: 남은 다시 짓기(클라이언트) 안 — 매 단계 다시 짓게(LLAMA_GRAPH_REUSE_DISABLE=1) 한 MTP 회에서 llama-server 주 스레드를 perf(dwarf 호출 그래프) 40 s.
# 속도 회가 아니라 진단(감시기 없음). perf 원자료는 공개 저장소에 올리지 않는다.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/rebuild-1111
export BENCH_S=900 WATCH=0 CL_prb="LLAMA_GRAPH_REUSE_DISABLE=1"
(
  for i in $(seq 300); do P=$(pgrep -x llama-server | head -1); [ -n "$P" ] && break; sleep 1; done
  [ -z "$P" ] && { echo "no llama-server"; exit 1; }
  for i in $(seq 600); do curl -sf http://127.0.0.1:8077/health > /dev/null && break; sleep 1; done
  sleep 20
  timeout 90 perf record -F 499 --call-graph dwarf,8192 -t $P -o $O/perf-rb.data -- sleep 40 > $O/perf-rb-record.log 2>&1
) &
OUTDIR=rebuild-1111 RUNS="mtp:prb" bash $R/tools/bench/node-ab.sh
wait
perf report -i $O/perf-rb.data --no-children --sort sym --stdio 2>/dev/null | grep -v "^$" | head -70 > $O/perf-rb-self.txt
perf report -i $O/perf-rb.data --children --sort sym --stdio -g none 2>/dev/null | grep -v "^$" | head -90 > $O/perf-rb-children.txt
ls -la $O/perf-rb.data
echo ALLDONE
