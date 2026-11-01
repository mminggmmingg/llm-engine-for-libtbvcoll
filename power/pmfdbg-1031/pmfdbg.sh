#!/usr/bin/env bash
# amd_pmf 디버그를 켠 상태에서: 유휴 30초 → 2노드 디코드(MTP 없음, H5) → 유휴 20초 → 두 노드 pfload(GPU 포화) → 커널 로그 수집
set -uo pipefail
S=/tmp/claude-1000/-data-parksThink-macos-reversing-claude-code/643ce5c3-138e-406c-bfc6-676a2e96b284/scratchpad/pf
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll; B=parks-zbook@10.99.0.2; BBIN=/home/parks-zbook/engine2n/bin
OUT=$R/power/pmfdbg-1031; mkdir -p $OUT; cd $S
on() { journalctl -k --since "-15s" --no-pager 2>/dev/null | grep -c "TA inputs START"; }
na=$(on); nb=$(ssh -o BatchMode=yes $B "journalctl -k --since -15s --no-pager 2>/dev/null | grep -c 'TA inputs START'")
echo "debug blocks last 15s: A=$na B=$nb"; [ "$na" -gt 0 ] && [ "$nb" -gt 0 ] || { echo "amd_pmf 디버그가 꺼져 있음"; exit 2; }
for i in $(seq 60); do b=$(timeout 10 ssh -o BatchMode=yes $B "cut -d' ' -f1 /proc/loadavg"); a=$(cut -d' ' -f1 /proc/loadavg); awk "BEGIN{exit !($a<0.6 && $b<0.6)}" && break; sleep 5; done
echo "load A=$a B=$b"; bash pmfin.sh > $OUT/in-a.txt 2>&1; ssh -o BatchMode=yes $B bash -s < pmfin.sh > $OUT/in-b.txt 2>&1
T0=$(date '+%Y-%m-%d %H:%M:%S'); echo "T0 $T0 idle"; echo "idle0 $T0" > $OUT/phases.txt; sleep 30
echo "decode $(date '+%H:%M:%S')" >> $OUT/phases.txt
export MODEL=/data/parksThink/hf-models/qwen38-flash-next-gguf/UD-IQ4_XS-dense4/Qwen3.8-Flash-Next-Q8mix-q8mix-H5.gguf
out=$(TAG=pmfdbg bash srv-probe.sh 2node none 2>&1); d=$(echo "$out" | tail -1); echo "$out" | grep TOTAL
for n in a b; do cp $d/gm-$n.txt $OUT/decode-gm-$n.txt; cp $d/thr-$n.txt $OUT/decode-thr-$n.txt; echo "  $n: $(python3 -I gmsum.py $d/gm-$n.txt)"; done; cp $d/bench.txt $OUT/decode-bench.txt
echo "idle1 $(date '+%H:%M:%S')" >> $OUT/phases.txt; sleep 20
echo "pfload $(date '+%H:%M:%S')" >> $OUT/phases.txt
python3 -I $R/tools/probe/gpumetrics_ts.py 55 > $OUT/pf-gm-a.txt 2>&1 & ./pfload 10 > $OUT/pf-a.out 2>&1 &
ssh -o BatchMode=yes $B "cd $BBIN; (python3 -I gpumetrics_ts.py 55 > gm-pf.txt 2>&1 &); ./pfload 10 > pf.out 2>&1"; wait
scp -q $B:$BBIN/gm-pf.txt $OUT/pf-gm-b.txt; scp -q $B:$BBIN/pf.out $OUT/pf-b.out
echo "end $(date '+%H:%M:%S')" >> $OUT/phases.txt; sleep 5
journalctl -k --since "$T0" -o short-precise --no-pager > $OUT/journal-a.txt
ssh -o BatchMode=yes $B "journalctl -k --since '$T0' -o short-precise --no-pager" > $OUT/journal-b.txt
for n in a b; do python3 -I $R/tools/probe/pmfdbg_parse.py $OUT/journal-$n.txt > $OUT/pmf-$n.tsv; echo "$n: $(($(wc -l < $OUT/pmf-$n.tsv)-1)) policy rows, $(grep -cE "amd-pmf .*: update " $OUT/journal-$n.txt) updates"; done
cat $OUT/phases.txt
