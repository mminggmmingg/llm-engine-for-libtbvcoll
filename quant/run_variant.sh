#!/usr/bin/env bash
# 밀집 부분 형식 변형 하나: (사용자 허락 2026-10-29) 이전 변형 파일만 지우고 → 변환 → 1노드 디코드(tg128 × 5) → PPL(1node)
#   [IMATRIX=<imatrix.gguf>] [SRC=<원본 첫 조각>] [NAME=<결과 이름 앞부분>] [THREADS=16] quant/run_variant.sh <types 파일> <태그>
#   결과: quant/<태그>.log, 마지막 줄 요약. 기본 원본은 UD-IQ4_XS, Q8_0 원본이면 SRC 를 준다.
set -uo pipefail
D=$(cd "$(dirname "$0")/.." && pwd); TYPES=$1 TAG=$2
G=/data/parksThink/hf-models/qwen38-flash-next-gguf; VD=$G/UD-IQ4_XS-dense4
SRC=${SRC:-$G/UD-IQ4_XS/Qwen3.8-Flash-Next-UD-IQ4_XS-00001-of-00003.gguf}
OUT=$VD/${NAME:-Qwen3.8-Flash-Next-UD-IQ4_XS}-$TAG.gguf; L=$D/quant/$TAG.log
export LD_LIBRARY_PATH=/opt/rocm/lib
# 변형 디렉터리 안, 이 이름 형식의 파일만 지운다(원본·다른 파일은 건드리지 않음)
for f in "$VD"/Qwen3.8-Flash-Next-*.gguf; do [ -f "$f" ] && { echo "remove variant $f" | tee -a "$L"; rm -f -- "$f"; }; done
"$D/llama.cpp/build-rocm/bin/llama-quantize" --allow-requantize --pure ${IMATRIX:+--imatrix "$IMATRIX"} --tensor-type-file "$TYPES" "$SRC" "$OUT" IQ4_NL ${THREADS:-16} >> "$L" 2>&1 || { echo "quantize failed"; exit 1; }
grep -E 'model size|quant size' "$L" | tail -2
TG=$("$D/llama.cpp/build-rocm/bin/llama-bench" -m "$OUT" -ngl 99 -fa on -p 0 -n 128 -r 5 -o md 2>/dev/null | grep tg128 | awk -F'|' '{print $(NF-1)}')
PPL=$("$D/eval_ppl.sh" "$OUT" 1node 2>&1 | grep -o 'PPL = [0-9.]* +/- [0-9.]*')
BPT=$(python3 -I "$D/tools/gguf_head.py" "$OUT" | python3 -I "$D/tools/bytes_per_token.py" 512 10 | tail -1)
echo "$TAG: tg128 $TG | $PPL | $BPT" | tee -a "$L"
