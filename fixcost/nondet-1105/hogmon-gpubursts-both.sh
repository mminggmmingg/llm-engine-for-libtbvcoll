#!/usr/bin/env bash
# node-ab 가 도는 동안, 벤치(spec_bench)가 돌 때만 A·B 두 GPU 에 띄엄띄엄 부하(gpuload 0.3 s, 0.7 s 쉼; 두 노드는 서로 다른 박자)를 건다
B=parks-zbook@10.99.0.2
GA="env LD_LIBRARY_PATH=/opt/rocm/lib ./gpuload"   # A 에 B 의 gpuload 바이너리를 복사해 둔 곳
while pgrep -f 'bash node-ab' > /dev/null; do
  if pgrep -f 'tools/spec_bench' > /dev/null; then
    echo "$(date +%T) gpu bursts on (A, B)"
    ssh -o BatchMode=yes $B "nohup bash -c 'for i in \$(seq 90); do /home/parks-zbook/engine2n/bin/gpuload 0.3 > /dev/null 2>&1; sleep 0.7; done # gpuburst' > /dev/null 2>&1 &"
    nohup bash -c "sleep 0.45; for i in \$(seq 90); do $GA 0.3 > /dev/null 2>&1; sleep 0.7; done # gpuburst" > /dev/null 2>&1 &
    while pgrep -f 'tools/spec_bench' > /dev/null; do sleep 2; done
    ssh -o BatchMode=yes $B "pkill -f 'gpub[u]rst'; pkill -x gpuload; true"; pkill -f 'gpub[u]rst'; pkill -x gpuload; echo "$(date +%T) gpu bursts off"
  fi
  sleep 2
done
ssh -o BatchMode=yes $B "pkill -f 'gpub[u]rst'; pkill -x gpuload; true"; pkill -f 'gpub[u]rst'; pkill -x gpuload; true
