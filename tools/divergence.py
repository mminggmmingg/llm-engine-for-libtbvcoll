# 두 설정의 생성 비교용 기록(표준 라이브러리): 프롬프트마다 greedy 로 낸 토큰 번호와 자리마다 상위 2개 후보의 확률을 남긴다.
#   divergence.py <server URL> <prompts.json> <max_tokens> <out.jsonl>   (srv-probe.sh 의 BENCH 로도: 서버 주소가 첫 인자)
#   divergence.py diff <a.jsonl> <b.jsonl>      — 프롬프트마다 처음 갈린 토큰 자리, 그 자리에서 a·b 각각의 1·2위 로그확률과 차
import json, sys, urllib.request

def post(url, path, body):
    req = urllib.request.Request(url + path, data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(req, timeout=1800))

def run(url, pfile, nmax, out):
    with open(out, "w") as f:
        for p in json.load(open(pfile, encoding='utf-8')):
            prompt = post(url, "/apply-template", {"messages": [{"role": "user", "content": p["text"]}]})["prompt"]
            r = post(url, "/completion", {"prompt": prompt, "n_predict": nmax, "temperature": 0, "cache_prompt": False,
                                          "return_tokens": True, "n_probs": 2, "post_sampling_probs": False})
            top = []
            for c in r.get("completion_probabilities", []):
                cand = c.get("top_logprobs") or c.get("probs") or []
                top.append([[x.get("id"), x.get("logprob", x.get("prob"))] for x in cand[:2]])
            f.write(json.dumps({"id": p["id"], "tokens": r["tokens"], "top2": top, "content": r.get("content", "")}, ensure_ascii=False) + "\n"); f.flush()
            print(p["id"], len(r["tokens"]), flush=True)

def align(tokens, top2):
    # 확률 기록은 UTF-8 이 덜 끝난 토큰들을 한 칸으로 합칠 수 있다(한국어). greedy 라 칸의 1위 = 그 칸의 첫 토큰 → 토큰 자리 → 칸 번호
    m, e = {}, 0
    for i, t in enumerate(tokens):
        if e < len(top2) and top2[e] and top2[e][0][0] == t:
            m[i] = e; e += 1
    return m

def diff(pa, pb):
    A = {j["id"]: j for j in map(json.loads, open(pa))}
    B = {j["id"]: j for j in map(json.loads, open(pb))}
    for k in A:
        ta, tb = A[k]["tokens"], B[k]["tokens"]
        n = next((i for i in range(min(len(ta), len(tb))) if ta[i] != tb[i]), None)
        if n is None:
            print(f"{k:10s} same {len(ta)} tokens")
            continue
        out = f"{k:10s} first differs at token {n} of {len(ta)}: a {ta[n]} b {tb[n]}"
        for nm, J in (("a", A[k]), ("b", B[k])):
            e = align(J["tokens"], J["top2"]).get(n)
            t2 = J["top2"][e] if e is not None else []
            desc = " ".join(f"id {c[0]} logp {c[1]:.4f}" for c in t2)
            gap = (t2[0][1] - t2[1][1]) if len(t2) == 2 else float('nan')
            out += f" | {nm}'s top-2: {desc} (gap {gap:.4f})"
        print(out)

if __name__ == '__main__':
    if sys.argv[1] == 'diff':
        diff(sys.argv[2], sys.argv[3])
    else:
        run(sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4])
