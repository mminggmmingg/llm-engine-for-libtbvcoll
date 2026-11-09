#!/usr/bin/env bash
# 측정(node-ab, PID $1)이 도는 동안, 벤치가 돌 때만 A·B 두 GPU 에 띄엄띄엄 부하(gpuload 0.3 s, 0.7 s 쉼; 두 노드 박자 다름) — 묶은 커널의 경쟁 시험
B=parks-zbook@10.99.0.2
GA="env LD_LIBRARY_PATH=/opt/rocm/lib /tmp/claude-1000/-data-parksThink-macos-reversing-claude-code/643ce5c3-138e-406c-bfc6-676a2e96b284/scratchpad/bin/gpuload"
while kill -0 $1 2>/dev/null; do
  if pgrep -f 'tools/spec_[b]ench' > /dev/null; then
    echo "$(date +%T) gpu bursts on (A, B)"
    ssh -o BatchMode=yes $B "nohup bash -c 'for i in \$(seq 90); do /home/parks-zbook/engine2n/bin/gpuload 0.3 > /dev/null 2>&1; sleep 0.7; done # gpuburst' > /dev/null 2>&1 &"
    nohup bash -c "sleep 0.45; for i in \$(seq 90); do $GA 0.3 > /dev/null 2>&1; sleep 0.7; done # gpuburst" > /dev/null 2>&1 &
    while pgrep -f 'tools/spec_[b]ench' > /dev/null; do sleep 2; done
    ssh -o BatchMode=yes $B "pkill -f 'gpub[u]rst'; pkill -x gpuload; true"; pkill -f 'gpub[u]rst'; pkill -x gpuload; echo "$(date +%T) gpu bursts off"
  fi
  sleep 2
done
ssh -o BatchMode=yes $B "pkill -f 'gpub[u]rst'; pkill -x gpuload; true"; pkill -f 'gpub[u]rst'; pkill -x gpuload; true
