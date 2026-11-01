#!/usr/bin/env python3
# amd_pmf 동적 디버그 로그(journalctl -k -o short-precise)를 정책 호출 1회당 한 줄로 정리한다.
#   pmfdbg_parse.py <journal.txt>   → 시각, 입력값(TA inputs), 그 호출에서 바뀐 출력(update ...)
import re, sys
KEYS = [('Slider State', 'slider'), ('Power Source', 'src'), ('Socket Power', 'sockW'), ('Skin Temperature', 'skin'),
        ('Avg C0 Residency', 'avgC0'), ('Max C0 Residency', 'maxC0'), ('GFX Busy', 'gfx'), ('LID State', 'lid'),
        ('User Presence', 'pres'), ('Ambient Light', 'als'), ('Platform type', 'plat'), ('Laptop placement', 'place'),
        ('Battery Percentage', 'bat')]
line_re = re.compile(r'^\S+ \S+ (\d\d:\d\d:\d\d\.\d+) \S+ kernel: amd-pmf \S+ (.*)$')
rows, cur, upd, custom = [], None, [], {}
for l in open(sys.argv[1], errors='replace'):
    m = line_re.match(l.rstrip())
    if not m:
        continue
    t, msg = m.groups()
    if msg.startswith('==== TA inputs START'):
        cur = {'t': t}; custom = {}
    elif msg.startswith('==== TA inputs END') and cur is not None:
        cur['custom'] = ','.join(f'{k}={v}' for k, v in sorted(custom.items())); cur['upd'] = []; rows.append(cur); cur = None
    elif cur is not None:
        cm = re.match(r'Custom BIOS input(\d+): (\d+)', msg)
        if cm:
            custom[cm.group(1)] = cm.group(2); continue
        for k, s in KEYS:
            if msg.startswith(k + ':'):
                cur[s] = msg.split(':', 1)[1].strip()
    elif msg.startswith('update ') or msg.startswith('action count'):
        (rows[-1]['upd'] if rows else upd).append(msg)
hdr = ['t'] + [s for _, s in KEYS] + ['custom', 'upd']
print('\t'.join(hdr))
for r in rows:
    print('\t'.join(str(r.get(h, '')) if h != 'upd' else ' | '.join(x for x in r['upd'] if not x.startswith('action count')) for h in hdr))
