#!/usr/bin/env bash
# 노드별 서버 환경 A/B, 2노드 H5: RUNS="none:<cfg> ..." — cfg 마다 A 환경(SA)·B 환경(SB)·클라이언트 환경(CL)·바이너리(BIN)·기록 링(TR). 회마다 두 노드 gpu_metrics·스레드·prof
# 속도 회는 기록 링을 끄고(TRACE 기본 0 — 켜면 ≈6% 느림) 잰다. 그다음 WATCH=1(기본)이면 RUNS 의 spec:cfg 마다 기록을 켠 회를 하나씩 더 돌려
# 추론 감시(inferwatch tag 사본 $IW, 11-10 전엔 tools/watch) 세션을 남기고, 그 비교표(stallsum.py: 단계 시간, AR 지연, 1 ms 넘는 기다림의 원인, 링크 늦음 크기)를
# $OUT/watch-summary-<시각>.md 에 쓴다 — 실험마다 감시기 결과를 같이 남긴다(사용자 규칙, 2026-11-07). WATCH=0 이면 속도 회만, SPEED=0 이면 감시기 회만.
cd "$(dirname "$(readlink -f "$0")")"   # tools/bench 에서(srv-probe.sh·gmsum.py·profsum.py 옆). 예전에는 세션 scratchpad 의 사본 pf/
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; OUT=$R/fixcost/${OUTDIR:-bstate-1101}; mkdir -p $OUT
BIN0=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp/build-rocm3/bin   # cfg 별 바이너리: BIN_<cfg>
export MODEL=/data/parksThink/hf-models/qwen38-flash-next-gguf/UD-IQ4_XS-dense4/Qwen3.8-Flash-Next-Q8mix-q8mix-H5.gguf SPEC_EXTRA="-devd ROCm0"
BASE="GGML_CUDA_DISABLE_GRAPHS=1 GGML_RPC_COMM_PROF=1000"
TRACE_DEF=${TRACE:-0}
# 감시기 = inferwatch 저장소의 tag 사본(측정 기준, inferwatch docs/ENVIRONMENT.md "엔진 연결"; 2026-11-10까지는 이 저장소 tools/watch)
IW=${IW:-/data/parksThink/inferwatch-iw-20261110-1}; IWB=$IW/target/release/inferwatch
BH=parks-zbook@10.99.0.2; BIW=/home/parks-zbook/inferwatch/bin/inferwatch; BDRAM=/home/parks-zbook/inferwatch/dram   # B: 데몬이 복사한 같은 판
# 노드별 DRAM 읽기 바이트(inferwatch docs/DRAM.md, perf amd_df): DRAM=auto(기본, 준비된 노드만 감시기 회에서 잼 — 안 된 노드 값은 비움)
# |1(두 노드 중 하나라도 못 하면 멈춤)|0(끔). 노드마다 amd-uncore 모듈·perf_event_paranoid ≤ 0 (사용자 sudo, 재부팅하면 풀림)·perf 필요.
DCHK='[ -d /sys/bus/event_source/devices/amd_df ] && [ "$(cat /proc/sys/kernel/perf_event_paranoid)" -le 0 ] && command -v perf > /dev/null'
DRAMD=""; DN=""                                   # DN: DRAM 을 재는 노드(a, b)
MTP0=${MTP:-}                                      # 초안 모델: 구성마다 MTP_<cfg>, 없으면 이 값(또는 srv-probe 기본)
has() { case " $DN " in *" $1 "*) return 0 ;; esac; return 1; }
one_run() {  # $1 = spec:cfg, $2 = 기록 링 0|1 (비면 TR_<cfg>, 없으면 TRACE), $3 = 실행 폴더 이름 꼬리
  run=$1; spec=${run%:*}; cfg=${run#*:}
  case $cfg in
    base)    SA="";                                   SB="" ;;
    b2s)     SA="";                                   SB="GGML_RPC_COMM_ZC=2 GGML_RPC_SPIN_US=20" ;;
    b2)      SA="";                                   SB="GGML_RPC_COMM_ZC=2" ;;
    b1s)     SA="";                                   SB="GGML_RPC_SPIN_US=20" ;;
    ab2s)    SA="GGML_RPC_COMM_ZC=2 GGML_RPC_SPIN_US=20"; SB="GGML_RPC_COMM_ZC=2 GGML_RPC_SPIN_US=20" ;;
    *) SA=$(eval echo \${SA_$cfg}); SB=$(eval echo \${SB_$cfg}) ;;
  esac
  bx=$(eval echo \${BIN_$cfg}); export BIN=${bx:-$BIN0}
  tr=$(eval echo \${TR_$cfg}); export TRACE=${2:-${tr:-$TRACE_DEF}}   # 기록 링(tools/watch) 켬/끔: TR_<cfg>=0|1
  export CLI_ENV=$(eval echo \${CL_$cfg})                          # 클라이언트(llama-server) 환경: CL_<cfg>
  export CLI_WRAP=$(eval echo \${CW_$cfg})                         # 클라이언트 앞 명령(taskset 등): CW_<cfg>
  export A_WRAP=$(eval echo \${AW_$cfg}) B_WRAP=$(eval echo \${BW_$cfg})   # A·B rpc-server 앞 명령: AW_<cfg>, BW_<cfg>
  tp=$(eval echo \${TBPIN_$cfg}); export TBPIN=${tp:-${TBPIN_ALL:-1}}   # TB 인터럽트 CPU 피하기(srv-probe 기본 1): TBPIN_<cfg>=0 이면 끔
  td=$(eval echo \${TBDEV_$cfg}); export TBDEV=${td:-${TBDEV_ALL:-1}}   # AR 링크를 클라이언트가 안 쓰는 장치로(srv-probe 기본 1): TBDEV_<cfg>=0 이면 끔
  r2=$(eval echo \${RAIL2_$cfg}); export RAIL2=${r2:-${RAIL2_ALL:-auto}}   # AR 둘째 레일(srv-probe 기본 auto = MTP 회만, 32 KB 이상만): RAIL2_<cfg>=0|1|auto
  mt=$(eval echo \${MTP_$cfg}); if [ -n "$mt" ]; then export MTP=$mt; elif [ -n "$MTP0" ]; then export MTP=$MTP0; else unset MTP; fi   # MTP_<cfg>: 초안 GGUF
  # MTP 초안 모델 인자: SE_<cfg>(빈 값이면 -devd 없이 본 모델처럼 2노드 TP), 없으면 -devd ROCm0(A GPU 혼자)
  if eval "[ -n \"\${SE_$cfg+x}\" ]"; then export SPEC_EXTRA=$(eval echo \${SE_$cfg}); else export SPEC_EXTRA="-devd ROCm0"; fi
  for i in $(seq 60); do b=$(timeout 10 ssh -o BatchMode=yes parks-zbook@10.99.0.2 "cut -d' ' -f1 /proc/loadavg"); a=$(cut -d' ' -f1 /proc/loadavg); awk "BEGIN{exit !($a<0.6 && $b<0.6)}" && break; sleep 5; done
  # RDMA 가 안 올라와 TCP 로 떨어진 회는 다시(최대 3번)
  for try in 1 2 3; do
    bb=$(eval echo \${BASE_$cfg}); bb=${bb:-$BASE}                  # 기본 서버 환경 바꾸기: BASE_<cfg>(예: 그래프 켜기)
    if [ -n "$DRAMD" ]; then   # 서버 전 10 초 쉬는 몫(두 노드 같이, 끝난 뒤 서버 시작), 회 동안 50 ms 표본 — sample-dram 은 파일에 덧붙이므로 회마다 새 이름
      f=$DRAMD/$(date +%m%d-%H%M%S)-$cfg$3; fb=$BDRAM/$(basename $f); PA=""; PB=""; ib=""
      has b && { timeout 40 ssh -n -o BatchMode=yes $BH "$BIW sample-dram 10 100 $fb-idle-b.txt" & ib=$!; }
      has a && timeout 40 $IWB sample-dram 10 100 $f-idle-a.txt; [ -n "$ib" ] && wait $ib
      # 새 세션(그룹)으로 띄우고 그 그룹 번호를 파일로 받는다 — 그룹째 멈춰야 자식 perf 도 끝남. `setsid x & $!` 는 setsid 가 fork 하면 다른 번호(11-10 시험)
      has a && { setsid -f bash -c "echo \$\$ > $f-a.pid; exec $IWB sample-dram 3600 50 $f-a.txt" > /dev/null 2>&1 < /dev/null; sleep 0.3; PA=$(cat $f-a.pid); }
      has b && PB=$(timeout 10 ssh -n -o BatchMode=yes $BH "setsid -f bash -c 'echo \$\$ > $fb-b.pid; exec $BIW sample-dram 3600 50 $fb-b.txt' > /dev/null 2>&1 < /dev/null; sleep 0.3; cat $fb-b.pid")
    fi
    out=$(SRV_ENV="$bb $SA" SRV_ENV_B="$bb $SB" TAG=bs-$cfg$3 bash srv-probe.sh 2node $spec 2>&1); d=$(echo "$out" | tail -1); n=$(basename $d)
    if [ -n "$DRAMD" ]; then
      [ -n "$PA" ] && kill -TERM -- -$PA; [ -n "$PB" ] && timeout 10 ssh -n -o BatchMode=yes $BH "kill -TERM -- -$PB"; sleep 1
      has b && { scp -q $BH:$fb-b.txt $f-b.txt; scp -q $BH:$fb-idle-b.txt $f-idle-b.txt; }
    fi
    [ "$(grep -cE "RDMA activated|allreduce link on .* [(]RDMA[)]" $d/rpc-a.log)" -ge 1 ] && break   # AR 링크 줄: GGML_RPC_LOCAL_TCP 이면 클라이언트 연결은 TCP
    echo "   ($n: rdma=0 — 다시 $try)"; sleep 10
  done
  for x in gm-a gm-b bench thr-a thr-b pin; do cp $d/$x.txt $OUT/$n-$x.txt 2>/dev/null; done
  scp -q parks-zbook@10.99.0.2:/home/parks-zbook/engine2n/bin/rpc-server.log $d/rpc-b.log; grep comm_prof $d/rpc-a.log > $OUT/$n-prof-a.txt; grep comm_prof $d/rpc-b.log > $OUT/$n-prof-b.txt
  echo "$spec $cfg$3 bin=$(basename $BIN) load A=$a B=$b rdma=$(grep -cE "RDMA activated|allreduce link on .* [(]RDMA[)]" $d/rpc-a.log) trace=$TRACE zc=$(grep -o 'ZC=[0-9]' $d/rpc-a.log | head -1)/$(grep -o 'ZC=[0-9]' $d/rpc-b.log | head -1): $(echo "$out" | grep TOTAL) | $n"
  for x in a b; do echo "   $x: $(python3 -I gmsum.py $d/gm-$x.txt | cut -d'|' -f1)"; done
  LAST_D=$d; python3 -I outsum.py "$spec:$cfg$3=$d" 2>/dev/null | tail -n +3 | sed 's/^/   out /'   # 출력 토큰 t/s · 가중치 기준 GB/s (2026-11-14)
  c=$(python3 -I profsum.py $OUT/$n-prof-a.txt 2>/dev/null | grep -o 'cycle *[0-9.]*'); [ -n "$c" ] && echo "   cyc: $c"
}
[ "${SPEED:-1}" != 0 ] && for run in ${RUNS:?}; do one_run $run "" ""; done   # SPEED=0: 감시기 회만

