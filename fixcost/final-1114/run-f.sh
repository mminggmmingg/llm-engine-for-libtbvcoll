#!/usr/bin/env bash
# 11-14 07:1x: 밤 작업 최종 빌드(전용 배열 + MTP 64k 전환·헤드 건너뛰기, mmvq 기본 되돌림) 확인 — none·MTP 6 프롬프트 해시·속도(진단, 감시기 없음).
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
export SA_f="" SB_f=""
BENCH_S=600 WATCH=0 OUTDIR=final-1114 RUNS="none:f mtp:f" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1tr $R/fixcost/final-1114/srv-2node-*-bs-f-1114-*-bench.txt | tail -2)
echo ALLDONE
