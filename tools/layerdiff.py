# 두 실행의 층별 텐서 덤프 비교(LLAMA_DEBUG_DUMP 로 llama-eval-callback 이 쓴 파일, numpy 필요).
#   layerdiff.py <a.bin> <b.bin> [positions, 예: 0,8,last]      — 층 출력(l_last-<층>)과 로짓
#   layerdiff.py ops <a.bin> <b.bin> <ubatch>                   — 한 ubatch(-ub 1 이면 토큰 하나)의 덤프된 텐서 모두를 실행 순서대로
#   layerdiff.py topk <a.bin> <b.bin>                           — ffn_moe_topk-<층>: 층마다 고른 전문가 집합이 달라진 토큰 수
# 텐서 이름마다 n 번째로 나온 것 = n 번째 ubatch(-ub 1 이면 n 번째 토큰). 이름·자리마다 상대 L2 차 ‖a−b‖/‖a‖, 최대 절대 차,
# 비트가 다른 원소 비율. result_output(로짓)은 KL(a‖b), 1위 토큰 같음 여부도.
import re, struct, sys
import numpy as np

def records(path):  # 덤프 순서 그대로 [(이름, 값)]
    out = []
    with open(path, 'rb') as f:
        while True:
            h = f.read(4)
            if len(h) < 4:
                break
            name = f.read(struct.unpack('<I', h)[0]).decode()
            ne = struct.unpack('<4q', f.read(32))
            out.append((name, np.frombuffer(f.read(4 * int(np.prod(ne))), dtype=np.float32).copy()))
    return out

def ubatches(path):  # ubatch 마다 기록 수가 같다고 보고(l_last-0 은 ubatch 에 한 번) 나눈다. 같은 ubatch 안에 같은 이름이 또 나오면 '#2'(attn·ffn 의 hc mix)
    recs = records(path); nub = sum(n == 'l_last-0' for n, _ in recs); per = len(recs) // nub; ub = []
    assert per * nub == len(recs), (len(recs), nub)
    for j, (name, v) in enumerate(recs):
        if j % per == 0:
            ub.append({})
        k = name; i = 2
        while k in ub[-1]:
            k = f"{name} #{i}"; i += 1
        ub[-1][k] = v
    return ub

def load(path):
    out = {}
    with open(path, 'rb') as f:
        while True:
            h = f.read(4)
            if len(h) < 4:
                break
            name = f.read(struct.unpack('<I', h)[0]).decode()
            ne = struct.unpack('<4q', f.read(32))
            out.setdefault(name, []).append(np.frombuffer(f.read(4 * int(np.prod(ne))), dtype=np.float32).copy())
            NE.setdefault(name, ne)
    return out

NE = {}

def per_token(L, n):  # 한 이름의 덤프들을 토큰 하나씩으로(ubatch 크기와 무관하게, -ub 1 과 -ub 4 비교용)
    w = NE[n][0] * (NE[n][1] if n.startswith('l_last') else 1)   # l_last: [n_embd, hc, 토큰], 로짓: [n_vocab, 토큰]
    x = np.concatenate(L) if L else np.zeros(0, np.float32)
    return list(x.reshape(-1, w)) if w and x.size % w == 0 else []

def stats(a, b):
    if a.size == 0:
        return None
    d = a.astype(np.float64) - b.astype(np.float64)
    na = np.linalg.norm(a.astype(np.float64))
    return np.linalg.norm(d) / na if na > 0 else 0.0, np.abs(d).max(), np.mean(a.view(np.uint32) != b.view(np.uint32))

def kl(a, b):
    la = a.astype(np.float64) - a.max(); lb = b.astype(np.float64) - b.max()
    pa = np.exp(la) / np.exp(la).sum(); lpa = la - np.log(np.exp(la).sum()); lpb = lb - np.log(np.exp(lb).sum())
    return float((pa * (lpa - lpb)).sum())

