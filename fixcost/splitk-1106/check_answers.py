# split-K 끔/켬 답변을 정답이 정해진 것만 기계적으로 채점한다(표준 라이브러리 + gcc -fsyntax-only, 생성 코드는 실행하지 않음).
#   check_answers.py <off.jsonl> <on.jsonl>     (tools/divergence.py 의 출력, content 포함)
import ast, json, re, subprocess, sys

def final(t):  # 추론 글(</think> 앞) 뒤의 답 부분, </think> 가 없으면(2048 토큰에서 잘림) 빈 글
    return t.split("</think>", 1)[1] if "</think>" in t else ""

def blocks(t, langs):
    return [b for l, b in re.findall(r"```(\w*)\n(.*?)```", t, re.S) if l.lower() in langs]

def chk_json(t):
    t = final(t)
    for b in list(reversed(blocks(t, ("json", "")))) + [t.strip()]:
        try:
            return "valid JSON", json.loads(b)
        except Exception:
            pass
    return "invalid JSON", None

def chk(pid, t):
    if "</think>" not in t:
        return "unfinished (2048 cap)"
    if pid == "math":      # 156/72 h = 2h10m → 11:50, +18m → 12:08, 90/60 h = 1h30m → 13:38
        return "13:38" if re.search(r"13:38|1:38\s*(PM|p\.m\.)", final(t), re.I) else "no 13:38"
    if pid == "h-math1":   # 48 km / (2 h + 2/3 h) = 18 km/h
        return "18 km/h" if re.search(r"\b18\s*km/h", final(t)) else "no 18 km/h"
    if pid == "h-math2":   # 5! - 2·4! = 72
        return "72" if re.search(r"\b72\b", final(t)) else "no 72"
    if pid == "json":
        s, v = chk_json(t)
        want = {("Alice", 7), ("Bob", 3), ("Carol", 5), ("Dan", 9)}
        rows = v if isinstance(v, list) else (next(iter(v.values()), None) if isinstance(v, dict) else None)
        got = {(r.get("name"), r.get("years")) for r in rows if isinstance(r, dict)} if isinstance(rows, list) else set()
        return s + (", 4 people right" if got == want else f", people {sorted(got, key=str)}")
    if pid in ("h-json1", "h-json2"):
        return chk_json(t)[0]
    if pid in ("code", "h-code1"):
        bs = blocks(final(t), ("python", "py"))
        if not bs:
            return "no python block"
        try:
            ast.parse(bs[-1]); return "python parses"
        except SyntaxError as e:
            return f"python SyntaxError line {e.lineno}"
    if pid == "h-code2":
        bs = blocks(final(t), ("c",))
        if not bs:
            return "no C block"
        r = subprocess.run(["gcc", "-fsyntax-only", "-x", "c", "-"], input=bs[-1], text=True, capture_output=True)
        return "C compiles" if r.returncode == 0 else "C error: " + r.stderr.strip().splitlines()[0][:80]
    return "-"

if __name__ == "__main__":
    A = {j["id"]: j for j in map(json.loads, open(sys.argv[1]))}
    B = {j["id"]: j for j in map(json.loads, open(sys.argv[2]))}
    print(f"{'prompt':10s} {'same':>5s} {'off tokens':>10s} {'on tokens':>10s} | off | on")
    for k in A:
        a, b = A[k], B[k]
        n = next((i for i in range(min(len(a["tokens"]), len(b["tokens"]))) if a["tokens"][i] != b["tokens"][i]), None)
        same = "yes" if n is None and len(a["tokens"]) == len(b["tokens"]) else f"@{n}"
        cap = lambda j: " (cut at 2048)" if len(j["tokens"]) >= 2048 and "</think>" in j["content"] else ""
        print(f"{k:10s} {same:>5s} {len(a['tokens']):10d} {len(b['tokens']):10d} | {chk(k, a['content'])}{cap(a)} | {chk(k, b['content'])}{cap(b)}")
