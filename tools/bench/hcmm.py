# rocprofv3 커널 기록에서 hc 경계 행렬곱 시간: hcmm.py <run_dir> [접두사=a] [토큰=32]
#   hc_post 뒤 hc_pre 앞의 mmvq 두 개 = hc down(10240→324, Q6_K), hc up(320→10240, Q8_0). 각각 중앙값·평균과 토큰당 합.
import csv, sys, statistics as st
d = sys.argv[1]; p = sys.argv[2] if len(sys.argv) > 2 else 'a'; N = int(sys.argv[3]) if len(sys.argv) > 3 else 32
K = sorted((int(r['Start_Timestamp']), int(r['End_Timestamp']), r['Kernel_Name']) for r in csv.DictReader(open(f'{d}/{p}_kernel_trace.csv')))
D = sorted(int(r['End_Timestamp']) for r in csv.DictReader(open(f'{d}/{p}_memory_copy_trace.csv')) if 'DEVICE_TO_HOST' in r['Direction'])
t0, t1 = D[-(N + 1)], D[-1]
down, up, quant = [], [], []
state = 0   # 1: hc_post 를 지남, 2: down 지남
for s, e, n in K:
    if not (t0 <= s < t1):
        continue
    if 'dsv4_hc_post' in n:
        state = 1
    elif 'dsv4_hc_pre' in n:
        state = 0
    elif state and 'mul_mat_vec_q' in n:
        (down if state == 1 else up).append((e - s) / 1e3); state = 2
    elif state and 'quantize_q8_1' in n:
        quant.append((e - s) / 1e3)
f = lambda v: f"n/tok {len(v)/N:5.1f} med {st.median(v):6.2f} mean {st.mean(v):6.2f} us  sum/tok {sum(v)/N/1e3:5.2f} ms" if v else "-"
print(f"hc down  {f(down)}  ({2.72e6 / (st.median(down) * 1e3):.0f} GB/s at med)" if down else "hc down -")
print(f"hc up    {f(up)}  ({3.48e6 / (st.median(up) * 1e3):.0f} GB/s at med)" if up else "hc up -")
print(f"quant    {f(quant)}")
