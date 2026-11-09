#!/usr/bin/env bash
# 11-09 밤: MTP 검증 4토큰의 전문가 중복 읽기 없애기(GGML_CUDA_MOE_DEDUP=1) — 검사 회 → MTP dd/def 번갈아 3바퀴 + 감시기 → pp4 프로파일 켬/끔
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/mtpv-1109
V="GGML_CUDA_MOE_DEDUP=1 GGML_CUDA_MOE_DEDUP_VERIFY=1"
export SA_dv="$V" SB_dv="$V" SA_dd="GGML_CUDA_MOE_DEDUP=1" SB_dd="GGML_CUDA_MOE_DEDUP=1"
cd $O
WATCH=0 OUTDIR=mtpv-1109 RUNS="mtp:dv" bash $R/tools/bench/node-ab.sh
d=$(ls -1dt $R/runs/srv-2node-mtp-bs-dv-* | head -1)
for x in a b; do
  echo "verify $x: $(grep -c 'moe dedup verify' $d/rpc-$x.log) lines, nonzero $(grep 'moe dedup verify' $d/rpc-$x.log | grep -vc ': 0 of')"
  grep -m2 'moe dedup verify' $d/rpc-$x.log; grep 'moe dedup verify' $d/rpc-$x.log | grep -v ': 0 of' | head -3
done
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-mtp-bs-dv-*-bench.txt | head -1)
if [ "$(grep -h 'moe dedup verify' $d/rpc-a.log $d/rpc-b.log | grep -vc ': 0 of')" != 0 ] || [ "$(grep -hc 'moe dedup verify' $d/rpc-a.log)" = 0 ]; then echo "verify failed or not used: stop"; exit 1; fi
OUTDIR=mtpv-1109 RUNS="mtp:dd mtp:def mtp:dd mtp:def mtp:dd mtp:def" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-mtp-bs-dd-*-bench.txt $O/srv-2node-mtp-bs-def-*-bench.txt | head -8)
SRVX="GGML_CUDA_MOE_DEDUP=1" BARGS="-p 4 -n 0 -r 40" bash $R/tools/bench/prof2node.sh pp4dd > $O/prof-pp4dd.log 2>&1
BARGS="-p 4 -n 0 -r 40" bash $R/tools/bench/prof2node.sh pp4def > $O/prof-pp4def.log 2>&1
python3 -I $R/tools/bench/kdiff.py $(ls -1dt $R/runs/prof2node-pp4def-* | head -1) $(ls -1dt $R/runs/prof2node-pp4dd-* | head -1) > $O/kdiff-pp4.txt
head -3 $O/kdiff-pp4.txt; grep -E "moe" $O/kdiff-pp4.txt
echo "== done $(date +%T)"
