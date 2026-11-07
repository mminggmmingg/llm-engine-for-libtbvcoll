#!/usr/bin/env bash
# 노드별 서버 환경 A/B, 2노드 H5: RUNS="none:<cfg> ..." — cfg 마다 A 환경(SA)·B 환경(SB)·클라이언트 환경(CL)·바이너리(BIN)·기록 링(TR). 회마다 두 노드 gpu_metrics·스레드·prof
S=/tmp/claude-1000/-data-parksThink-macos-reversing-claude-code/643ce5c3-138e-406c-bfc6-676a2e96b284/scratchpad/pf; cd $S
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; OUT=$R/fixcost/${OUTDIR:-bstate-1101}; mkdir -p $OUT
BIN0=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp/build-rocm3/bin   # cfg 별 바이너리: BIN_<cfg>
export MODEL=/data/parksThink/hf-models/qwen38-flash-next-gguf/UD-IQ4_XS-dense4/Qwen3.8-Flash-Next-Q8mix-q8mix-H5.gguf SPEC_EXTRA="-devd ROCm0"
BASE="GGML_CUDA_DISABLE_GRAPHS=1 GGML_RPC_COMM_PROF=1000"
for run in ${RUNS:?}; do
  spec=${run%:*}; cfg=${run#*:}
  case $cfg in
    base)    SA="";                                   SB="" ;;
    b2s)     SA="";                                   SB="GGML_RPC_COMM_ZC=2 GGML_RPC_SPIN_US=20" ;;
    b2)      SA="";                                   SB="GGML_RPC_COMM_ZC=2" ;;
    b1s)     SA="";                                   SB="GGML_RPC_SPIN_US=20" ;;
    ab2s)    SA="GGML_RPC_COMM_ZC=2 GGML_RPC_SPIN_US=20"; SB="GGML_RPC_COMM_ZC=2 GGML_RPC_SPIN_US=20" ;;
    *) SA=$(eval echo \${SA_$cfg}); SB=$(eval echo \${SB_$cfg}) ;;
  esac
  bx=$(eval echo \${BIN_$cfg}); export BIN=${bx:-$BIN0}
  tr=$(eval echo \${TR_$cfg}); export TRACE=${tr:-${TRACE:-1}}   # 기록 링(tools/watch) 켬/끔: TR_<cfg>=0|1
  export CLI_ENV=$(eval echo \${CL_$cfg})                          # 클라이언트(llama-server) 환경: CL_<cfg>
  export CLI_WRAP=$(eval echo \${CW_$cfg})                         # 클라이언트 앞 명령(taskset 등): CW_<cfg>
  export A_WRAP=$(eval echo \${AW_$cfg}) B_WRAP=$(eval echo \${BW_$cfg})   # A·B rpc-server 앞 명령: AW_<cfg>, BW_<cfg>
  tp=$(eval echo \${TBPIN_$cfg}); export TBPIN=${tp:-${TBPIN_ALL:-1}}   # TB 인터럽트 CPU 피하기(srv-probe 기본 1): TBPIN_<cfg>=0 이면 끔
  td=$(eval echo \${TBDEV_$cfg}); export TBDEV=${td:-${TBDEV_ALL:-1}}   # AR 링크를 클라이언트가 안 쓰는 장치로(srv-probe 기본 1): TBDEV_<cfg>=0 이면 끔
  # MTP 초안 모델 인자: SE_<cfg>(빈 값이면 -devd 없이 본 모델처럼 2노드 TP), 없으면 -devd ROCm0(A GPU 혼자)
  if eval "[ -n \"\${SE_$cfg+x}\" ]"; then export SPEC_EXTRA=$(eval echo \${SE_$cfg}); else export SPEC_EXTRA="-devd ROCm0"; fi
  for i in $(seq 60); do b=$(timeout 10 ssh -o BatchMode=yes parks-zbook@10.99.0.2 "cut -d' ' -f1 /proc/loadavg"); a=$(cut -d' ' -f1 /proc/loadavg); awk "BEGIN{exit !($a<0.6 && $b<0.6)}" && break; sleep 5; done
  # RDMA 가 안 올라와 TCP 로 떨어진 회는 다시(최대 3번)
  for try in 1 2 3; do
    bb=$(eval echo \${BASE_$cfg}); bb=${bb:-$BASE}                  # 기본 서버 환경 바꾸기: BASE_<cfg>(예: 그래프 켜기)
    out=$(SRV_ENV="$bb $SA" SRV_ENV_B="$bb $SB" TAG=bs-$cfg bash srv-probe.sh 2node $spec 2>&1); d=$(echo "$out" | tail -1); n=$(basename $d)
    [ "$(grep -c "RDMA activated" $d/rpc-a.log)" -ge 1 ] && break
    echo "   ($n: rdma=0 — 다시 $try)"; sleep 10
  done
  for x in gm-a gm-b bench thr-a thr-b pin; do cp $d/$x.txt $OUT/$n-$x.txt 2>/dev/null; done
  scp -q parks-zbook@10.99.0.2:/home/parks-zbook/engine2n/bin/rpc-server.log $d/rpc-b.log; grep comm_prof $d/rpc-a.log > $OUT/$n-prof-a.txt; grep comm_prof $d/rpc-b.log > $OUT/$n-prof-b.txt
  echo "$spec $cfg bin=$(basename $BIN) load A=$a B=$b rdma=$(grep -c "RDMA activated" $d/rpc-a.log) zc=$(grep -o 'ZC=[0-9]' $d/rpc-a.log | head -1)/$(grep -o 'ZC=[0-9]' $d/rpc-b.log | head -1): $(echo "$out" | grep TOTAL) | $n"
  for x in a b; do echo "   $x: $(python3 -I gmsum.py $d/gm-$x.txt | cut -d'|' -f1)"; done
  echo "   cyc: $(python3 -I profsum.py $OUT/$n-prof-a.txt | grep -o 'cycle *[0-9.]*')"
done
