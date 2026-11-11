# 추론 감시 비교 (2026-11-11 15:18:57, RUNS="mtp:sd mtp:def mtp:sd mtp:def mtp:sd mtp:def")

기록 링을 켠 회라 tok/s 는 속도 회보다 ≈6% 낮다. 세션 폴더: runs/watch/<세션>/(report.html, receipt.md, stalls.txt).
감시기 판: inferwatch iw-20261110-1 (reads ring format GGRPCTR1 v1..v1) (/data/parksThink/inferwatch-iw-20261110-1)

| 설정 | 감시기 tok/s | ms/단계 | AR 지연 A→B 중앙 / p99 µs | B→A | 1 ms 넘는 기다림 ms/단계 | 그중 링크 / 상대 계산 (번) | 링크 늦음 1–2.5 / 2.5–3.5 / 3.5–7 / 7–12 / >12 ms (번) | 세션 |
|---|---:|---:|---|---|---:|---|---|---|
| mtp:sd | 199.1 | 11.09 | 30.1 / 952.5 | 29.3 / 490.5 | 0.52 | 12 / 696 | 1 / 2 / 0 / 0 / 0 | 20261111-151247 |
| mtp:def | 197.7 | 11.17 | 30.5 / 515.5 | 29.2 / 697.7 | 0.28 | 6 / 478 | 4 / 0 / 0 / 0 / 0 | 20261111-151707 |

## 노드별 DRAM 읽기 (inferwatch dram-bytes, 기록 링 켠 회의 decode 단계, 쉬는 몫 뺌)

| 회 | 노드 | GB/처리 토큰 | decode 중 GB/s | 239.7 대비 | 쉬는 몫 GB/s(중앙값, 3배 넘는 구간 수) | 처리 토큰 |
|---|---|---:|---:|---:|---|---:|
| mtp:sd | A | 0.586 | 116.7 | 0.487 | 0.354 (0) | 5332 |
| mtp:sd | B | 0.491 | 97.8 | 0.408 | 0.204 (6) | 5332 |
| mtp:def | A | 0.585 | 115.7 | 0.483 | 0.334 (0) | 5332 |
| mtp:def | B | 0.493 | 97.4 | 0.406 | 0.193 (6) | 5332 |

처리 토큰 = 감시 세션 decode 단계가 처리한 토큰(MTP 는 검증 묶음의 토큰까지 — 출력 토큰보다 많다). 85% 목표 값(none): 노드마다 GB/토큰 × 같은 구성 속도 회(기록 링 끔) tok/s ÷ 239.7.
MTP 는 decode 중 GB/s(기록 링 켠 회) 를 본다. 자료: /data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll/fixcost/ahead-1111/dram
