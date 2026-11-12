# 추론 감시 비교 (2026-11-12 16:58:46, RUNS="none:ctx mtp:ctx")

기록 링을 켠 회라 tok/s 는 속도 회보다 ≈6% 낮다. 세션 폴더: runs/watch/<세션>/(report.html, receipt.md, stalls.txt).
감시기 판: inferwatch iw-20261110-1 (reads ring format GGRPCTR1 v1..v1) (/data/parksThink/inferwatch-iw-20261110-1)

| 설정 | 감시기 tok/s | ms/단계 | AR 지연 A→B 중앙 / p99 µs | B→A | 1 ms 넘는 기다림 ms/단계 | 그중 링크 / 상대 계산 (번) | 링크 늦음 1–2.5 / 2.5–3.5 / 3.5–7 / 7–12 / >12 ms (번) | 세션 |
|---|---:|---:|---|---|---:|---|---|---|
| none:ctx | 26.2 | 40.06 | 18.7 / 185.0 | 18.5 / 115.8 | 0.06 | 2 / 5 | 0 / 1 / 1 / 0 / 0 | 20261112-163333 |
| mtp:ctx | 105.7 | 21.13 | 27.0 / 353.2 | 26.5 / 305.5 | 0.03 | 2 / 4 | 2 / 0 / 0 / 0 / 0 | 20261112-164822 |

## 노드별 DRAM 읽기 (inferwatch dram-bytes, 기록 링 켠 회의 decode 단계, 쉬는 몫 뺌)

| 회 | 노드 | GB/처리 토큰 | decode 중 GB/s | 239.7 대비 | 쉬는 몫 GB/s(중앙값, 3배 넘는 구간 수) | 처리 토큰 |
|---|---|---:|---:|---:|---|---:|
| none:ctx | A | 3.846 | 100.8 | 0.42 | 0.323 (1) | 424 |
| none:ctx | B | 3.842 | 100.7 | 0.42 | 1.56 (0) | 424 |
| mtp:ctx | A | 0.711 | 75.2 | 0.314 | 0.75 (6) | 1449 |
| mtp:ctx | B | 0.574 | 60.7 | 0.253 | 1.417 (0) | 1449 |

처리 토큰 = 감시 세션 decode 단계가 처리한 토큰(MTP 는 검증 묶음의 토큰까지 — 출력 토큰보다 많다). 85% 목표 값(none): 노드마다 GB/토큰 × 같은 구성 속도 회(기록 링 끔) tok/s ÷ 239.7.
MTP 는 decode 중 GB/s(기록 링 켠 회) 를 본다. 자료: /data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll/fixcost/ctx-1112/dram
