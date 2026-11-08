#!/usr/bin/env bash
# 11-09 새벽: 1토큰 기본 + 블록 단위로 모아 쓰는 판 확인 — 검증 회, 프로파일(NW 8 / 32), none co/def 3바퀴 + 감시기, MTP 2바퀴
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/fuse2-1108
V="GGML_CUDA_COMM_OUT_FUSE=1 GGML_CUDA_COMM_OUT_VERIFY=1 GGML_CUDA_COMM_OUT_STATS=1"
export SA_cv="$V" SB_cv="$V" SA_co="GGML_CUDA_COMM_OUT_FUSE=1" SB_co="GGML_CUDA_COMM_OUT_FUSE=1"
cd $O
WATCH=0 OUTDIR=fuse2-1108 RUNS="none:cv" bash $R/tools/bench/node-ab.sh
d=$(ls -1dt $R/runs/srv-2node-none-bs-cv-* | head -1)
for x in a b; do echo "verify $x: $(grep -c 'comm out verify' $d/rpc-$x.log) lines, DIFFER $(grep 'comm out verify' $d/rpc-$x.log | grep -c DIFFER)"; grep "comm out:" $d/rpc-$x.log | sort | uniq -c | sort -rn | head -2; done
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-none-bs-cv-*-bench.txt | head -1)
if [ "$(grep 'comm out verify' $d/rpc-a.log $d/rpc-b.log | grep -c DIFFER)" != 0 ] || ! grep -q "6/6 same" <(python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-none-bs-cv-*-bench.txt | head -1)); then echo "verify failed: stop"; exit 1; fi
for nw in 8 32; do SRVX="GGML_CUDA_COMM_OUT_FUSE=1 GGML_CUDA_COMM_OUT_NW=$nw" bash $R/tools/bench/prof2node.sh cw$nw 48 > $O/prof-cw$nw.log 2>&1; sleep 15; done
python3 - <<'PY'
import csv, glob, collections
R = "/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll/runs/"
for pat in ("prof2node-cw8-*", "prof2node-cw32-*"):
    d = sorted(glob.glob(R + pat))[-1]
    t = collections.defaultdict(list)
    for r in csv.DictReader(open(d + "/a_kernel_trace.csv")):
        n = r['Kernel_Name'].replace('void ', '').replace('(ggml_type)', 't').split('(')[0]
        if 'comm_out' in n or 'moe_weighted' in n:
            t[n[:50]].append((int(r['End_Timestamp']) - int(r['Start_Timestamp']))/1e3)
    print(d.rsplit('/',1)[-1], {k: round(sorted(v)[len(v)//2], 1) for k, v in t.items()})
PY
WATCH=1 OUTDIR=fuse2-1108 RUNS="none:co none:def none:co none:def none:co none:def" bash $R/tools/bench/node-ab.sh
WATCH=0 OUTDIR=fuse2-1108 RUNS="mtp:co mtp:def mtp:co mtp:def" bash $R/tools/bench/node-ab.sh
python3 -I $R/fixcost/gluhc-1108/hashchk.py $(ls -1t $O/srv-2node-*-bs-co-1109-0[3-9]*-bench.txt)
