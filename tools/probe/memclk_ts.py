# gpu_metrics v3.0(APU) 메모리 쪽 시계열(읽기만): 100 ms 마다 경과초 gfxclk fclk uclk socclk gfx활동% dram_rd dram_wr 소켓W   (argv[1] = 초)
import struct, sys, time
P = '/sys/class/drm/card1/device/gpu_metrics'
t0 = time.time(); end = t0 + float(sys.argv[1])
while time.time() < end:
    b = open(P, 'rb').read()
    u16 = lambda o: struct.unpack_from('<H', b, o)[0]
    print(f"{time.time()-t0:6.1f} {u16(174)} {u16(182)} {u16(186)} {u16(176)} {u16(42)} {u16(94)} {u16(96)} {struct.unpack_from('<I', b, 112)[0]/1000:.1f}", flush=True)
    time.sleep(0.1)
