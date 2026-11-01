# 이 프로세스를 같은 사용자의 아무 프로세스나 ptrace 할 수 있게 한 뒤(Yama PR_SET_PTRACER_ANY) 명령을 exec — 진단용 스택 찍기
import ctypes, os, sys
libc = ctypes.CDLL(None, use_errno=True)
if libc.prctl(0x59616d61, ctypes.c_ulong(0xffffffffffffffff), 0, 0, 0) != 0:
    sys.exit('prctl failed %d' % ctypes.get_errno())
os.execvp(sys.argv[1], sys.argv[1:])
