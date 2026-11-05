#!/usr/bin/env bash
# node-ab 가 도는 동안, 벤치(spec_bench)가 돌 때만 B GPU 에 띄엄띄엄 부하(gpuload 0.3 s, 0.7 s 쉼)를 건다
B=parks-zbook@10.99.0.2
while pgrep -f 'bash node-ab' > /dev/null; do
  if pgrep -f 'tools/spec_bench' > /dev/null; then
    echo "$(date +%T) gpu bursts on"
    ssh -o BatchMode=yes $B "nohup bash -c 'for i in \$(seq 90); do /home/parks-zbook/engine2n/bin/gpuload 0.3 > /dev/null 2>&1; sleep 0.7; done # gpub[u]rst' > /dev/null 2>&1 &"
    while pgrep -f 'tools/spec_bench' > /dev/null; do sleep 2; done
    ssh -o BatchMode=yes $B "pkill -f 'gpub[u]rst'; pkill -x gpuload; true"; echo "$(date +%T) gpu bursts off"
  fi
  sleep 2
done
ssh -o BatchMode=yes $B "pkill -f 'gpub[u]rst'; pkill -x gpuload; true"
