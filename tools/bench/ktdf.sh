#!/usr/bin/env bash
# 2노드 디코드(llama-bench -n N, A 서버 커널 기록) 중 A 의 DRAM 읽기 바이트/토큰 — 커널 기록 타임스탬프로 디코드 구간(첫 GDN ~ 마지막 GDN)을 잡아
# inferwatch sample-dram(CLOCK_MONOTONIC → BOOTTIME 으로 옮김)을 그 구간만 적분, 쉬는 몫(앞 20 구간 중앙값) 뺌. 서버 환경은 SRVX(두 서버).
#   tools/bench/ktdf.sh <tag> [토큰 수=64]   결과 한 줄: tg t/s, DF GB/토큰. 시간 제한 있음(프로파일 20분).
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
IWB=${IWB:-/data/parksThink/inferwatch-iw-20261110-1/target/release/inferwatch}
tag=${1:?tag}; N=${2:-64}; W=$(mktemp -d /tmp/ktdf.XXXXXX)
setsid -f bash -c "echo \$\$ > $W/pid; exec $IWB sample-dram 1500 50 $W/df.txt" > /dev/null 2>&1 < /dev/null; sleep 0.5
OFF=$(python3 -I -c "import time; print(time.clock_gettime_ns(time.CLOCK_BOOTTIME) - time.clock_gettime_ns(time.CLOCK_MONOTONIC))")
timeout 1200 bash $R/tools/bench/prof2node.sh $tag $N > $W/prof.log 2>&1
kill -TERM -- -$(cat $W/pid); sleep 1
d=$(tail -1 $W/prof.log); cp $W/df.txt $d/df-a.txt
python3 -I - $d $d/df-a.txt $OFF <<'PY'
import csv, sys
d, dff, OFF = sys.argv[1], sys.argv[2], int(sys.argv[3])
g = sorted((int(r['Start_Timestamp']), int(r['End_Timestamp'])) for r in csv.DictReader(open(d + '/a_kernel_trace.csv')) if 'gated_delta_net' in r['Kernel_Name'][:40])
t0, t1 = g[0][0], g[-1][1]; ntok = len(g) / 36
df = [(e + OFF, b, dt) for e, b, dt in (tuple(map(int, l.split())) for l in open(dff) if not l.startswith('#'))]
idle = sorted(b / (dt / 1e9) for e, b, dt in df[:20])[10]
tot = sum(b * max(0, min(e, t1) - max(e - dt, t0)) / dt for e, b, dt in df)
win = (t1 - t0) / 1e9
tg = [l for l in open(d + '/bench.txt') if "tg" in l and "|" in l and "t/s" not in l]
print(f'{d.rsplit("/",1)[-1]}: {tg[-1].split("|")[-2].strip() if tg else "?"} t/s; DF {(tot - idle*win)/ntok/1e9:.3f} GB/token (window {win:.2f} s, {ntok:.0f} tokens, idle {idle/1e9:.2f} GB/s)')
PY
