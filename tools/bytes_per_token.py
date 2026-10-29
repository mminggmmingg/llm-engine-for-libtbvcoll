# 디코드 1토큰에 읽는 가중치 양 추정(gguf_head.py 출력에서): 밀집은 전부, 전문가는 활성 비율만, 임베딩 조회는 제외. argv: n_expert n_used < 텐서 줄
import sys, re
ne, nu = int(sys.argv[1]), int(sys.argv[2])
BLK = {'Q5_K': (256, 176), 'Q4_K': (256, 144), 'F32': (1, 4), 'F16': (1, 2), 'BF16': (1, 2), 'Q8_0': (32, 34), 'Q6_K': (256, 210), 'IQ4_NL': (32, 18), 'IQ3_S': (256, 110), 'IQ4_XS': (256, 136)}
cat = {}
for line in sys.stdin:
    p = line.split()
    if len(p) < 4 or p[0] != 'T': continue
    name, ty = p[1], p[2]; dims = [int(x) for x in re.findall(r'\d+', ' '.join(p[3:]))]
    n = 1
    for d in dims: n *= d
    b = n // BLK[ty][0] * BLK[ty][1]
    if name in ('token_embd.weight', 'per_layer_token_embd.weight'): continue
    if '_exps' in name: b = b * nu / ne; k = 'experts(active)'
    elif re.search(r'\.(attn_|ssm_|indexer)', name): k = 'attn/GDN'
    elif '.hc_' in name or 'output_hc' in name: k = 'hyper-connection'
    elif name == 'output.weight': k = 'output head'
    elif 'shexp' in name or 'gate_inp' in name: k = 'shared expert + router'
    else: k = 'other'
    cat[k] = cat.get(k, 0) + b
for k, v in sorted(cat.items(), key=lambda x: -x[1]): print(f"  {v/1e9:5.2f} GB  {k}")
print(f"  total {sum(cat.values())/1e9:.2f} GB per token")
