import sys, collections
rows=[]
for line in open(sys.argv[1]):
    p=line.split()
    if not p or p[0]!='stall': continue
    d={'w':p[1]}
    d.update({p[i]:float(p[i+1]) for i in range(2,len(p)-1,2)})
    rows.append(d)
L=[r for r in rows if r['link']>=1000]
print('stalls',len(rows),'link>=1ms',len(L))
c=collections.Counter((r['w'], '1-2.5' if r['link']<2500 else '2.5-3.5' if r['link']<3500 else '3.5-7' if r['link']<7000 else '>7') for r in L)
for k in sorted(c): print(k,c[k])
# fine histogram of link (100us bins) for link >= 1ms
h=collections.Counter(int(r['link']//250)*250 for r in L)
print('hist(250us):',' '.join(f'{k}:{h[k]}' for k in sorted(h)))
# post values for those
print('post>=500 among link stalls',sum(r['post']>=500 for r in L))
# inter-arrival of link stalls per waiter
for w in ('w0','w1'):
    t=sorted(r['t'] for r in L if r['w']==w)
    dt=[b-a for a,b in zip(t,t[1:])]
    dh=collections.Counter(min(int(x//5000)*5,200) for x in dt)
    print(w,'gap ms hist(5ms):',' '.join(f'{k}:{dh[k]}' for k in sorted(dh)))
