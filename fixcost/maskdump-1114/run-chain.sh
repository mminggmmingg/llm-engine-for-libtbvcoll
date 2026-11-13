#!/usr/bin/env bash
# 11-14 04:4x: 새 빌드로 3번 마스크 덤프(run-md.sh) → masksim → 2번 전환 확인(mtpswitch-1114/run-sw.sh). 하나씩 차례로.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; MD=$R/runs/maskdump-1114; O=$R/fixcost/maskdump-1114
echo "== md $(date +%T)"; timeout 1800 bash $O/run-md.sh > $O/run-md.log 2>&1; tail -6 $O/run-md.log
echo "== masksim $(date +%T)"
for f in $(ls -1 $MD/mask-*.f16 2>/dev/null); do
  timeout 600 python3 -I $R/tools/bench/masksim.py $f --q 1,4,8,16,32,64 --kv 16,32,64,128 >> $O/masksim.txt 2>&1
done
echo "== sw $(date +%T)"; timeout 3000 bash $R/fixcost/mtpswitch-1114/run-sw.sh > $R/fixcost/mtpswitch-1114/run-sw.log 2>&1; tail -20 $R/fixcost/mtpswitch-1114/run-sw.log
echo "CHAINDONE $(date +%T)"
