#!/usr/bin/env bash
# 11-12 18:4x: 사용자 "QSA 층 커널 분해부터 해서 긴 문맥 개선해" — 깊이 0·32k·128k 에서 2노드 디코드(tg32)의 A 서버 커널 기록(rocprofv3).
# llama-bench -d <깊이>(KV 를 먼저 채움) -p 0 -n 32. 진단용(감시기 없음). 회마다 시간 제한, 끝나면 남은 서버를 PID 로 정리.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
for d in ${DEPTHS:-0 32768 131072}; do
  echo "== depth $d $(date +%T)"
  BARGS="-p 0 -n 32 -d $d -r 1" timeout -k 30 ${PROF_S:-2400} bash $R/tools/bench/prof2node.sh qsad$d 32
  echo "rc=$? $(date +%T)"
  for p in $(pgrep -x ggml-rpc-server) $(pgrep -x llama-bench) $(pgrep -f "rocprofv3.*ggml-rpc-server"); do echo "leftover $p"; kill -KILL $p 2>/dev/null; done
  ssh -o BatchMode=yes -o ConnectTimeout=10 parks-zbook@10.99.0.2 'for p in $(pgrep -x ggml-rpc-server); do kill -KILL $p; done; true'
  sleep 5
done
echo ALLDONE
