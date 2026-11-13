#!/usr/bin/env bash
# 11-14 00:xx (진단, 감시기 없음): MTP 4토큰 검증과 같은 4토큰 묶음을 깊이별로 커널 기록 — 인덱서가 질의마다 키를 따로 읽는 몫, FA 합집합 몫 보기.
# llama-bench -d <깊이>(KV 먼저 채움) -p 4 -n 0 -r 1. 회마다 시간 제한, 끝나면 남은 서버를 PID 로 정리.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
for d in ${DEPTHS:-0 32768 131072}; do
  echo "== depth $d $(date +%T)"
  BARGS="-p 4 -n 0 -d $d -r 1" timeout -k 30 ${PROF_S:-2400} bash $R/tools/bench/prof2node.sh pp4d$d 4
  echo "rc=$? $(date +%T)"
  for p in $(pgrep -x ggml-rpc-server) $(pgrep -x llama-bench) $(pgrep -f "rocprofv3.*ggml-rpc-server"); do echo "leftover $p"; kill -KILL $p 2>/dev/null; done
  ssh -o BatchMode=yes -o ConnectTimeout=10 parks-zbook@10.99.0.2 'for p in $(pgrep -x ggml-rpc-server); do kill -KILL $p; done; true'
  sleep 5
done
echo ALLDONE
