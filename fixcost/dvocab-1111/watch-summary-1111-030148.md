# 추론 감시 비교 (2026-11-11 03:01:48, RUNS="mtp:dv80 mtp:dv96 mtp:dv80 mtp:dv96 mtp:dv80 mtp:dv96")

기록 링을 켠 회라 tok/s 는 속도 회보다 ≈6% 낮다. 세션 폴더: runs/watch/<세션>/(report.html, receipt.md, stalls.txt).
감시기 판: inferwatch iw-20261110-1 (reads ring format GGRPCTR1 v1..v1) (/data/parksThink/inferwatch-iw-20261110-1)

| 설정 | 감시기 tok/s | ms/단계 | AR 지연 A→B 중앙 / p99 µs | B→A | 1 ms 넘는 기다림 ms/단계 | 그중 링크 / 상대 계산 (번) | 링크 늦음 1–2.5 / 2.5–3.5 / 3.5–7 / 7–12 / >12 ms (번) | 세션 |
|---|---:|---:|---|---|---:|---|---|---|
| mtp:dv80 | 200.1 | 11.02 | 32.9 / 533.9 | 29.5 / 382.3 | 0.19 | 3 / 280 | 2 / 0 / 0 / 0 / 0 | 20261111-025440 |
| mtp:dv96 | 192.3 | 11.46 | 33.2 / 516.4 | 29.4 / 610.8 | 0.25 | 10 / 357 | 0 / 0 / 0 / 0 / 0 | 20261111-025959 |

## 노드별 DRAM 읽기 (inferwatch dram-bytes, 기록 링 켠 회의 decode 단계, 쉬는 몫 뺌)

| 회 | 노드 | GB/처리 토큰 | decode 중 GB/s | 239.7 대비 | 쉬는 몫 GB/s(중앙값, 3배 넘는 구간 수) | 처리 토큰 |
|---|---|---:|---:|---:|---|---:|
| mtp:dv80 | A | 0.592 | 118.4 | 0.494 | 0.366 (3) | 5453 |
| mtp:dv80 | B | 0.487 | 97.4 | 0.406 | 0.201 (4) | 5453 |
| mtp:dv96 | A | 0.599 | 115.3 | 0.481 | 0.383 (0) | 5332 |
| mtp:dv96 | B | 0.487 | 93.8 | 0.391 | 0.206 (4) | 5332 |

처리 토큰 = 감시 세션 decode 단계가 처리한 토큰(MTP 는 검증 묶음의 토큰까지 — 출력 토큰보다 많다). 85% 목표 값(none): 노드마다 GB/토큰 × 같은 구성 속도 회(기록 링 끔) tok/s ÷ 239.7.
MTP 는 decode 중 GB/s(기록 링 켠 회) 를 본다. 자료: /data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll/fixcost/dvocab-1111/dram
