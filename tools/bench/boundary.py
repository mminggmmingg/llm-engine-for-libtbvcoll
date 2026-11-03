# step boundary chain (median us) from a saved inferwatch session dir
import struct, statistics as st, bisect, sys
D=sys.argv[1].rstrip('/')+'/'
def load(p):
    b=open(D+p,'rb').read(); frm=struct.unpack_from('<Q',b,4096)[0]; o=4104; recs=[]
    for k in range((len(b)-o)//64):
        idx,typ,a,bb,*t=struct.unpack_from('<IIII6q',b,o+64*k)
        if idx==((frm+k+1)&0xffffffff): recs.append((typ,a,bb,t))
    return recs
C=load('client.ring'); A=load('a.ring')
dec=sorted([(t[0],t[1]) for typ,a,b,t in C if typ==9])
cc=sorted([(t[0],t[1],t[2],a) for typ,a,b,t in C if typ==7])
acmd=sorted([(t[1],t[2],a) for typ,a,b,t in A if typ==1]); cst=[x[0] for x in acmd]
gets=[x for x in acmd if x[2]==8]; gs=[x[0] for x in gets]
r={k:[] for k in ('prev_get_end_to_decode','decode_to_first_set_q','set_q_span','decode_to_first_rc_srv','first_rc_srv_len','decode_call','get_srv')}
for i in range(300,len(dec)-300):
    d0,d1=dec[i]
    if dec[i+1][0]-d0>60000: continue
    j=bisect.bisect_left(gs,d0)-1; r['prev_get_end_to_decode'].append(d0-gets[j][1]); r['get_srv'].append(gets[j][1]-gets[j][0])
    sq=[x[0] for x in cc if d0<=x[0]<=d1 and x[3]==6]
    if sq: r['decode_to_first_set_q'].append(sq[0]-d0); r['set_q_span'].append(sq[-1]-sq[0])
    m=bisect.bisect_left(cst,d0)
    while m<len(acmd) and acmd[m][2]!=16: m+=1
    r['decode_to_first_rc_srv'].append(acmd[m][0]-d0); r['first_rc_srv_len'].append(acmd[m][1]-acmd[m][0])
    r['decode_call'].append(d1-d0)
for k,v in r.items():
    if v: print(f'{k:24s} med {st.median(v):7.0f} p90 {sorted(v)[9*len(v)//10]:7.0f}')
