"""GPU 사용률 빠른 표본(읽기만): gpu_fast.py <초> [간격 ms=20]
   열: CLOCK_MONOTONIC(ns) gpu_busy_percent(작업 표시줄 그래프와 같은 값) gfx_activity(gpu_metrics, 펌웨어 평균) gfxclk(MHz) 소켓W"""
import struct, sys, time
D = '/sys/class/drm/card1/device/'
end = time.monotonic() + float(sys.argv[1]); dt = (float(sys.argv[2]) if len(sys.argv) > 2 else 20) / 1000
fb = open(D + 'gpu_busy_percent'); fm = open(D + 'gpu_metrics', 'rb')
while time.monotonic() < end:
    fb.seek(0); busy = fb.read().strip(); fm.seek(0); b = fm.read()
    u16 = lambda o: struct.unpack_from('<H', b, o)[0]
    print(f"{time.monotonic_ns()} {busy} {u16(42)} {u16(174)} {struct.unpack_from('<I', b, 112)[0]/1000:.1f}", flush=True)
    time.sleep(dt)
