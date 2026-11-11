# 추론 감시 비교 (2026-11-11 22:59:10, RUNS="mtp:fin none:fin mtp:fin none:fin")

기록 링을 켠 회라 tok/s 는 속도 회보다 ≈6% 낮다. 세션 폴더: runs/watch/<세션>/(report.html, receipt.md, stalls.txt).
감시기 판: inferwatch iw-20261110-1 (reads ring format GGRPCTR1 v1..v1) (/data/parksThink/inferwatch-iw-20261110-1)

| 설정 | 감시기 tok/s | ms/단계 | AR 지연 A→B 중앙 / p99 µs | B→A | 1 ms 넘는 기다림 ms/단계 | 그중 링크 / 상대 계산 (번) | 링크 늦음 1–2.5 / 2.5–3.5 / 3.5–7 / 7–12 / >12 ms (번) | 세션 |
|---|---:|---:|---|---|---:|---|---|---|
| mtp:fin | 207.7 | 10.63 | 30.0 / 469.5 | 29.2 / 52.1 | 0.01 | 2 / 6 | 2 / 0 / 0 / 0 / 0 | 20261111-225306 |
| none:fin | 41.6 | 24.37 | 18.5 / 66.9 | 18.2 / 51.4 | 0.04 | 2 / 7 | 2 / 0 / 0 / 0 / 0 | 20261111-225711 |

## 노드별 DRAM 읽기 (inferwatch dram-bytes, 기록 링 켠 회의 decode 단계, 쉬는 몫 뺌)

| 회 | 노드 | GB/처리 토큰 | decode 중 GB/s | 239.7 대비 | 쉬는 몫 GB/s(중앙값, 3배 넘는 구간 수) | 처리 토큰 |
|---|---|---:|---:|---:|---|---:|
| mtp:fin | A | 0.583 | 121.2 | 0.506 | 0.587 (1) | 5332 |
| mtp:fin | B | 0.484 | 100.5 | 0.419 | 1.462 (0) | 5332 |
| none:fin | A | 3.219 | 134.0 | 0.559 | 0.588 (0) | 1429 |
| none:fin | B | 3.188 | 132.7 | 0.554 | 1.469 (0) | 1429 |

처리 토큰 = 감시 세션 decode 단계가 처리한 토큰(MTP 는 검증 묶음의 토큰까지 — 출력 토큰보다 많다). 85% 목표 값(none): 노드마다 GB/토큰 × 같은 구성 속도 회(기록 링 끔) tok/s ÷ 239.7.
MTP 는 decode 중 GB/s(기록 링 켠 회) 를 본다. 자료: /data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll/fixcost/rebuild-1111/dram
