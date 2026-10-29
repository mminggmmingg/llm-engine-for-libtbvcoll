# llama-quantize --tensor-type-file 만들기: 고른 그룹의 Q8_0 밀집 텐서만 목표 형식으로, 나머지는 원래 형식 그대로(정확한 이름 패턴).
#   make_types.py <목표 형식(예: iq4_nl)> <그룹,...> < gguf_head.py 텐서 줄     그룹: attn, gdn, hc, shexp, ple
import sys, re
target, groups = sys.argv[1], set(sys.argv[2].split(','))
G = {'attn': {'attn_q', 'attn_k', 'attn_v', 'attn_output'},           # 전체 어텐션 12층
     'gdn':  {'attn_qkv', 'attn_gate', 'ssm_out'},                     # GDN 36층
     'hc':   {'hc_attn_down', 'hc_attn_up', 'hc_ffn_down', 'hc_ffn_up', 'output_hc_down', 'output_hc_up'},
     'shexp': {'ffn_down_shexp', 'ffn_gate_shexp', 'ffn_up_shexp'},
     'ple':  {'ple_key', 'ple_value'}}
sel = set().union(*(G[g] for g in groups))
NAMES = {'Q8_0': 'q8_0', 'IQ4_NL': 'iq4_nl', 'IQ3_S': 'iq3_s', 'IQ4_XS': 'iq4_xs', 'Q6_K': 'q6_K', 'F32': 'f32', 'BF16': 'bf16'}
out, n = [], 0
for line in sys.stdin:
    p = line.split()
    if len(p) < 3 or p[0] != 'T': continue
    name, ty = p[1], p[2]
    base = re.sub(r'^blk\.\d+\.', '', name).removesuffix('.weight')
    tgt = NAMES[ty]
    if ty == 'Q8_0' and base in sel: tgt = target; n += 1
    out.append('^' + name.replace('.', '\\.') + '$=' + tgt)
sys.stdout.write('\n'.join(out) + '\n')
print(f"{len(out)} patterns, {n} tensors -> {target} ({','.join(sorted(groups))})", file=sys.stderr)
