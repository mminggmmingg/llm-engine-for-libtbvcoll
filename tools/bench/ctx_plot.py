# 컨텍스트 길이 벤치(ctx_bench.py) 결과 → README 용 표(markdown)와 SVG 그림(밝은·어두운 테마). 표준 라이브러리만.
#   ctx_plot.py <출력 폴더> none=<ctx.jsonl>[,<ctx.jsonl>...] mtp=<ctx.jsonl>[,...]
# 같은 깊이가 여러 파일에 있으면 모두 모은다(평균 ± 표준편차). 그림: 깊이별 decode(tg) tok/s, 문맥 채우기(ctx_pp) tok/s.
import json, os, statistics, sys

outdir = sys.argv[1]
modes = {}
for a in sys.argv[2:]:
    k, v = a.split('=', 1)
    rows = []
    for f in v.split(','):
        rows += [json.loads(l) for l in open(f) if l.startswith('{"depth"')]
    modes[k] = rows
os.makedirs(outdir, exist_ok=True)

def agg(rows, d, fn):
    v = [fn(r) for r in rows if r["depth"] == d]
    v = [x for x in v if x is not None]
    if not v:
        return None, None, 0
    return statistics.mean(v), (statistics.stdev(v) if len(v) > 1 else None), len(v)

M = {
    "ctx": lambda r: r["ctx_n"] / r["ctx_ms"] * 1e3 if r.get("ctx_ms") else None,
    "ctx_s": lambda r: r["ctx_ms"] / 1e3 if r.get("ctx_ms") else None,
    "pp": lambda r: r["pp_n"] / r["pp_ms"] * 1e3 if r.get("pp_ms") else None,
    "tg": lambda r: r["tg_n"] / r["tg_ms"] * 1e3 if r.get("tg_ms") else None,
    "acc": lambda r: r["draft_acc"] / r["draft_n"] * 100 if r.get("draft_n") else None,
}
depths = sorted({r["depth"] for rows in modes.values() for r in rows})

def lab(d):
    return "0" if d == 0 else (f"{d // 1024}k" if d % 1024 == 0 else str(d))

def fmt(m, s, n, nd=1, unit=""):
    if m is None:
        return "—"
    return f"{m:.{nd}f}{unit}" + (f" ± {s:.{nd}f}" if s is not None else "") + ("" if n > 1 else " (1회)")

# 표: 깊이마다 한 줄, none·MTP 나란히
hdr = ("| 문맥 깊이 d (토큰) | 문맥 채우기 tok/s | 채우는 시간 s | pp512 @ d tok/s | tg128 @ d tok/s (none) | tg128 @ d tok/s (MTP) | MTP 채택률 |\n"
       "|---:|---:|---:|---:|---:|---:|---:|")
lines = [hdr]
for d in depths:
    base = modes.get("none", [])
    c = agg(base, d, M["ctx"]); cs = agg(base, d, M["ctx_s"]); p = agg(base, d, M["pp"]); t = agg(base, d, M["tg"])
    tm = agg(modes.get("mtp", []), d, M["tg"]); ac = agg(modes.get("mtp", []), d, M["acc"])
    lines.append(f"| {d:,}" + (f" ({lab(d)})" if d else "") + f" | {fmt(*c) if d else '—'} | {fmt(*cs) if d else '—'} | {fmt(*p)} | "
                 f"**{fmt(*t)}** | **{fmt(*tm)}** | {fmt(*ac, nd=0, unit='%')} |")
open(os.path.join(outdir, "ctx-table.md"), "w").write("\n".join(lines) + "\n")
print("\n".join(lines))

THEMES = {
    "light": dict(bg="#ffffff", ink="#1f2328", muted="#59636e", grid="#d1d9e0", c={"blue": "#1f6feb", "orange": "#bc4c00", "green": "#1a7f37"}),
    "dark": dict(bg="#0d1117", ink="#e6edf3", muted="#9198a1", grid="#3d444d", c={"blue": "#4493f8", "orange": "#f0883e", "green": "#3fb950"}),
}

