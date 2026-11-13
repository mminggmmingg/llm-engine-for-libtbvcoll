# 추론 감시 비교 (2026-11-14 07:07:03, RUNS="mtp:g mtp:b mtp:g mtp:b")

기록 링을 켠 회라 tok/s 는 속도 회보다 ≈6% 낮다. 세션 폴더: runs/watch/<세션>/(report.html, receipt.md, stalls.txt).
감시기 판: inferwatch iw-20261110-1 (reads ring format GGRPCTR1 v1..v1) (/data/parksThink/inferwatch-iw-20261110-1)

| 설정 | 감시기 tok/s | ms/단계 | AR 지연 A→B 중앙 / p99 µs | B→A | 1 ms 넘는 기다림 ms/단계 | 그중 링크 / 상대 계산 (번) | 링크 늦음 1–2.5 / 2.5–3.5 / 3.5–7 / 7–12 / >12 ms (번) | 세션 |
|---|---:|---:|---|---|---:|---|---|---|
| mtp:g | 213.0 | 10.37 | 30.6 / 444.2 | 29.6 / 45.3 | 0.02 | 13 / 9 | 10 / 2 / 0 / 0 / 0 | 20261114-070123 |
| mtp:b | 216.2 | 10.22 | 30.7 / 470.4 | 29.6 / 44.5 | 0.02 | 9 / 7 | 6 / 2 / 2 / 0 / 0 | 20261114-070520 |

## 출력 토큰 기준 (tools/bench/outsum.py — MTP 는 출력 토큰으로 센 t/s, 가중치 기준 GB/s = t/s × 노드당 2.83 GB, DRAM 은 잰 노드만)

| run | output t/s | weight-based GB/s per node (x 2.83 GB) | DRAM GB/s A / B | DRAM GB per output token A / B |
|---|---:|---:|---|---|
| mtp:g | 62.05 | 175.6 |  |  |
| mtp:b | 62.83 | 177.8 |  |  |