if [ "${WATCH:-1}" != 0 ]; then
  W=$R/runs/watch; started=0
  [ -x $IWB ] || { echo "inferwatch tag 사본이 없다: $IW (inferwatch docs/ENVIRONMENT.md \"엔진 연결\" 대로 worktree + cargo build --release)"; exit 1; }
  if ! { [ -f $W/daemon.pid ] && kill -0 "$(cat $W/daemon.pid)" 2>/dev/null; }; then INFERWATCH_OUT=$W $IW/scripts/inferwatch.sh start > /dev/null; started=1
  else e=$(readlink /proc/$(cat $W/daemon.pid)/exe); [ "$e" = "$IWB" ] || echo "   (주의: 이미 도는 감시 데몬이 다른 판이다: $e)"; fi
  if [ "${DRAM:-auto}" != 0 ]; then
    bash -c "$DCHK" && DN="a"
    for i in 1 2 3 4 5; do   # B 사본은 데몬이 띄울 때 복사하므로 잠깐 기다림
      timeout 10 ssh -n -o BatchMode=yes $BH "$DCHK && [ -x $BIW ] && mkdir -p $BDRAM" && { DN="$DN b"; break; }; sleep 2; done
    for x in a b; do has $x || echo "   (DRAM: 노드 ${x^^} 못 잼 — amd_df·perf_event_paranoid ≤ 0·perf(B 는 감시기 사본도) 중 하나 없음, inferwatch docs/DRAM.md 1절. 그 노드 값은 비움)"; done
    [ "$DRAM" = 1 ] && ! { has a && has b; } && exit 1
    [ -n "$DN" ] && { DRAMD=$OUT/dram; mkdir -p $DRAMD; }
  fi
  seen=" "; pairs=(); drams=(); outs=()
  for run in $RUNS; do
    case "$seen" in *" $run "*) continue ;; esac
    seen="$seen$run "
    before=$(ls -1d $W/2*/ 2>/dev/null | tail -1)
    one_run $run 1 -w
    # 감시기는 추론이 3 초 쉬면 그 세션의 보고서를 쓴다
    last=$before
    for i in $(seq 90); do last=$(ls -1d $W/2*/ 2>/dev/null | tail -1); [ "$last" != "$before" ] && [ -f $last/receipt.md ] && break; sleep 2; done
    if [ "$last" != "$before" ] && [ -f $last/receipt.md ]; then pairs+=("$run=$last"); else echo "   (감시기 세션 없음: $run)"; fi
    if [ -n "$DRAMD" ] && [ "$last" != "$before" ] && [ -f $last/receipt.md ]; then   # 노드별 토큰당 바이트(쉬는 몫 빼기·토큰 나누기는 inferwatch)
      # 쉬는 몫 = 쉬는 표본 구간의 중앙값(B/s) — 평균은 기록 양 끝의 튐을 넣는다(inferwatch 11-11 권고, 그 다음 판은 --idle-file 이 중앙값). 중앙값 3배 넘는 구간 수도 남김
      for x in $DN; do
        med=$(awk '!/^#/ && $3 > 0 {printf "%.0f\n", $2/($3/1e9)}' $f-idle-$x.txt | sort -n | awk '{a[NR]=$1} END {if (NR) printf "%.0f\n", (NR%2 ? a[(NR+1)/2] : (a[NR/2]+a[NR/2+1])/2)}')
        hi=$(awk -v m="${med:-0}" '!/^#/ && $3 > 0 && $2/($3/1e9) > 3*m {n++} END {print n+0}' $f-idle-$x.txt); echo "${med:-?} $hi" > $f-idle-$x.med
        $IWB dram-bytes $last $f-$x.txt --node ${x^^} ${med:+--idle-bps $med} > $f-$x.json 2> $f-$x.err \
          || echo "   (dram-bytes ${x^^} 실패: $(tail -1 $f-$x.err))"
      done
      drams+=("$run=$f")
    fi
    o="$run=$LAST_D"; [ -n "$DRAMD" ] && { [ -f $f-a.json ] || [ -f $f-b.json ]; } && o="$o,$f"; outs+=("$o")
  done
  [ $started = 1 ] && kill "$(cat $W/daemon.pid)" 2>/dev/null   # inferwatch.sh stop 은 pid 파일을 지우므로 쓰지 않는다
  if [ ${#pairs[@]} -gt 0 ]; then
    sum=$OUT/watch-summary-$(date +%m%d-%H%M%S).md
    { echo "# 추론 감시 비교 ($(date '+%F %T'), RUNS=\"$RUNS\")"; echo
      echo "기록 링을 켠 회라 tok/s 는 속도 회보다 ≈6% 낮다. 세션 폴더: runs/watch/<세션>/(report.html, receipt.md, stalls.txt)."
      echo "감시기 판: $($IWB version 2>&1 | head -1) ($IW)"; echo
      python3 -I $IW/scripts/stallsum.py "${pairs[@]}"
      if [ ${#drams[@]} -gt 0 ]; then
        echo; echo "## 노드별 DRAM 읽기 (inferwatch dram-bytes, 기록 링 켠 회의 decode 단계, 쉬는 몫 뺌)"; echo
        echo "| 회 | 노드 | GB/처리 토큰 | decode 중 GB/s | 239.7 대비 | 쉬는 몫 GB/s(중앙값, 3배 넘는 구간 수) | 처리 토큰 |"; echo "|---|---|---:|---:|---:|---|---:|"
        for p in "${drams[@]}"; do for x in a b; do python3 -I -c 'import json,sys
d=json.load(open(sys.argv[1])); m=open(sys.argv[3]).read().split() if len(sys.argv) > 3 else ["?", "?"]
print("| %s | %s | %s | %s | %s | %s (%s) | %s |"%(sys.argv[2],d["node"],d["gb_per_token"],d["gbps_during_decode"],d["share_of_peak"],d["idle_gbps"],m[1],d["decode_tokens"]))' ${p#*=}-$x.json ${p%%=*} ${p#*=}-idle-$x.med 2>/dev/null || echo "| ${p%%=*} | ${x^^} | (없음) | | | | |"; done; done
        echo; echo "처리 토큰 = 감시 세션 decode 단계가 처리한 토큰(MTP 는 검증 묶음의 토큰까지 — 출력 토큰보다 많다). 85% 목표 값(none): 노드마다 GB/토큰 × 같은 구성 속도 회(기록 링 끔) tok/s ÷ 239.7."
        echo "MTP 는 decode 중 GB/s(기록 링 켠 회) 를 본다. 자료: $DRAMD"
      fi
      echo; echo "## 출력 토큰 기준 (tools/bench/outsum.py — MTP 는 출력 토큰으로 센 t/s, 가중치 기준 GB/s = t/s × 노드당 2.83 GB, DRAM 은 잰 노드만)"; echo
      python3 -I outsum.py "${outs[@]}" 2>/dev/null
      for p in "${pairs[@]}"; do cp ${p#*=}receipt.md $OUT/watch-receipt-$(basename ${p#*=}).md; done; } > $sum
    cat $sum
  fi
fi