def chart(name, title, ylab, series, theme):
    # series: (모드, 지표 키, 이름, 색 이름) — 색은 대상(none = 파랑, MTP = 주황)을 따라가고 순위를 따라가지 않는다
    T = THEMES[theme]
    W, H, L, R, TOP, B = 680, 380, 64, 72, 64, 52
    xs = [d for d in depths if any(agg(modes.get(m, []), d, M[k])[0] is not None for m, k, *_ in series)]
    vals = []
    for m, k, *_ in series:
        for d in xs:
            a = agg(modes.get(m, []), d, M[k])
            if a[0] is not None:
                vals.append(a[0] + (a[1] or 0))
    ymax = max(vals) * 1.12
    step = [1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500][0]
    for s in [1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000]:
        if ymax / s <= 6:
            step = s; break
    ymax = step * (int(ymax / step) + 1)
    px = lambda i: L + (W - L - R) * (i / max(1, len(xs) - 1))
    py = lambda v: TOP + (H - TOP - B) * (1 - v / ymax)
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" font-family="-apple-system,Segoe UI,Helvetica,Arial,sans-serif">',
         f'<rect width="{W}" height="{H}" fill="{T["bg"]}"/>',
         f'<text x="{L}" y="24" font-size="15" font-weight="600" fill="{T["ink"]}">{title}</text>']
    y = 0
    while y <= ymax + 1e-9:
        o.append(f'<line x1="{L}" x2="{W - R}" y1="{py(y):.1f}" y2="{py(y):.1f}" stroke="{T["grid"]}" stroke-width="1"/>')
        o.append(f'<text x="{L - 8}" y="{py(y) + 4:.1f}" font-size="12" text-anchor="end" fill="{T["muted"]}">{y:g}</text>')
        y += step
    for i, d in enumerate(xs):
        o.append(f'<text x="{px(i):.1f}" y="{H - B + 20}" font-size="12" text-anchor="middle" fill="{T["muted"]}">{lab(d)}</text>')
    o.append(f'<text x="{(L + W - R) / 2:.0f}" y="{H - 10}" font-size="12" text-anchor="middle" fill="{T["muted"]}">문맥 깊이 d (토큰)</text>')
    o.append(f'<text x="14" y="{(TOP + H - B) / 2:.0f}" font-size="12" text-anchor="middle" fill="{T["muted"]}" transform="rotate(-90 14 {(TOP + H - B) / 2:.0f})">{ylab}</text>')
    lx = L
    for m, k, name_, cn, _ in series:   # 범례(위), 끝 점에는 이름을 직접 붙임
        col = T["c"][cn]
        o.append(f'<line x1="{lx}" x2="{lx + 18}" y1="44" y2="44" stroke="{col}" stroke-width="2"/><circle cx="{lx + 9}" cy="44" r="4" fill="{col}"/>')
        o.append(f'<text x="{lx + 24}" y="48" font-size="12" fill="{T["ink"]}">{name_}</text>')
        lx += 24 + 8 * len(name_) + 28
    if any(agg(modes.get(m, []), d, M[k])[1] is not None for m, k, *_ in series for d in xs):
        o.append(f'<text x="{W - R}" y="48" font-size="11" text-anchor="end" fill="{T["muted"]}">세로 막대 = ±1 표준편차</text>')
    ends = []
    for m, k, name_, cn, short in series:
        col = T["c"][cn]
        pts = []
        for i, d in enumerate(xs):
            mu, sd, n = agg(modes.get(m, []), d, M[k])
            if mu is None:
                continue
            pts.append((px(i), py(mu), sd))
        if not pts:
            continue
        o.append(f'<polyline fill="none" stroke="{col}" stroke-width="2" points="' + " ".join(f"{a:.1f},{b:.1f}" for a, b, _ in pts) + '"/>')
        for i, (a, b, sd) in enumerate(pts):
            if sd:
                mu = ymax * (1 - (b - TOP) / (H - TOP - B))
                y1, y2 = py(max(0, mu - sd)), py(mu + sd)
                o.append(f'<line x1="{a:.1f}" x2="{a:.1f}" y1="{y1:.1f}" y2="{y2:.1f}" stroke="{col}" stroke-width="1.5" opacity="0.7"/>')
                o.append(f'<line x1="{a - 4:.1f}" x2="{a + 4:.1f}" y1="{y1:.1f}" y2="{y1:.1f}" stroke="{col}" stroke-width="1.5" opacity="0.7"/>')
                o.append(f'<line x1="{a - 4:.1f}" x2="{a + 4:.1f}" y1="{y2:.1f}" y2="{y2:.1f}" stroke="{col}" stroke-width="1.5" opacity="0.7"/>')
            o.append(f'<circle cx="{a:.1f}" cy="{b:.1f}" r="4" fill="{col}" stroke="{T["bg"]}" stroke-width="2"/>')
        ends.append([pts[-1][1], pts[-1][0], short])
    ends.sort()   # 끝 이름표가 겹치지 않게 14px 이상 벌림
    for i in range(1, len(ends)):
        ends[i][0] = max(ends[i][0], ends[i - 1][0] + 14)
    for b, a, short in ends:
        o.append(f'<text x="{a + 10:.1f}" y="{b + 4:.1f}" font-size="12" fill="{T["ink"]}">{short}</text>')
    o.append('</svg>')
    open(os.path.join(outdir, f"{name}-{theme}.svg"), "w").write("\n".join(o) + "\n")

for th in THEMES:
    chart("ctx-decode", "디코드 속도 — 문맥 깊이 d 에서 128토큰 생성 (tg128 @ d)", "tok/s",
          [("none", "tg", "none (추측 없음)", "blue", "none"), ("mtp", "tg", "MTP (초안 3토큰)", "orange", "MTP")], th)
    chart("ctx-prefill", "프롬프트 처리 속도 — 2노드 none", "tok/s",
          [("none", "ctx", "0 → d 채우기 평균", "blue", "채우기"), ("none", "pp", "d 뒤 512토큰 (pp512 @ d)", "green", "pp512")], th)
print("written", outdir)
