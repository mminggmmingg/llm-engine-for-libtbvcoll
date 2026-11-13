# Does skipping the draft head past LLAMA_SPEC_MAX_CTX leave a hole that a later, shorter request drafts from? (2026-11-14)
#   spec_hole.py <server URL> <text .txt> <out jsonl> [SHORT=49152] [LONG=131072] [TG=128]
# Same text from token 0 each time, greedy:
#   A  first SHORT+512 tokens, cache_prompt false (fresh)                    -> reference output and draft acceptance
#   B  first LONG tokens, cache_prompt false (fresh; past the threshold the draft head skips the batches), 16 tokens
#   C  first SHORT+512 tokens again, cache_prompt true: the server keeps B's prefix, so the draft head's cache below the
#      threshold comes from B's prompt processing
# C must give A's output (the target decides it either way) and, if B left no hole below the threshold, A's draft numbers.
import json, sys, time, hashlib, urllib.request
url, cfile, out = sys.argv[1], sys.argv[2], sys.argv[3]
SHORT = int(sys.argv[4]) if len(sys.argv) > 4 else 49152
LONG = int(sys.argv[5]) if len(sys.argv) > 5 else 131072
TG = int(sys.argv[6]) if len(sys.argv) > 6 else 128

def post(path, body, timeout=7200):
    req = urllib.request.Request(url + path, data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(req, timeout=timeout))

text = open(cfile, encoding='utf-8').read()
nch = LONG * 5
while True:
    toks = post("/tokenize", {"content": text[:nch], "add_special": False})["tokens"]
    if len(toks) >= LONG + 16 or nch >= len(text):
        break
    nch *= 2
assert len(toks) >= LONG, f"corpus too short: {len(toks)}"

def comp(tag, prompt, n_predict, cache):
    body = {"prompt": prompt, "n_predict": n_predict, "temperature": 0, "cache_prompt": cache, "ignore_eos": True, "stream": False}
    t0 = time.time(); r = post("/completion", body); wall = time.time() - t0
    t = r.get("timings", {})
    row = {"req": tag, "prompt": len(prompt), "cache_prompt": cache, "prompt_n": t.get("prompt_n"), "prompt_ms": t.get("prompt_ms"),
           "tg_n": t.get("predicted_n"), "tg_ms": t.get("predicted_ms"), "draft_n": t.get("draft_n"), "draft_acc": t.get("draft_n_accepted"),
           "wall_s": round(wall, 2), "sha": hashlib.sha256((r.get("content") or "").encode()).hexdigest()[:16]}
    print(json.dumps(row), flush=True)
    return row

rows = [comp("A", toks[:SHORT + 512], TG, False), comp("B", toks[:LONG], 16, False), comp("C", toks[:SHORT + 512], TG, True)]
with open(out, "w") as f:
    for r in rows:
        f.write(json.dumps(r) + "\n")
a, c = rows[0], rows[2]
print(f"C vs A: output {'same' if a['sha'] == c['sha'] else 'DIFFERENT'}, drafts {a['draft_n']}/{a['draft_acc']} -> {c['draft_n']}/{c['draft_acc']}"
      f" ({'same' if (a['draft_n'], a['draft_acc']) == (c['draft_n'], c['draft_acc']) else 'different'}), C prompt_n {c['prompt_n']}")
print("HOLEDONE")
