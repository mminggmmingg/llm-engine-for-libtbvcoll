#!/usr/bin/env bash
# 11-14 (진단, WATCH=0): 인덱서 키 전용 배열(dense mirror) 검증 — 두 서버 GGML_CUDA_IDX_DENSE_VERIFY=1(갱신마다 전용 배열 전체를 캐시 행과 비교),
# ctx_bench 깊이 8192·32768 1회씩, none·MTP(MTP 는 거절 되돌리기를 거침). 출력 sha 는 run-ab 의 끔 회와 비교.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; C=$R/fixcost/ctx-1112/corpus-llamacpp-e09a78a.txt
export SA_ver="GGML_CUDA_IDX_DENSE_VERIFY=1" SB_ver="GGML_CUDA_IDX_DENSE_VERIFY=1" SRV_EXTRA="-c 262144"
BENCH_S=1800 WATCH=0 BENCH="tools/bench/ctx_bench.py $C 8192,32768 1 {OUT}/ctx.jsonl" OUTDIR=idxdense-1114 RUNS="none:ver mtp:ver" bash $R/tools/bench/node-ab.sh
for d in $(ls -1dtr $R/runs/srv-2node-*-bs-ver-1114-* | tail -2); do echo "== $d"; cat $d/ctx.jsonl
  for f in $d/rpc-a.log $d/rpc-b.log; do echo "-- $(basename $f): $(grep -c 'idx dense verify' $f) verify lines, nonzero: $(grep 'idx dense verify' $f | grep -vc ': 0 differing')"; grep -m3 'dense mirror\|another way' $f; grep 'idx dense verify' $f | tail -2; done; done
echo ALLDONE
