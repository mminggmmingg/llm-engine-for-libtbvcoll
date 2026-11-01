#!/usr/bin/env bash
# 2노드 디코드 중 A 의 ggml-rpc-server 스레드 스택을 몇 번 찍는다(진단, 속도 측정 아님)
S=/tmp/claude-1000/-data-parksThink-macos-reversing-claude-code/643ce5c3-138e-406c-bfc6-676a2e96b284/scratchpad/pf; cd $S
export MODEL=/data/parksThink/hf-models/qwen38-flash-next-gguf/UD-IQ4_XS-dense4/Qwen3.8-Flash-Next-Q8mix-q8mix-H5.gguf
A_WRAP="python3 -I $S/ptracer_any.py" PROBE_S=40 TAG=stack bash srv-probe.sh 2node none 256 > $S/stack-run.log 2>&1 &
# 생성이 시작될 때(측정 파일 gm-a.txt 가 생기면 서버 준비 끝, 그 뒤 15초) 까지 기다린 뒤 찍기
for i in $(seq 600); do sleep 1; d=$(ls -dt /data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll/runs/srv-2node-none-stack-* | head -1); [ -f $d/gm-a.txt ] && break; done
echo "run $d"; sleep 15; P=$(pgrep -x ggml-rpc-server | head -1); echo "pid $P"
for k in 1 2 3; do
  echo "=== snapshot $k $(date +%T)"; for t in /proc/$P/task/*; do echo "$(basename $t) $(awk '{print $3, $14+$15}' $t/stat) $(cat $t/wchan)"; done
  timeout 30 gdb -p $P -batch -ex "set pagination off" -ex "thread apply all bt 14" 2>&1 | grep -E "^Thread|^#" ; sleep 6
done
wait; tail -3 $S/stack-run.log
