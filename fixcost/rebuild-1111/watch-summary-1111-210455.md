# 추론 감시 비교 (2026-11-11 21:04:55, RUNS="mtp:tb mtp:tk")

기록 링을 켠 회라 tok/s 는 속도 회보다 ≈6% 낮다. 세션 폴더: runs/watch/<세션>/(report.html, receipt.md, stalls.txt).
감시기 판: inferwatch iw-20261110-1 (reads ring format GGRPCTR1 v1..v1) (/data/parksThink/inferwatch-iw-20261110-1)

| 설정 | 감시기 tok/s | ms/단계 | AR 지연 A→B 중앙 / p99 µs | B→A | 1 ms 넘는 기다림 ms/단계 | 그중 링크 / 상대 계산 (번) | 링크 늦음 1–2.5 / 2.5–3.5 / 3.5–7 / 7–12 / >12 ms (번) | 세션 |
|---|---:|---:|---|---|---:|---|---|---|
| mtp:tb | 208.5 | 10.59 | 29.8 / 499.8 | 29.0 / 63.6 | 0.03 | 9 / 21 | 5 / 2 / 0 / 1 / 0 | 20261111-205742 |
| mtp:tk | 205.3 | 10.76 | 29.8 / 481.3 | 28.9 / 58.2 | 0.02 | 7 / 24 | 7 / 0 / 0 / 0 / 0 | 20261111-210305 |

## 노드별 DRAM 읽기 (inferwatch dram-bytes, 기록 링 켠 회의 decode 단계, 쉬는 몫 뺌)

| 회 | 노드 | GB/처리 토큰 | decode 중 GB/s | 239.7 대비 | 쉬는 몫 GB/s(중앙값, 3배 넘는 구간 수) | 처리 토큰 |
|---|---|---:|---:|---:|---|---:|
| mtp:tb | A | 0.582 | 121.4 | 0.507 | 0.564 (0) | 5332 |
| mtp:tb | B | 0.481 | 100.3 | 0.419 | 0.572 (8) | 5332 |
| mtp:tk | A | 0.582 | 119.6 | 0.499 | 0.586 (0) | 5332 |
| mtp:tk | B | 0.482 | 99.0 | 0.413 | 0.4 (1) | 5332 |

처리 토큰 = 감시 세션 decode 단계가 처리한 토큰(MTP 는 검증 묶음의 토큰까지 — 출력 토큰보다 많다). 85% 목표 값(none): 노드마다 GB/토큰 × 같은 구성 속도 회(기록 링 끔) tok/s ÷ 239.7.
MTP 는 decode 중 GB/s(기록 링 켠 회) 를 본다. 자료: /data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll/fixcost/rebuild-1111/dram
