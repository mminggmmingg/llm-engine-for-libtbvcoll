# 초안 어휘 고르기용 말뭉치: 본 모델이 프롬프트마다 greedy 로 낸 토큰 번호를 모은다(표준 라이브러리).
#   draft_vocab_corpus.py <server URL> <prompts.json> <max_tokens> <결과 jsonl>
# 채팅 틀은 서버(/apply-template)가 입히고, /completion 의 return_tokens 로 생성된 토큰 번호를 그대로 받는다.
import json, sys, urllib.request
url, pfile, nmax, out = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]

def post(path, body):
    req = urllib.request.Request(url + path, data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(req, timeout=1800))

with open(out, "w") as f:
    for p in json.load(open(pfile, encoding='utf-8')):
        prompt = post("/apply-template", {"messages": [{"role": "user", "content": p["text"]}]})["prompt"]
        r = post("/completion", {"prompt": prompt, "n_predict": nmax, "temperature": 0, "cache_prompt": False,
                                 "return_tokens": True})
        f.write(json.dumps({"id": p["id"], "tokens": r["tokens"]}) + "\n"); f.flush()
        print(p["id"], len(r["tokens"]), flush=True)
