#!/bin/bash
# 컨테이너 안 _hg_flash_serve 자리: flash_serve 를 rocprofv3 커널 기록(GPU 시각) 아래에서 실행. 짧은 조회 호출(--ck 없음)은 그대로.
# 10-28 의 --runtime-trace 조합은 커널 Start=End 였다 → 이번에는 --kernel-trace --memory-copy-trace 만.
case " $* " in *" --ck "*) ;; *) exec /usr/local/bin/flash_serve "$@" ;; esac
exec rocprofv3 --kernel-trace --memory-copy-trace -f csv -d /out/prof -o fs -- /usr/local/bin/flash_serve "$@"
