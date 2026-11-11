#!/usr/bin/env bash
# 11-11: 4토큰(MTP 검증) 전문가 중복 읽기 제거 다시 — GGML_CUDA_MOE_DEDUP=2(mul_mat_vec_q_moe_dd2). 1) 두 노드 비트 검사 회 2) pp4 프로파일 dd2/def
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; O=$R/fixcost/dd2-1111
V="GGML_CUDA_MOE_DEDUP=2 GGML_CUDA_MOE_DEDUP_VERIFY=1"
export SA_dv2="$V" SB_dv2="$V" BENCH_S=900
cd $O
WATCH=0 OUTDIR=dd2-1111 RUNS="mtp:dv2" bash $R/tools/bench/node-ab.sh
d=$(ls -1dt $R/runs/srv-2node-mtp-bs-dv2-* | head -1)
for x in a b; do
  echo "verify $x: $(grep -c 'moe dedup verify' $d/rpc-$x.log) lines, nonzero $(grep 'moe dedup verify' $d/rpc-$x.log | grep -vc ': 0 of')"
  grep -m2 'moe dedup verify' $d/rpc-$x.log; grep 'moe dedup verify' $d/rpc-$x.log | grep -v ': 0 of' | head -3
done
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-mtp-bs-dv2-*-bench.txt | head -1)
if [ "$(grep -h 'moe dedup verify' $d/rpc-a.log $d/rpc-b.log | grep -vc ': 0 of')" != 0 ] || [ "$(grep -hc 'moe dedup verify' $d/rpc-a.log)" = 0 ]; then echo "verify failed or not used: stop"; exit 1; fi
SRVX="GGML_CUDA_MOE_DEDUP=2" BARGS="-p 4 -n 0 -r 40" timeout 900 bash $R/tools/bench/prof2node.sh pp4dd2 > $O/prof-pp4dd2.log 2>&1
BARGS="-p 4 -n 0 -r 40" timeout 900 bash $R/tools/bench/prof2node.sh pp4def > $O/prof-pp4def.log 2>&1
python3 -I $R/tools/bench/kdiff.py $(ls -1dt $R/runs/prof2node-pp4def-1111* | head -1) $(ls -1dt $R/runs/prof2node-pp4dd2-* | head -1) > $O/kdiff-pp4.txt
head -3 $O/kdiff-pp4.txt; grep -E "moe" $O/kdiff-pp4.txt
echo "== done $(date +%T)"
