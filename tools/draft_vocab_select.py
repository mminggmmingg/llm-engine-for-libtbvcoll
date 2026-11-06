# 초안 어휘 고르기(표준 라이브러리): 말뭉치(draft_vocab_corpus.py)에 나온 토큰을 많은 순으로, 모자라면 토큰 번호가 작은 순
# (BPE 병합 순서 = 토크나이저 말뭉치의 빈도 순)으로 보통 토큰 K 개를 채우고, 보통이 아닌 토큰(제어·사용자 정의 등)은 모두 넣는다.
# ko 를 주면 한글이 든 토큰을 모두 더한다(이 어휘의 한글 토큰은 대부분 뒤쪽 다국어 확장 구간에 있어 번호 순으로는 안 들어옴).
#   draft_vocab_select.py <corpus.jsonl> <K> <model.gguf> <ids.txt> [ko]
import collections, json, re, struct, sys

def vocab(path):
    f = open(path, 'rb')
    rd = lambda fmt: struct.unpack('<' + fmt, f.read(struct.calcsize('<' + fmt)))[0]
    def s(): n = rd('Q'); return f.read(n).decode('utf-8', 'replace')
    SC = {0: 'B', 1: 'b', 2: 'H', 3: 'h', 4: 'I', 5: 'i', 6: 'f', 7: '?', 10: 'Q', 11: 'q', 12: 'd'}
    def val(t):
        if t in SC: return rd(SC[t])
        if t == 8: return s()
        if t == 9:
            et = rd('I'); n = rd('Q'); return [val(et) for _ in range(n)]
        raise ValueError(t)
    assert f.read(4) == b'GGUF'; rd('I'); rd('Q'); nkv = rd('Q')
    kv = {}
    for _ in range(nkv):
        k = s(); v = val(rd('I'))
        if k in ('tokenizer.ggml.tokens', 'tokenizer.ggml.token_type'): kv[k] = v
    return kv['tokenizer.ggml.tokens'], kv['tokenizer.ggml.token_type']

def byte_decoder():
    # GPT-2 byte-level BPE: each byte is shown as one printable character
    bs = list(range(ord('!'), ord('~') + 1)) + list(range(ord('¡'), ord('¬') + 1)) + list(range(ord('®'), ord('ÿ') + 1))
    cs = bs[:]; n = 0
    for b in range(256):
        if b not in bs: bs.append(b); cs.append(256 + n); n += 1
    return {chr(c): b for b, c in zip(bs, cs)}

corpus_p, k, model_p, out_p = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
add_ko = len(sys.argv) > 5 and sys.argv[5] == 'ko'
tokens, types = vocab(model_p)
normal = [t == 1 for t in types]
count = collections.Counter(t for l in open(corpus_p) for t in json.loads(l)['tokens'])
seen = sorted((t for t in count if normal[t]), key=lambda t: (-count[t], t))
chosen = set(seen[:k])
for t in range(len(types)):
    if len(chosen) >= k: break
    if normal[t]: chosen.add(t)
chosen |= {t for t in range(len(types)) if not normal[t]}
n_ko = 0
if add_ko:
    u2b = byte_decoder(); han = re.compile('[\uac00-\ud7a3\u3131-\u318e]')
    for t in range(len(types)):
        if normal[t] and all(c in u2b for c in tokens[t]) and han.search(bytes(u2b[c] for c in tokens[t]).decode('utf-8', 'replace')):
            n_ko += 1; chosen.add(t)
open(out_p, 'w').write(''.join(f'{t}\n' for t in sorted(chosen)))
total = sum(count.values()); cov = sum(c for t, c in count.items() if t in chosen)
print(f"corpus {total} tokens, {len(count)} distinct; chose {len(chosen)} ids ({min(k, len(seen))} seen in the corpus, {n_ko} hangul); "
      f"corpus coverage {cov / total:.4f}")
