#!/usr/bin/env bash
# 고정비 분해: 연산 종류를 GPU 에서 빼고(GGML_CUDA_SKIP_OPS, 결과는 틀림) 1노드 디코드 시간이 얼마나 주는지 잰다. 프로파일러 없이.
#   fixcost/ablate.sh <GGUF> <회차> <이름=환경 ...>    예) ablate.sh M 2 base= skipmm=GGML_CUDA_SKIP_OPS=MUL_MAT,MUL_MAT_ID
# 이름=환경 에 BENCH=<llama-bench 경로> 를 넣으면 그 바이너리로 잰다(빌드 변형 비교).
# 결과: runs/fixcost/ablate-<시각>/<이름>-<회차>.jsonl 과 gpum(클럭·전력 시계열), 요약 summary.txt
set -uo pipefail
D=$(cd "$(dirname "$0")/.." && pwd); M=$1 R=$2; shift 2
N=${N:-128}; OUT=$D/runs/fixcost/ablate-$(date +%m%d-%H%M%S); mkdir -p "$OUT"
for r in $(seq "$R"); do
  for cfg in "$@"; do
    name=${cfg%%=*}; envs=${cfg#*=}
    BENCH=$(echo "$envs" | sed -n 's/.*BENCH=\([^ ]*\).*/\1/p'); BENCH=${BENCH:-$D/llama.cpp/build-rocm/bin/llama-bench}
    python3 -I "$D/tools/probe/gpumetrics_ts.py" 600 > "$OUT/$name-$r.gpum" & GP=$!
    env LD_LIBRARY_PATH=/opt/rocm/lib $envs "$BENCH" -m "$M" -ngl 99 -fa 1 -p 0 -n "$N" -r 3 -o jsonl \
      > "$OUT/$name-$r.jsonl" 2> "$OUT/$name-$r.err"
    kill $GP 2>/dev/null
    python3 -I - "$OUT/$name-$r.jsonl" "$OUT/$name-$r.gpum" "$name" "$r" <<'PY' | tee -a "$OUT/summary.txt"
import json, sys
r = [json.loads(l) for l in open(sys.argv[1])]
g = [l.split() for l in open(sys.argv[2])]; g = [x for x in g if len(x) > 7 and int(x[3]) > 20]
ts = r[0]['samples_ts'] if r else []
clk = sum(int(x[1]) for x in g) / max(len(g), 1); w = sum(float(x[4]) for x in g) / max(len(g), 1); cw = sum(float(x[6]) for x in g) / max(len(g), 1)
print(f"{sys.argv[3]:>10} #{sys.argv[4]}  tok/s {' '.join(f'{t:6.2f}' for t in ts)}  ms/tok {1000/(sum(ts)/len(ts)) if ts else 0:6.2f}  gfx {clk:4.0f} MHz  sock {w:4.1f} W  core {cw:4.1f} W")
PY
  done
done
echo "$OUT"
