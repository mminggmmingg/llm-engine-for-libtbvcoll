# 1층 shared expert 에서 차이가 커지는 이유 나누기(numpy + gguf-py): 덤프(LLAMA_DEBUG_DUMP)의 입력 x 를 끔/S=2 두 판으로,
# 가중치를 GGUF 에서 풀어 (1) 활성값 f32 그대로 W·x  (2) mmvq 처럼 활성값을 q8_1(32개마다 amax/127, f16 스케일)로 반올림한 W·q8(x)
# 를 계산해, 두 판의 출력 차이가 반올림 때문인지 행렬곱 자체 때문인지 본다.
#   amplify.py <gguf-py 경로> <model.gguf> <off.bin> <s2.bin> <층> [ubatch]
#   amplify.py <gguf-py 경로> flips <off.bin> <s2.bin> [ubatch]   — 양자화 행렬곱의 입력마다 q8_1 반올림 칸이 바뀐 값 수(가중치 없이)
import sys
sys.path.insert(0, sys.argv[1])
import numpy as np, gguf
sys.path.insert(0, __file__.rsplit('/', 3)[0] + '/tools')
import layerdiff

def q8_1(x):   # quantize_q8_1: d = amax/127, q = round(x/d), ds = half2(d, Σx) — 블록 합은 원래 값의 합을 f16 으로
    b = x.astype(np.float32).reshape(-1, 32)
    d = (np.abs(b).max(axis=1) / 127).astype(np.float32)
    q = np.round(np.where(d[:, None] > 0, b / np.where(d > 0, d, 1)[:, None], 0)).astype(np.int32)
    return q, d.astype(np.float16).astype(np.float32)

def q8_sum(x):
    return x.astype(np.float32).reshape(-1, 32).sum(axis=1, dtype=np.float32).astype(np.float16).astype(np.float32)

def q5_0_scales(t):   # 블록(22 바이트) 앞의 f16 d
    raw = np.asarray(t.data, dtype=np.uint8).reshape(int(t.shape[1]), -1, 22)
    return raw[:, :, :2].copy().view(np.float16)[:, :, 0].astype(np.float64)

def kernel_q5_0(w, d5, x):   # vec_dot_q5_0_q8_1: d5·(sumi·d8 − 16·s8) = W·deq8(x) + 16·d5·(d8·Σq − s8)
    q, d = q8_1(x); s8 = q8_sum(x)
    return w @ deq8(q, d) + 16 * d5 @ (d * q.sum(axis=1) - s8)

def deq8(q, d):
    return (q * d[:, None]).reshape(-1)

def rel(a, b):
    return np.linalg.norm(a.astype(np.float64) - b) / np.linalg.norm(a.astype(np.float64))

if sys.argv[2] == 'flips':
    ub = int(sys.argv[5]) if len(sys.argv) > 5 else 0
    UA, UB = layerdiff.ubatches(sys.argv[3])[ub], layerdiff.ubatches(sys.argv[4])[ub]
    INPUTS = ('hc_mixed-', 'final_output-', 'ffn_swiglu-', 'ffn_moe_swiglu-', 'z-')
    print(f"{'matmul input':28s} {'values':>7s} {'rel diff':>9s} {'q8 step changed':>16s} {'block scale changed':>20s} {'f16 block sum changed':>22s}")
    for n in UA:
        if n.startswith(INPUTS) and n in UB and UA[n].size % 32 == 0 and UA[n].size:
            qa, da = q8_1(UA[n]); qb, db = q8_1(UB[n])
            sa, sb = q8_sum(UA[n]), q8_sum(UB[n])
            print(f"{n:28s} {qa.size:7d} {rel(UA[n], UB[n]):9.2e} {int((qa != qb).sum()):16d} {int((da != db).sum()):14d} of {da.size} {int((sa != sb).sum()):14d} of {da.size}")
    sys.exit(0)
r = gguf.GGUFReader(sys.argv[2]); il = int(sys.argv[5]); ub = int(sys.argv[6]) if len(sys.argv) > 6 else 0
W = {t.name: t for t in r.tensors}
def mat(name):
    t = W[name]
    return gguf.quants.dequantize(t.data, t.tensor_type).reshape(int(t.shape[1]), int(t.shape[0])).astype(np.float64), t.tensor_type.name

UA, UB = layerdiff.ubatches(sys.argv[3])[ub], layerdiff.ubatches(sys.argv[4])[ub]
xa, xb = UA[f'hc_mixed-{il} #2'], UB[f'hc_mixed-{il} #2']
print(f"layer {il} ubatch {ub}: FFN input (hc_mixed #2) rel diff {rel(xa, xb):.2e}")
for nm, x_a, x_b, dump in ((f'blk.{il}.ffn_gate_shexp.weight', xa, xb, f'ffn_gate-{il}'),
                           (f'blk.{il}.ffn_up_shexp.weight', xa, xb, f'ffn_up-{il}'),
                           (f'blk.{il}.ffn_down_shexp.weight', UA[f'ffn_swiglu-{il}'], UB[f'ffn_swiglu-{il}'], f'ffn_shexp-{il}')):
    w, ty = mat(nm)
    qa, da = q8_1(x_a); qb, db = q8_1(x_b)
    flips = int((qa != qb).sum()); dsame = int((da == db).sum())
    yf_a, yf_b = w @ x_a.astype(np.float64), w @ x_b.astype(np.float64)
    yq_a, yq_b = w @ deq8(qa, da), w @ deq8(qb, db)
    ssame = int((q8_sum(x_a) == q8_sum(x_b)).sum())
    yk = ''
    if ty == 'Q5_0':
        d5 = q5_0_scales(W[nm]); ka, kb = kernel_q5_0(w, d5, x_a), kernel_q5_0(w, d5, x_b)
        yk = f", kernel formula (with f16 block sums) {rel(ka, kb):.2e} (vs dumped off: {rel(UA[dump], ka.astype(np.float32)):.1e})"
    print(f"{nm:32s} {ty:7s} input rel {rel(x_a, x_b):.2e} | q8_1: {flips} of {qa.size} values change a step, scales same {dsame}/{da.size},"
          f" f16 block sums same {ssame}/{da.size} | out rel: f32 act {rel(yf_a, yf_b):.2e}, int8 values only {rel(yq_a, yq_b):.2e}{yk},"
          f" dumped {rel(UA[dump], UB[dump]):.2e}")
