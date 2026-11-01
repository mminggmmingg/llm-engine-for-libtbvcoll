# timeline: tlsum.py tl-a.txt tl-b.txt — per AR on each node (us): gap (end k-1 -> entry k), peer landed after our return,
# pending wait at entry, GPU done after entry, GPU done after peer landed
import sys, statistics as st
def load(p):
    d = {}
    for l in open(p):
        q, *v = l.split(); v = list(map(int, v))
        if all(v): d[int(q)] = dict(zip(['entry','pending','ready','sent','end','land'], v))
    return d
for p in sys.argv[1:]:
    d = load(p); rows = []
    for q in sorted(d):
        if q-1 not in d: continue
        a, b = d[q-1], d[q]
        cyc = b['sent'] - a['sent']
        if cyc > 2000: continue          # between requests / prefill
        rows.append(dict(cyc=cyc, gap=b['entry']-a['end'], land=a['land']-a['end'], pend=b['pending']-b['entry'],
                         after_entry=b['ready']-b['pending'], after_land=b['ready']-a['land'], post=b['sent']-b['ready']))
    print(p, 'n', len(rows))
    for k in ['cyc','gap','land','pend','after_entry','after_land','post']:
        v = sorted(r[k] for r in rows)
        print(f"  {k:12s} p10 {v[len(v)//10]:6d} med {v[len(v)//2]:6d} p90 {v[len(v)*9//10]:6d} mean {st.mean(v):7.1f}")
    # which comes last for the GPU start: host launch done (entry) or the peer data (land)?
    late_data = sum(1 for r in rows if r['land'] > r['gap'])
    print(f"  peer data landed after the host was back for the next AR: {late_data}/{len(rows)}")
