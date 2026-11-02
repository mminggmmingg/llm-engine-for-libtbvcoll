#!/usr/bin/env bash
# 적응형 초안 길이: n-max × p-min 조합
S=/tmp/claude-1000/-data-parksThink-macos-reversing-claude-code/643ce5c3-138e-406c-bfc6-676a2e96b284/scratchpad/pf; cd $S
for c in 4:0.5 3:0.5 4:0.8 3:0.8; do n=${c%:*}; p=${c#*:}; RUNS="$n" XSPEC="--spec-draft-p-min $p" PTAG="p$p" bash mtpn.sh 2>&1 | grep -vE "^== "; done
echo "== done $(date +%T)"
