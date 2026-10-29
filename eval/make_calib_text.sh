#!/usr/bin/env bash
# imatrix 보정용 글(eval/imatrix_calib.txt): 평가 글(build.md, function-calling.md, server README)과 겹치지 않게
# llama.cpp 의 다른 문서 + 우리 한국어 기록 + C++/Python 코드 일부를 섞는다.
set -euo pipefail
D=$(cd "$(dirname "$0")/.." && pwd); L=$D/llama.cpp
{
  for f in "$L"/docs/*.md "$L"/docs/backend/*.md; do
    case "$(basename "$f")" in build.md|function-calling.md) continue ;; esac
    cat "$f"; echo
  done
  cat "$D/RESULTS.md" "$D/DESIGN.md"; echo
  cat "$L/src/llama-sampler.cpp" "$L/common/speculative.cpp" "$L/gguf-py/gguf/gguf_reader.py"
} > "$D/eval/imatrix_calib.txt"
wc -c "$D/eval/imatrix_calib.txt"
