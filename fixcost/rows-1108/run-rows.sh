#!/usr/bin/env bash
# 11-08 새벽: MoE down(IQ4_NL) 행렬곱을 블록당 행 2·4개로(mmvq.cu MMVQ_RDNA2_IQ4NL_ROWS, 값은 그대로여야 함).
# 순서: 앞 측정(ab-ahead.sh, PID $1)이 끝나기를 기다림 → 빌드(측정 없음) → def(build-rocm3, 행 1) / r2(build-half2) / r4(build-r4) none 2바퀴 + 감시기 회
LL=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/rows-1108
while kill -0 $1 2>/dev/null; do sleep 15; done
echo "== build $(date +%T)"
cd $LL
nice cmake --build build-half2 -j 30 --target ggml-rpc-server llama-server llama-bench > $O/r2-build.log 2>&1 || { echo "r2 build failed"; exit 1; }
[ -f build-r4/CMakeCache.txt ] || cmake -S . -B build-r4 -G Ninja -DCMAKE_MAKE_PROGRAM=/usr/bin/ninja -Dhip_DIR=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/rocm-cmake-prefix/lib/cmake/hip -DLLAMA_CURL=OFF -DGGML_HIP=ON -DGGML_RPC=ON -DGGML_RPC_RDMA=ON -DAMDGPU_TARGETS=gfx1151 -DGPU_TARGETS=gfx1151 -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=/opt/rocm/llvm/bin/clang -DCMAKE_CXX_COMPILER=/opt/rocm/llvm/bin/clang++ -DCMAKE_HIP_COMPILER=/opt/rocm/lib/llvm/bin/clang++ "-DCMAKE_HIP_FLAGS=-DMMVQ_RDNA2_IQ4NL_ROWS=4" > $O/r4-cmake.log 2>&1
nice cmake --build build-r4 -j 30 --target ggml-rpc-server llama-server llama-bench > $O/r4-build.log 2>&1 || { echo "r4 build failed"; exit 1; }
echo "== built $(date +%T)"; ls -la build-half2/bin/ggml-rpc-server build-r4/bin/ggml-rpc-server
sleep 60   # let the load settle (node-ab also waits for load < 0.6)
export BIN_r2=$LL/build-half2/bin BIN_r4=$LL/build-r4/bin
cd $O
OUTDIR=rows-1108 RUNS="${RUNS:-none:def none:r2 none:r4 none:def none:r2 none:r4}" bash $R/tools/bench/node-ab.sh
