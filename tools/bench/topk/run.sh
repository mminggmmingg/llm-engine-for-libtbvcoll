#!/usr/bin/env bash
# topk_moe 같은 값 확인: 원래 ds_bpermute 판(-DGGML_CUDA_NO_XOR_DPP)의 일반 커널과, DPP 판의 일반·lean 커널 출력을 바이트로 비교한다.
#   tools/bench/topk/run.sh   (A 에서, 빌드 산출물은 스크래치 폴더에)
set -eu
H=$(cd "$(dirname "$0")" && pwd); L=$(readlink -f "$H/../../../llama.cpp"); W=${W:-/tmp/topk-exact}; mkdir -p "$W"
python3 - "$L" "$W" <<'PY'
import sys
s = open(sys.argv[1] + '/ggml/src/ggml-cuda/topk-moe.cu').read()
a = s.index('// Kernel config struct'); b = s.index('template<bool has_bias>\nstatic void launch_topk_moe_cuda(')
open(sys.argv[2] + '/topk_kernel3.inc', 'w').write(s[a:b])
PY
F="-DGGML_USE_HIP -D__HIP_PLATFORM_AMD__=1 -D__HIP_ROCclr__=1 -I$L/ggml/src -I$L/ggml/include -I$W -O3 -std=gnu++17 --offload-arch=gfx1151 -x hip -L/opt/rocm/lib -lamdhip64"
/opt/rocm/lib/llvm/bin/clang++ $F -DGGML_CUDA_NO_XOR_DPP "$H/topk_exact.cu" -o "$W/ref"
/opt/rocm/lib/llvm/bin/clang++ $F "$H/topk_exact.cu" -o "$W/new"
LD_LIBRARY_PATH=/opt/rocm/lib "$W/ref" "$W/ref.bin"; LD_LIBRARY_PATH=/opt/rocm/lib "$W/new" "$W/new.bin"
cmp "$W/ref.bin" "$W/new.bin" && echo "같음: 원래(bpermute) 일반·lean == DPP 일반·lean (파일 전체)"
# 한 파일 안에서 일반 커널 블록과 lean 커널 블록 비교(행 1/4/8 × norm 끔/켬 × 200 회)
python3 -I - "$W/ref.bin" <<'PY'
import sys
r = open(sys.argv[1], 'rb').read(); off = 0; bad = 0; n = 0
for rows in (1, 4, 8):
    for norm in (0, 1):
        for t in range(200):
            sz = 10*rows*2*4; bad += r[off:off+sz] != r[off+sz:off+2*sz]; n += 1; off += 2*sz
print(f"일반 vs lean: {n} 경우 중 다름 {bad} (읽은 바이트 {off}/{len(r)})")
PY
