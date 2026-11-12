# 컨텍스트 길이별 속도(llama-bench -d / llama-benchy 방식, 표준 라이브러리만): 깊이 d 마다
#   (1) 문맥 채우기: 글의 토큰 d 개를 처음부터 처리 → ctx_pp(t/s), 걸린 시간(= 그 길이 문서의 첫 토큰까지 시간에 가까움)
#   (2) 그 문맥 뒤에 다음 글 PP 토큰을 더 넣고(앞 d 는 서버 캐시) TG 토큰을 greedy 로 생성 → pp<PP> @ d, tg<TG> @ d
# 값은 서버가 잰 timings(prompt_n·prompt_ms·predicted_n·predicted_ms, MTP 면 draft_n·draft_n_accepted). 측정마다 글의 다른 자리
# (측정 번호 × STRIDE 토큰)에서 시작해서 앞 측정의 캐시를 쓰지 않는다(첫 토큰부터 달라 공통 앞부분이 없음 — (1)의 prompt_n = d 로 확인).
# (2)의 prompt_n 이 PP 보다 크면 캐시를 다 못 쓴 것 — 그대로 기록. 맨 앞에 기록하지 않는 데우기 요청 하나(llama-bench 처럼).
#   ctx_bench.py <서버 URL> <글 .txt> <깊이,...> <회 수> <결과 jsonl> [PP=512] [TG=128]
#   환경: CTX_STRIDE(기본 1024). 기록 링 켠 회(TRACE=1, node-ab 감시기 회)는 CTX_WATCH_DEPTHS(기본 0,32768,131072)·1회만.
import json, os, sys, time, hashlib, statistics, urllib.request
url, cfile, depths, reps, out = sys.argv[1], sys.argv[2], [int(x) for x in sys.argv[3].split(',')], int(sys.argv[4]), sys.argv[5]
PP = int(sys.argv[6]) if len(sys.argv) > 6 else 512
TG = int(sys.argv[7]) if len(sys.argv) > 7 else 128
STRIDE = int(os.environ.get("CTX_STRIDE", "1024"))
if os.environ.get("TRACE") == "1":
    depths = [int(x) for x in os.environ.get("CTX_WATCH_DEPTHS", "0,32768,131072").split(',')]; reps = 1

def post(path, body, timeout=7200):
    req = urllib.request.Request(url + path, data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(req, timeout=timeout))

text = open(cfile, encoding='utf-8').read()
n_meas = len(depths) * reps + 1                       # + 데우기
need = max(depths) + PP + TG + n_meas * STRIDE + 16
# 필요한 만큼만 토큰화(글자 ≈ 토큰 × 2.5 보다 넉넉히 잘라 보고 모자라면 늘림)
nch = need * 5
while True:
    toks = post("/tokenize", {"content": text[:nch], "add_special": False})["tokens"]
    if len(toks) >= need or nch >= len(text):
        break
    nch *= 2
assert len(toks) >= need, f"corpus too short: {len(toks)} < {need} tokens"
print(json.dumps({"corpus": os.path.basename(cfile), "corpus_sha256": hashlib.sha256(text.encode()).hexdigest()[:16],
                  "tokens_used": need, "depths": depths, "reps": reps, "pp": PP, "tg": TG, "stride": STRIDE}), flush=True)

def comp(prompt, n_predict):
    body = {"prompt": prompt, "n_predict": n_predict, "temperature": 0, "cache_prompt": True, "ignore_eos": True, "stream": False}
    t0 = time.time(); r = post("/completion", body); wall = time.time() - t0
    return r, r.get("timings", {}), wall

rows = []
_, tw, _ = comp(toks[n_meas * STRIDE - 64:n_meas * STRIDE + 64], 16)   # 데우기(기록 안 함), 측정들과 겹치지 않는 자리
print(json.dumps({"warmup_pp_n": tw.get("prompt_n"), "warmup_tg_n": tw.get("predicted_n")}), flush=True)
idx = 0
with open(out, "w") as f:
    for d in depths:
        for rep in range(reps):
            off = idx * STRIDE; idx += 1
            row = {"depth": d, "rep": rep, "off": off}
            if d > 0:
                _, ta, wa = comp(toks[off:off + d], 0)
                row.update(ctx_n=ta.get("prompt_n"), ctx_ms=ta.get("prompt_ms"), ctx_wall_s=round(wa, 2))
            rb, tb, wb = comp(toks[off:off + d + PP], TG)
            row.update(pp_n=tb.get("prompt_n"), pp_ms=tb.get("prompt_ms"), tg_n=tb.get("predicted_n"), tg_ms=tb.get("predicted_ms"),
                       draft_n=tb.get("draft_n"), draft_acc=tb.get("draft_n_accepted"), wall_s=round(wb, 2),
                       sha=hashlib.sha256((rb.get("content") or "").encode()).hexdigest()[:16])
            rows.append(row); f.write(json.dumps(row) + "\n"); f.flush()
            print(json.dumps(row), flush=True)

def ms(v):
    v = [x for x in v if x is not None]
    if not v: return "-"
    return f"{statistics.mean(v):.1f}" + (f" ± {statistics.stdev(v):.1f}" if len(v) > 1 else "")
print(f"| depth | ctx_pp t/s | ctx 처리 s | pp{PP} @ d t/s | tg{TG} @ d t/s | 채택률 | (2) prompt_n |")
print("|---:|---:|---:|---:|---:|---:|---|")
for d in depths:
    rr = [r for r in rows if r["depth"] == d]
    ctx = [r["ctx_n"] / r["ctx_ms"] * 1e3 for r in rr if r.get("ctx_ms")]
    cs = [r["ctx_ms"] / 1e3 for r in rr if r.get("ctx_ms")]
    pp = [r["pp_n"] / r["pp_ms"] * 1e3 for r in rr if r.get("pp_ms")]
    tg = [r["tg_n"] / r["tg_ms"] * 1e3 for r in rr if r.get("tg_ms")]
    acc = [r["draft_acc"] / r["draft_n"] for r in rr if r.get("draft_n")]
    pn = sorted(set(r["pp_n"] for r in rr))
    print(f"| {d} | {ms(ctx)} | {ms(cs)} | {ms(pp)} | {ms(tg)} | {ms([a * 100 for a in acc]) + '%' if acc else '-'} | {pn} |")
print("CTXDONE")
