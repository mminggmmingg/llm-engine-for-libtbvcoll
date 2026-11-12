#!/usr/bin/env bash
# 11-12 22:0x: 긴 문맥 개선 확정 빌드(FA 묶음 건너뛰기·인덱서 키 직접 읽기·한 블록 top-k)로 다시 — 남은 깊이 비용을 보려고(비효율 점검).
# llama-bench -d <깊이>(KV 를 먼저 채움) -p 0 -n 32. 진단용(감시기 없음). 회마다 시간 제한, 끝나면 남은 서버를 PID 로 정리.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
for d in ${DEPTHS:-0 32768 131072}; do
  echo "== depth $d $(date +%T)"
  BARGS="-p 0 -n 32 -d $d -r 1" timeout -k 30 ${PROF_S:-2400} bash $R/tools/bench/prof2node.sh lcd$d 32
  echo "rc=$? $(date +%T)"
  for p in $(pgrep -x ggml-rpc-server) $(pgrep -x llama-bench) $(pgrep -f "rocprofv3.*ggml-rpc-server"); do echo "leftover $p"; kill -KILL $p 2>/dev/null; done
  ssh -o BatchMode=yes -o ConnectTimeout=10 parks-zbook@10.99.0.2 'for p in $(pgrep -x ggml-rpc-server); do kill -KILL $p; done; true'
  sleep 5
done
echo ALLDONE
