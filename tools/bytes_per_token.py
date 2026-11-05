# 디코드 1토큰에 읽는 가중치 양 추정(gguf_head.py 출력에서): 밀집은 전부, 전문가는 활성 비율만, 임베딩 조회는 제외.
# argv: n_expert n_used [loaded] [tp=N] < 텐서 줄
#   loaded: 엔진이 불러올 때 바꾸는 것까지(qwen4exp.cpp: 라우터 F32 → BF16, 같은 입력 가중치 합치기는 형식이 다르면 바이트가 큰 쪽 형식으로)
#   tp=N: --split-mode tensor 에서 노드 하나가 읽는 양(llama-model.cpp llama_meta_device_get_split_state 규칙: 나뉘는 텐서는 1/N, 나머지는 복제)
import sys, re
ne, nu = int(sys.argv[1]), int(sys.argv[2])
loaded = 'loaded' in sys.argv[3:]
tp = next((int(a[3:]) for a in sys.argv[3:] if a.startswith('tp=')), 1)
BLK = {'Q5_K': (256, 176), 'Q4_K': (256, 144), 'F32': (1, 4), 'F16': (1, 2), 'BF16': (1, 2), 'Q8_0': (32, 34), 'Q6_K': (256, 210), 'IQ4_NL': (32, 18), 'IQ3_S': (256, 110), 'IQ4_XS': (256, 136), 'Q5_0': (32, 22), 'Q4_0': (32, 18), 'Q4_1': (32, 20), 'Q5_1': (32, 24), 'MXFP4': (32, 17)}
SPLIT = re.compile(r'(^output\.weight$)|\.(attn_(q|k|v|qkv|gate|output)|ssm_(alpha|beta|conv1d|out)|ffn_(up|gate|down)(_exps)?)\.weight$|\.ssm_(a|dt\.bias)$')
MERGE = [('hc_attn_down', 'hc_attn_inject'), ('hc_ffn_down', 'hc_ffn_inject'), ('attn_qkv', 'attn_gate'), ('ssm_beta', 'ssm_alpha')]
nbytes = lambda n, ty: n // BLK[ty][0] * BLK[ty][1]
ts = {}
for line in sys.stdin:
    p = line.split()
    if len(p) < 4 or p[0] != 'T': continue
    n = 1
    for d in re.findall(r'\d+', ' '.join(p[3:])): n *= int(d)
    ts[p[1]] = [p[2], n]
if loaded:
    for name, t in ts.items():
        if re.match(r'blk\.\d+\.ffn_gate_inp\.weight$', name) and t[0] == 'F32': t[0] = 'BF16'
        m = re.match(r'(blk\.\d+\.)(\w+)\.weight$', name)
        for a, b in MERGE:
            if not m or m.group(2) != a or m.group(1) + b + '.weight' not in ts: continue
            ta, tb = t, ts[m.group(1) + b + '.weight']
            ty = ta[0] if nbytes(ta[1], ta[0]) >= nbytes(tb[1], tb[0]) else tb[0]
            ta[0] = tb[0] = ty
cat, node = {}, {}
for name, (ty, n) in ts.items():
    b = nbytes(n, ty)
    if name in ('token_embd.weight', 'per_layer_token_embd.weight'): continue
    if '_exps' in name: b = b * nu / ne; k = 'experts(active)'
    elif re.search(r'\.(attn_|ssm_|indexer)', name): k = 'attn/GDN'
    elif '.hc_' in name or 'output_hc' in name: k = 'hyper-connection'
    elif name == 'output.weight': k = 'output head'
    elif 'shexp' in name or 'gate_inp' in name: k = 'shared expert + router'
    else: k = 'other'
    cat[k] = cat.get(k, 0) + b
    node[k] = node.get(k, 0) + (b / tp if SPLIT.search(name) else b)
for k, v in sorted(cat.items(), key=lambda x: -x[1]):
    print(f"  {v/1e9:5.2f} GB  {k}" + (f"  (노드당 {node[k]/1e9:5.2f})" if tp > 1 else ''))
print(f"  total {sum(cat.values())/1e9:.2f} GB per token" + (f", per node {sum(node.values())/1e9:.2f} GB (tp={tp})" if tp > 1 else ''))
