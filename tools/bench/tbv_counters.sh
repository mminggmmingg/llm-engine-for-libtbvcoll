#!/usr/bin/env bash
# tbv(debugfs) 카운터를 두 노드에서 저장 — A 에서 실행: tools/bench/tbv_counters.sh <tag>
#   /sys/kernel/debug/thunderbolt_ibverbs/{summary,peers} 는 root 만 읽으므로 sudo 비밀번호를 A 에서 한 번, B 에서(ssh -t) 한 번 묻는다.
#   측정 앞뒤로 한 번씩(before/after) 돌리면 그 사이 늘어난 값(RNR·credit·재전송·보조 폴링 등)을 비교할 수 있다.
#   결과: runs/tbv-counters/<tag>-{a,b}-{summary,peers}.txt
set -u
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
B=parks-zbook@10.99.0.2
tag=${1:?tag}
O=$R/runs/tbv-counters; mkdir -p $O
D=/sys/kernel/debug/thunderbolt_ibverbs
echo "== A(park2) sudo"
for f in summary peers; do
    sudo cat $D/$f > $O/$tag-a-$f.txt || exit 1
done
echo "== B(parks-zbook) sudo"
ssh -t $B "sudo -p '[B parks-zbook 비밀번호] ' sh -c 'cat $D/summary > /tmp/tbvc-summary.txt; cat $D/peers > /tmp/tbvc-peers.txt; chmod 644 /tmp/tbvc-*.txt'" || exit 1
for f in summary peers; do
    scp -q $B:/tmp/tbvc-$f.txt $O/$tag-b-$f.txt
done
wc -l $O/$tag-*.txt
