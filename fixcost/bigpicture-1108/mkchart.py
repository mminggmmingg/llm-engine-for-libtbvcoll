# docs/inefficiency-1108/token-budget.svg 만들기(값은 budget-A.md 와 감시기 영수증에서): python3 -I mkchart.py <출력 svg>
import sys
out = sys.argv[1]
TOK = 24.04
bars = [
    ("가중치 읽기 최소 시간", "2.81 GB ÷ 239.7 GB/s — 줄일 수 없는 몫", 11.72, True),
    ("커널 사이 빈틈", "1308개/토큰 × 평균 2.8 µs", 3.95, False),
    ("행렬곱 대역폭 손실", "행렬곱 15.43 ms − 최소 11.72 ms", 3.71, False),
    ("행렬곱 밖 커널", "GDN·attention·라우팅·AR 더하기 등", 2.84, False),
    ("AR 기다림", "커널 안에서 상대 부분합을 기다림", 1.15, False),
    ("토큰 경계", "출력 읽기·클라이언트 다음 단계 준비", 0.67, False),
]
W, x0, scale = 800, 300, 32.0   # px per ms
top, bh, gap = 92, 26, 22
H = top + len(bars) * (bh + gap) + 46
def bar(x, y, w, h, r=4):
    r = min(r, w / 2)
    return f'M{x},{y} h{w-r:.1f} a{r},{r} 0 0 1 {r},{r} v{h-2*r} a{r},{r} 0 0 1 -{r},{r} h-{w-r:.1f} z'
s = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" role="img" aria-labelledby="t d">',
     '<title id="t">토큰 하나의 시간 장부 (2노드 TP none, 2026-11-08)</title>',
     '<desc id="d">' + ", ".join(f"{n} {v:.2f} ms" for n, _, v, _ in bars) + f' (합 {TOK} ms)</desc>',
     '<style>.bg{fill:#fcfcfb}.t1{fill:#0b0b0b}.t2{fill:#52514e}.t3{fill:#6f6e69}.need{fill:#b4b2aa}.loss{fill:#2a78d6}.grid{stroke:#e4e3de;stroke-width:1}'
     '@media (prefers-color-scheme: dark){.bg{fill:#1a1a19}.t1{fill:#f0efec}.t2{fill:#c3c2b7}.t3{fill:#a3a29a}.need{fill:#5e5d58}.loss{fill:#3987e5}.grid{stroke:#33332f}}'
     'text{font-family:-apple-system,"Segoe UI","Noto Sans KR","Apple SD Gothic Neo",sans-serif}</style>',
     f'<rect class="bg" x="0" y="0" width="{W}" height="{H}" rx="8"/>',
     f'<text class="t1" x="24" y="36" font-size="19" font-weight="600">토큰 하나 {TOK} ms 는 어디에 쓰이나</text>',
     '<text class="t2" x="24" y="60" font-size="13">2노드 TP, MTP 없음, 41.6 tok/s · A 노드 GPU 시간선(rocprofv3) + 감시기 · 회색 = 줄일 수 없는 몫, 파랑 = 비효율</text>']
for ms in range(0, 13, 2):
    x = x0 + ms * scale
    s.append(f'<line class="grid" x1="{x}" y1="{top-8}" x2="{x}" y2="{H-40}"/>')
    s.append(f'<text class="t3" x="{x}" y="{H-22}" font-size="11" text-anchor="middle">{ms} ms</text>')
for i, (name, sub, ms, need) in enumerate(bars):
    y = top + i * (bh + gap)
    s.append(f'<text class="t1" x="{x0-12}" y="{y+11}" font-size="13.5" font-weight="600" text-anchor="end">{name}</text>')
    s.append(f'<text class="t2" x="{x0-12}" y="{y+27}" font-size="11" text-anchor="end">{sub}</text>')
    s.append(f'<path class="{"need" if need else "loss"}" d="{bar(x0, y, ms*scale, bh)}"><title>{name}: {ms:.2f} ms/토큰 ({100*ms/TOK:.0f}%)</title></path>')
    s.append(f'<text class="t1" x="{x0 + ms*scale + 8:.1f}" y="{y+18}" font-size="13">{ms:.2f} ms · {100*ms/TOK:.0f}%</text>')
s.append('</svg>')
open(out, "w").write("\n".join(s))
