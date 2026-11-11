#!/usr/bin/env bash
# 11-11 13:2x: 추론 중 A 의 스레드별 CPU 점유(어느 스레드가 CPU 를 붙들고 도는가) — MTP 한 회, 벤치 시작 30 s 뒤 top -H 두 번(5 s)
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/ahead-1111
export BENCH_S=600 WATCH=0
(
  for i in $(seq 600); do curl -sf http://127.0.0.1:8077/health > /dev/null && break; sleep 1; done
  sleep 25
  top -H -b -d 5 -n 2 -w 200 | awk '/^top -/{n++} n==2' | head -45 > $O/top-threads.txt
  ps -eLo pid,tid,psr,stat,comm,pcpu --sort=-pcpu | head -40 > $O/ps-threads.txt
  cat /proc/loadavg >> $O/ps-threads.txt
) &
OUTDIR=ahead-1111 RUNS="mtp:th" bash $R/tools/bench/node-ab.sh
wait
