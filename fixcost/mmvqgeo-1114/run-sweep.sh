#!/usr/bin/env bash
# 11-14 (tubo 식 커널 배치 비교, 측정 전용 빌드): RDNA3.5 mmvq 2–4열(MTP 검증) 블록 배치 (워프 수, 블록당 행) 를 바꿔 test-backend-ops perf 를
# TP 반쪽 모양(5120x2560, 2560x5120, 출력 머리 124160x2560)에서 잰다. 변형마다 mmvq.cu 의 기본값 줄만 바꿔 test-backend-ops 만 다시 짓고,
# 정확성(test, CPU 비교)도 본다. 끝나면 기본값(0 = 한 워프·한 행)으로 되돌린다. A 노드 GPU 만 쓴다(서버 없음).
L=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp; O=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll/fixcost/mmvqgeo-1114
F=$L/ggml/src/ggml-cuda/mmvq.cu
P='m=(5120|2560|124160),n=[124],k=(2560|5120),'
setgeo() { sed -i "s/^#define MMVQ_RDNA2_NC4_WARPS .*/#define MMVQ_RDNA2_NC4_WARPS $1/; s/^#define MMVQ_RDNA2_NC4_ROWS .*/#define MMVQ_RDNA2_NC4_ROWS $2/" $F; }
for g in ${GEOS:-1:1 1:2 1:4 2:1 2:2 4:1 4:2}; do
  w=${g%:*}; r=${g#*:}; [ "$g" = 1:1 ] && { w=0; r=0; }
  setgeo $w $r; grep -n '^#define MMVQ_RDNA2_NC4' $F
  echo "== geo $g $(date +%T)"
  timeout 1800 /usr/bin/ninja -C $L/build-rocm3 test-backend-ops > $O/build-$g.log 2>&1 || { echo "build failed $g"; tail -5 $O/build-$g.log; continue; }
  timeout 900 $L/build-rocm3/bin/test-backend-ops test -b ROCm0 -o MUL_MAT -p "$P" > $O/test-$g.txt 2>&1; echo "test rc=$? $(grep -c 'OK$' $O/test-$g.txt) ok, $(grep -c FAIL $O/test-$g.txt) fail"
  timeout 900 $L/build-rocm3/bin/test-backend-ops perf -b ROCm0 -o MUL_MAT -p "$P" > $O/perf-$g.txt 2>&1; echo "perf rc=$?"
done
setgeo 0 0; grep -n '^#define MMVQ_RDNA2_NC4' $F
timeout 1800 /usr/bin/ninja -C $L/build-rocm3 test-backend-ops > $O/build-restore.log 2>&1; echo "restore build rc=$?"
echo ALLDONE