def ops(UA, UB, p):
    A, B = UA[p], UB[p]
    print(f"{'tensor':40s} {'elems':>8s} {'rel L2':>10s} {'max abs':>10s} {'bits differ':>12s}")
    for n in A:
        if n not in B or A[n].size == 0:
            continue
        a, b = A[n], B[n]
        if 'topk' in n or 'argsort' in n:   # 전문가 번호: 고른 집합이 같은지
            same = set(a.astype(int).tolist()) == set(b.astype(int).tolist())
            print(f"{n:40s} {a.size:8d} {'experts ' + ('same' if same else 'DIFFER: ' + str(sorted(set(a.astype(int).tolist()) ^ set(b.astype(int).tolist())))):>34s}")
            continue
        r, m, d = stats(a, b)
        print(f"{n:40s} {a.size:8d} {r:10.2e} {m:10.2e} {d:11.1%}")

def topk(A, B):
    names = sorted((n for n in A if re.fullmatch(r'ffn_moe_topk-\d+', n)), key=lambda n: int(n.split('-')[1]))
    first = {}
    print(f"{'layer':>5s} {'tokens':>7s} {'set differs':>12s} {'experts swapped (mean when differs)':>36s}")
    for n in names:
        il = int(n.split('-')[1]); nd = 0; sw = []
        for p, (a, b) in enumerate(zip(A[n], B[n])):
            x, y = set(a.astype(int).tolist()), set(b.astype(int).tolist())
            if x != y:
                nd += 1; sw.append(len(x - y)); first.setdefault(p, il)
        print(f"{il:5d} {len(A[n]):7d} {nd:12d} {(np.mean(sw) if sw else 0):36.2f}")
    print(f"tokens with any routing change: {len(first)}; earliest changed layer per token (pos:layer): " +
          ' '.join(f"{p}:{l}" for p, l in sorted(first.items())[:40]))

if __name__ == '__main__':
    if sys.argv[1] == 'topk':
        topk(load(sys.argv[2]), load(sys.argv[3]))
        sys.exit(0)
    if sys.argv[1] == 'ops':
        ops(ubatches(sys.argv[2]), ubatches(sys.argv[3]), int(sys.argv[4]))
        sys.exit(0)
    A, B = load(sys.argv[1]), load(sys.argv[2])
    layers = sorted((n for n in A if re.fullmatch(r'l_last-\d+', n)), key=lambda n: int(n.split('-')[1]))
    A = {n: per_token(A[n], n) for n in layers + ['result_output'] if n in A}
    B = {n: per_token(B[n], n) for n in layers + ['result_output'] if n in B}
    npos = max(len(A[n]) for n in layers)
    for n in A:   # 잘린 마지막 층·로짓(출력 토큰만): 마지막 자리로
        if len(A[n]) < npos:
            A[n] = [np.zeros(0, np.float32)] * (npos - len(A[n])) + A[n]; B[n] = [np.zeros(0, np.float32)] * (npos - len(B[n])) + B[n]
    want = sys.argv[3].split(',') if len(sys.argv) > 3 else ['0', str(npos // 2), 'last']
    pos = [npos - 1 if p == 'last' else int(p) for p in want]
    print('rel L2 ‖a−b‖/‖a‖ of the layer output (hc-wide residual), by token position; last column: median over all positions')
    print(f"{'tensor':16s}" + ''.join(f"{'pos ' + str(p):>12s}" for p in pos) + f"{'median':>12s}{'bits differ':>13s}")
    for n in layers:
        row = [stats(A[n][p], B[n][p]) if p < len(A[n]) else None for p in pos]
        allp = [s for s in (stats(x, y) for x, y in zip(A[n], B[n])) if s is not None]
        med = np.median([s[0] for s in allp]) if allp else float('nan')
        bits = np.mean([s[2] for s in allp]) if allp else float('nan')
        print(f"{n:16s}" + ''.join(f"{(s[0] if s else float('nan')):12.2e}" for s in row) + f"{med:12.2e}{bits:12.1%}")
    for i, (x, y) in enumerate(zip(A.get('result_output', []), B.get('result_output', []))):
        s = stats(x, y)
        if s is None:
            continue
        print(f"result_output #{i}: rel L2 {s[0]:.2e} max abs {s[1]:.2e} | KL(a||b) {kl(x, y):.2e} | top-1 a {int(x.argmax())} b {int(y.argmax())}")
