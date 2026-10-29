# Q8_0 원본에서 그룹별 비트 배분(llama-quantize --tensor-type-file)을 만든다. 정확한 텐서 이름 패턴, 지정 없는 텐서는 원래 형식 그대로.
# 256 블록 형식을 못 쓰는 차원(ne0 % 256 != 0)은 32 블록 형식으로 바꾼다.
#   make_mix.py <배분 이름> < gguf_head.py 텐서 줄(모든 조각)      배분: H, H5 (아래 PROFILES)
import sys, re
PROFILES = {
    # halogen v2 식: 전문가·몸통 4-bit, 혼합 층(hyper-connection) 6-bit, 전체 어텐션 o_proj 8-bit
    'H':  {'exp_gu': 'iq4_xs', 'exp_down': 'iq4_xs', 'attn_qkv': 'iq4_xs', 'attn_o': 'q8_0', 'gdn': 'iq4_xs', 'ssm_out': 'iq4_xs',
           'hc': 'q6_K', 'shexp': 'iq4_xs', 'ple_proj': 'q8_0', 'output': 'q6_K', 'tok_embd': 'q8_0', 'ple_table': 'iq4_nl', 'router': 'f32'},
    # H 에서 몸통(어텐션·GDN·공유 전문가)만 5-bit. Q5_K 가 아니라 Q5_0: gfx1151 에서 K 형식은 묶음 4(MTP 검증)에 1.7배 느려짐(quant/tbo-q4exp.txt)
    # 라우터(ffn_gate_inp)는 F32 그대로: 값이 BF16 이라(하위 16비트 0) BF16 이 손실 없지만 llama-quant.cpp 가 ffn_gate_inp 를 변환 대상에서 뺀다(패치 필요)
    'H5': {'exp_gu': 'iq4_xs', 'exp_down': 'iq4_xs', 'attn_qkv': 'q5_0', 'attn_o': 'q8_0', 'gdn': 'q5_0', 'ssm_out': 'q5_0',
           'hc': 'q6_K', 'shexp': 'q5_0', 'ple_proj': 'q8_0', 'output': 'q6_K', 'tok_embd': 'q8_0', 'ple_table': 'iq4_nl', 'router': 'f32'},
}
GROUP = [  # (그룹, 이름 끝부분 정규식) — 처음 맞는 것
    ('exp_gu', r'ffn_(gate|up)_exps\.weight$'), ('exp_down', r'ffn_down_exps\.weight$'),
    ('attn_o', r'blk\.\d+\.attn_output\.weight$'), ('attn_qkv', r'blk\.\d+\.attn_[qkv]\.weight$'),
    ('gdn', r'blk\.\d+\.attn_(qkv|gate)\.weight$'), ('ssm_out', r'ssm_out\.weight$'),
    ('hc', r'(hc_(attn|ffn)_(down|up)|output_hc_(down|up))\.weight$'), ('shexp', r'ffn_(gate|up|down)_shexp\.weight$'),
    ('ple_proj', r'ple_(key|value)\.weight$'), ('output', r'^output\.weight$'), ('tok_embd', r'^token_embd\.weight$'),
    ('ple_table', r'^per_layer_token_embd\.weight$'), ('router', r'ffn_gate_inp\.weight$'),
]
BLK256 = {'iq4_xs': 'iq4_nl', 'q4_K': 'iq4_nl', 'q5_K': 'q5_0', 'q6_K': 'q8_0', 'iq3_s': 'iq4_nl'}
NAMES = {'Q8_0': 'q8_0', 'IQ4_NL': 'iq4_nl', 'IQ3_S': 'iq3_s', 'IQ4_XS': 'iq4_xs', 'Q6_K': 'q6_K', 'Q5_K': 'q5_K', 'Q4_K': 'q4_K',
         'F32': 'f32', 'F16': 'f16', 'BF16': 'bf16'}
prof = PROFILES[sys.argv[1]]
out, count = [], {}
for line in sys.stdin:
    p = line.split()
    if len(p) < 4 or p[0] != 'T': continue
    name, ty = p[1], p[2]; ne0 = int(re.findall(r'\d+', p[3])[0])
    tgt = NAMES.get(ty, ty.lower())
    for g, rx in GROUP:
        if re.search(rx, name):
            tgt = prof[g]
            if tgt in BLK256 and ne0 % 256: tgt = BLK256[tgt]
            count[(g, tgt)] = count.get((g, tgt), 0) + 1
            break
    out.append('^' + name.replace('.', '\\.') + '$=' + tgt)
sys.stdout.write('\n'.join(out) + '\n')
for (g, t), n in sorted(count.items()): print(f"  {g:10} -> {t:7} x{n}", file=sys.stderr)
