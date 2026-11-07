#!/usr/bin/env bash
# 11-08 새벽: MoE down 행 4개를 기본으로 build-rocm3 다시 빌드 + Q5_0(GDN qkv·ssm_out·attn_q, K 2560–3072) 도 블록당 행 2·4개로
# (mmvq.cu MMVQ_RDNA2_Q5_0_ROWS, 값은 그대로여야 함). 앞 측정(PID $1)이 끝나기를 기다림 → 빌드(측정 없음) → none def/q5r2/q5r4 2바퀴 + 감시기 회
LL=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/llama.cpp
R=/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll
O=$R/fixcost/q5rows-1108
CFG="-G Ninja -DCMAKE_MAKE_PROGRAM=/usr/bin/ninja -Dhip_DIR=/data/parksThink/macos_reversing/codex/zbook-rdma/experiments/engine2n/rocm-cmake-prefix/lib/cmake/hip -DLLAMA_CURL=OFF -DGGML_HIP=ON -DGGML_RPC=ON -DGGML_RPC_RDMA=ON -DAMDGPU_TARGETS=gfx1151 -DGPU_TARGETS=gfx1151 -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=/opt/rocm/llvm/bin/clang -DCMAKE_CXX_COMPILER=/opt/rocm/llvm/bin/clang++ -DCMAKE_HIP_COMPILER=/opt/rocm/lib/llvm/bin/clang++"
while kill -0 $1 2>/dev/null; do sleep 15; done
echo "== build $(date +%T)"
cd $LL
nice cmake --build build-rocm3 -j 30 --target ggml-rpc-server llama-server llama-bench llama-cli llama-perplexity > $O/def-build.log 2>&1 || { echo "def build failed"; exit 1; }
for v in 2 4; do
  [ -f build-q5r$v/CMakeCache.txt ] || cmake -S . -B build-q5r$v $CFG "-DCMAKE_HIP_FLAGS=-DMMVQ_RDNA2_Q5_0_ROWS=$v" > $O/q5r$v-cmake.log 2>&1
  nice cmake --build build-q5r$v -j 30 --target ggml-rpc-server llama-server llama-bench > $O/q5r$v-build.log 2>&1 || { echo "q5r$v build failed"; exit 1; }
done
echo "== built $(date +%T)"; ls -la build-rocm3/bin/ggml-rpc-server build-q5r2/bin/ggml-rpc-server build-q5r4/bin/ggml-rpc-server
sleep 60   # let the load settle (node-ab also waits for load < 0.6)
export BIN_q5r2=$LL/build-q5r2/bin BIN_q5r4=$LL/build-q5r4/bin
cd $O
OUTDIR=q5rows-1108 RUNS="${RUNS:-none:def none:q5r2 none:q5r4 none:def none:q5r2 none:q5r4}" bash $R/tools/bench/node-ab.sh
echo "== done $(date +%T)"
