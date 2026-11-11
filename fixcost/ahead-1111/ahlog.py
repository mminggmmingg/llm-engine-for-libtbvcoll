# draft-ahead 라운드 로그(LLAMA_SPEC_AHEAD_LOG) 요약: R <n_draft> <n_acc> <from_ahead> <pre> <conf> / H <pos0> <allacc> <hit>
# H 줄은 그 앞 R 라운드(미리 만들기가 돈 라운드)의 결과: allacc = 그 라운드 초안이 모두 채택, hit = 다음 토큰까지 맞음
import sys
for fn in sys.argv[1:]:
    rows = []; last = None
    for ln in open(fn):
        p = ln.split()
        if p[0] == 'R':
            last = dict(nd=int(p[1]), na=int(p[2]), fa=int(p[3]), pre=int(p[4]), conf=float(p[5]), allacc=None, hit=None); rows.append(last)
        elif p[0] == 'H' and rows:
            # H 는 다음 draft() 에서 나오므로 가장 최근 pre=1 인 R 에 붙인다
            for r in reversed(rows):
                if r['pre'] and r['allacc'] is None:
                    r['allacc'] = int(p[2]); r['hit'] = int(p[3]); break
    n = len(rows); pre = [r for r in rows if r['pre']]; fa = [r for r in rows if r['fa']]; nfa = [r for r in rows if not r['fa']]
    tok = lambda rs: sum(1 + r['na'] for r in rs) / max(1, len(rs))
    print(f"== {fn}\n라운드 {n}, 미리 만들기 {len(pre)}, 그 뒤 모두 채택 {sum(r['allacc'] or 0 for r in pre)}, 적중 {sum(r['hit'] or 0 for r in pre)}, 적중을 쓴 라운드 {len(fa)}")
    print(f"라운드당 토큰: 전체 {tok(rows):.3f} · 미리 만든 초안을 쓴 라운드 {tok(fa):.3f} · 보통 라운드 {tok(nfa):.3f}")
    print("확신도(초안 top-1 p 곱) 칸별: 라운드 수, 모두 채택 비율, 적중 비율(미리 만들기 돈 것만)")
    for lo, hi in ((0, .1), (.1, .3), (.3, .5), (.5, .7), (.7, .9), (.9, 1.01)):
        rs = [r for r in nfa if lo <= r['conf'] < hi]
        pr = [r for r in rs if r['pre'] and r['allacc'] is not None]
        aa = sum(r['na'] == r['nd'] for r in rs) / max(1, len(rs)); ht = sum(r['hit'] for r in pr) / max(1, len(pr))
        print(f"  {lo:.1f}–{hi:.1f}: {len(rs):5d}  모두 채택 {aa:.3f}  적중 {ht:.3f} ({len(pr)})")
