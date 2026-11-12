#!/usr/bin/env bash
# 11-13 02:1x: 짧은 문맥 MTP 가 11-12 낮보다 ≈3% 낮고, 감시기로 초안 단계가 2.3 → 2.9 ms. 서버 쪽 끄기 A/B(run-mtpab)는 차이 없음 →
#   클라이언트의 초안 백엔드 샘플링 top-10(어휘 104,459열 1행)이 한 블록 top-k 로 간 탓으로 보고, 한 블록을 열 65,536 이하(QSA 풀)로 제한한 빌드(bin)를
#   고치기 전 빌드(bin-1113-pre)와 번갈아. 긴 문맥 인덱서 top-k 는 열 ≤ 65,536 이라 그대로.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/longctx-1112
export SA_fix="" SB_fix="" SA_pre="" SB_pre="" BIN_pre=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp/build-rocm3/bin-1113-pre
BENCH_S=600 WATCH=1 OUTDIR=longctx-1112 RUNS="mtp:fix mtp:pre mtp:pre mtp:fix none:fix" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1tr $O/srv-2node-*-fix*-1113-*-bench.txt $O/srv-2node-*-pre*-1113-*-bench.txt | sort -u)
echo ALLDONE
