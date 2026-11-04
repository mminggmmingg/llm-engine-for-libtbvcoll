"""halogen 에 우리 엔진과 같은 6 프롬프트(eval/spec_prompts.json, chat, temperature 0)를 보낸다: hg_bench.py <URL> <prompts.json> <max_tokens> <drafter serial|mtp>
디코드 속도는 서버 ledger(serve_api: ... t/s, prefill 따로)에서 읽고, 여기서는 요청마다 시작·끝 CLOCK_MONOTONIC 과 출력 해시를 남긴다."""
import hashlib, json, sys, time, urllib.request
U, pfile, nmax, drafter = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
M = json.load(urllib.request.urlopen(U + "/v1/models", timeout=60))["data"][0]["id"]
for p in json.load(open(pfile, encoding="utf-8")):
    body = {"model": M, "messages": [{"role": "user", "content": p["text"]}], "max_tokens": nmax, "temperature": 0, "drafter": drafter}
    r = urllib.request.Request(U + "/v1/chat/completions", json.dumps(body).encode(), {"Content-Type": "application/json"})
    t0 = time.monotonic_ns(); w0 = time.time()
    o = json.load(urllib.request.urlopen(r, timeout=1800))
    t1 = time.monotonic_ns()
    m = o["choices"][0]["message"]
    text = (m.get("reasoning_content") or m.get("reasoning") or "") + "\n" + (m.get("content") or "")
    print(json.dumps({"id": p["id"], "drafter": drafter, "n": o["usage"]["completion_tokens"], "wall_s": round(time.time() - w0, 3),
                      "mono_start_ns": t0, "mono_end_ns": t1, "sha": hashlib.sha256(text.encode()).hexdigest()[:16]}), flush=True)
    time.sleep(1)
