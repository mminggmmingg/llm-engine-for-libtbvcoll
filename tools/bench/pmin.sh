#!/usr/bin/env bash
# 적응형 초안 길이: n-max × p-min 조합
cd "$(dirname "$(readlink -f "$0")")"   # tools/bench 에서(srv-probe.sh·gmsum.py·profsum.py 옆). 예전에는 세션 scratchpad 의 사본 pf/
for c in 4:0.5 3:0.5 4:0.8 3:0.8; do n=${c%:*}; p=${c#*:}; RUNS="$n" XSPEC="--spec-draft-p-min $p" PTAG="p$p" bash mtpn.sh 2>&1 | grep -vE "^== "; done
echo "== done $(date +%T)"
