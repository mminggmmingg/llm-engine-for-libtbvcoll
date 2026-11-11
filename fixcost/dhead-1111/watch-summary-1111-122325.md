# 추론 감시 비교 (2026-11-11 12:23:25, RUNS="mtp:hx mtp:def mtp:hx mtp:def")

기록 링을 켠 회라 tok/s 는 속도 회보다 ≈6% 낮다. 세션 폴더: runs/watch/<세션>/(report.html, receipt.md, stalls.txt).
감시기 판: inferwatch iw-20261110-1 (reads ring format GGRPCTR1 v1..v1) (/data/parksThink/inferwatch-iw-20261110-1)

| 설정 | 감시기 tok/s | ms/단계 | AR 지연 A→B 중앙 / p99 µs | B→A | 1 ms 넘는 기다림 ms/단계 | 그중 링크 / 상대 계산 (번) | 링크 늦음 1–2.5 / 2.5–3.5 / 3.5–7 / 7–12 / >12 ms (번) | 세션 |
|---|---:|---:|---|---|---:|---|---|---|
| mtp:hx | 192.6 | 11.45 | 30.3 / 489.7 | 29.2 / 271.6 | 0.07 | 3 / 101 | 1 / 1 / 0 / 0 / 0 | 20261111-121708 |
| mtp:def | 195.4 | 11.29 | 30.3 / 523.2 | 29.4 / 291.5 | 0.16 | 12 / 220 | 6 / 2 / 0 / 0 / 0 | 20261111-122135 |

## 노드별 DRAM 읽기 (inferwatch dram-bytes, 기록 링 켠 회의 decode 단계, 쉬는 몫 뺌)

| 회 | 노드 | GB/처리 토큰 | decode 중 GB/s | 239.7 대비 | 쉬는 몫 GB/s(중앙값, 3배 넘는 구간 수) | 처리 토큰 |
|---|---|---:|---:|---:|---|---:|
| mtp:hx | A | 0.583 | 112.3 | 0.469 | 0.389 (2) | 5299 |
| mtp:hx | B | 0.493 | 94.9 | 0.396 | 0.165 (8) | 5299 |
| mtp:def | A | 0.586 | 114.6 | 0.478 | 0.345 (0) | 5332 |
| mtp:def | B | 0.493 | 96.4 | 0.402 | 0.205 (4) | 5332 |

처리 토큰 = 감시 세션 decode 단계가 처리한 토큰(MTP 는 검증 묶음의 토큰까지 — 출력 토큰보다 많다). 85% 목표 값(none): 노드마다 GB/토큰 × 같은 구성 속도 회(기록 링 끔) tok/s ÷ 239.7.
MTP 는 decode 중 GB/s(기록 링 켠 회) 를 본다. 자료: /data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll/fixcost/dhead-1111/dram
