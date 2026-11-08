# node-ab.sh 의 RDMA 확인을 GGML_RPC_LOCAL_TCP(같은 노드 연결은 TCP)에서도 맞게: A 로그의 AR 링크 줄도 RDMA 로 친다
p = "/data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll/tools/bench/node-ab.sh"
s = open(p).read()
old1 = '[ "$(grep -c "RDMA activated" $d/rpc-a.log)" -ge 1 ] && break'
new1 = '[ "$(grep -cE "RDMA activated|allreduce link on .* [(]RDMA[)]" $d/rpc-a.log)" -ge 1 ] && break   # AR 링크 줄: GGML_RPC_LOCAL_TCP 이면 클라이언트 연결은 TCP'
old2 = 'rdma=$(grep -c "RDMA activated" $d/rpc-a.log)'
new2 = 'rdma=$(grep -cE "RDMA activated|allreduce link on .* [(]RDMA[)]" $d/rpc-a.log)'
assert s.count(old1) == 1 and s.count(old2) == 1
open(p, "w").write(s.replace(old1, new1).replace(old2, new2))
print("node-ab.sh patched")
