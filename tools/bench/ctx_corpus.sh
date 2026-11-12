#!/usr/bin/env bash
# 컨텍스트 길이 벤치(ctx_bench.py)의 문맥 글: 상류 llama.cpp 커밋의 docs/**/*.md·tools/server/README.md(앞) + src/*.cpp(뒤)를
# 경로 순서대로 이어 붙인다(우리 수정이 섞이지 않게 git 커밋에서 읽음). 영어 문서 ≈ 앞 10%, 나머지 C++ 코드.
#   ctx_corpus.sh <llama.cpp git 폴더> <커밋> <출력 .txt>   → 출력의 sha256 을 찍는다
set -euo pipefail
L=${1:?llama.cpp dir}; C=${2:?commit}; O=${3:?out}
git -C "$L" ls-tree -r --name-only "$C" -- docs src tools/server |
  awk '/^docs\/.*\.md$/ || /^tools\/server\/README\.md$/ {print "1 " $0; next} /^src\/.*\.cpp$/ {print "2 " $0}' | sort | cut -d' ' -f2 |
  while read -r f; do printf '\n\n===== %s =====\n\n' "$f"; git -C "$L" show "$C:$f"; done > "$O"
sha256sum "$O"
