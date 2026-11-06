# MTP 초안 GGUF 의 출력층을 일부 어휘로 줄인다(표준 라이브러리, 스트리밍 복사). output.weight 에서 고른 행만 남기고
# d2t(I64, 줄인 행 → 토큰 번호)를 붙인다 — 엔진은 그 행만 계산해 나머지 로짓을 -inf 로 둔다(초안만 바뀌고 출력은 검증이 정함).
#   gguf_draft_vocab.py <mtp.gguf> <ids.txt(한 줄에 토큰 번호 하나)> <출력.gguf>
import os, struct, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gguf_merge_mtp import parse, nbytes, TYPE_SIZE

GGML_TYPE_I64 = 27
TYPE_SIZE[GGML_TYPE_I64] = (1, 8)

src_p, ids_p, out_p = sys.argv[1], sys.argv[2], sys.argv[3]
A = parse(src_p); align = A['align']
ids = sorted({int(l) for l in open(ids_p) if l.strip()})
out_w = [t for t in A['tensors'] if t[0] == 'output.weight']
assert len(out_w) == 1 and not any(t[0] == 'd2t' for t in A['tensors'])
_, (n_embd, n_vocab), w_ty, w_off = out_w[0]
assert 0 <= ids[0] and ids[-1] < n_vocab
row = nbytes([n_embd], w_ty)

plan = []  # (name, dims, type, source: (abs offset, nbytes) or bytes)
for name, dims, ty, off in A['tensors']:
    if name == 'output.weight':
        plan.append((name, [n_embd, len(ids)], ty, ('rows', A['data'] + off)))
    else:
        plan.append((name, dims, ty, ('copy', A['data'] + off, nbytes(dims, ty))))
plan.append(('d2t', [len(ids)], GGML_TYPE_I64, ('bytes', struct.pack(f'<{len(ids)}q', *ids))))

out = open(out_p + '.tmp', 'wb')
w = lambda fmt, v: out.write(struct.pack('<' + fmt, v))
out.write(b'GGUF'); w('I', A['ver']); w('Q', len(plan)); w('Q', A['nkv'])
src = open(src_p, 'rb'); src.seek(A['kv'][0]); out.write(src.read(A['kv'][1] - A['kv'][0]))
off = 0; offs = []
for name, dims, ty, _ in plan:
    offs.append(off); off = (off + nbytes(dims, ty) + align - 1) // align * align
for (name, dims, ty, _), o in zip(plan, offs):
    b = name.encode(); w('Q', len(b)); out.write(b); w('I', len(dims))
    for d in dims: w('Q', d)
    w('I', ty); w('Q', o)
pad = (-out.tell()) % align; out.write(b'\0' * pad); data0 = out.tell()
for (name, dims, ty, s), o in zip(plan, offs):
    assert out.tell() == data0 + o
    nb = nbytes(dims, ty)
    if s[0] == 'rows':
        for i in ids:
            src.seek(s[1] + i * row); out.write(src.read(row))
    elif s[0] == 'bytes':
        out.write(s[1])
    else:
        src.seek(s[1]); left = s[2]
        while left:
            chunk = src.read(min(left, 64 << 20)); assert chunk; out.write(chunk); left -= len(chunk)
    out.write(b'\0' * ((-nb) % align))
out.close(); os.replace(out_p + '.tmp', out_p)
print(f"wrote {out_p}: output.weight {n_vocab} -> {len(ids)} rows, {os.path.getsize(out_p)/1e9:.2f} GB")
