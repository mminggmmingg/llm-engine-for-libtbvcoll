#!/usr/bin/env bash
# 11-13 03:0x: 비효율 점검(고치지 않음) — 긴 문맥 프롬프트 처리(문맥 채우기 + pp512)의 커널별 몫. A 서버 rocprofv3, llama-bench -d <깊이> -p 512 -n 0 -r 1.
# 진단용(감시기 없음). 회마다 시간 제한, 끝나면 남은 서버를 PID 로 정리.
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
for d in ${DEPTHS:-32768 131072}; do
  echo "== depth $d $(date +%T)"
  BARGS="-p 512 -n 0 -d $d -r 1" timeout -k 30 ${PROF_S:-2400} bash $R/tools/bench/prof2node.sh ppd$d
  echo "rc=$? $(date +%T)"
  for p in $(pgrep -x ggml-rpc-server) $(pgrep -x llama-bench) $(pgrep -f "rocprofv3.*ggml-rpc-server"); do echo "leftover $p"; kill -KILL $p 2>/dev/null; done
  ssh -o BatchMode=yes -o ConnectTimeout=10 parks-zbook@10.99.0.2 'for p in $(pgrep -x ggml-rpc-server); do kill -KILL $p; done; true'
  sleep 5
done
echo ALLDONE
