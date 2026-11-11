# 추론 감시 비교 (2026-11-12 00:25:13, RUNS="mtp:rb2 mtp:rt2")

기록 링을 켠 회라 tok/s 는 속도 회보다 ≈6% 낮다. 세션 폴더: runs/watch/<세션>/(report.html, receipt.md, stalls.txt).
감시기 판: inferwatch iw-20261110-1 (reads ring format GGRPCTR1 v1..v1) (/data/parksThink/inferwatch-iw-20261110-1)

| 설정 | 감시기 tok/s | ms/단계 | AR 지연 A→B 중앙 / p99 µs | B→A | 1 ms 넘는 기다림 ms/단계 | 그중 링크 / 상대 계산 (번) | 링크 늦음 1–2.5 / 2.5–3.5 / 3.5–7 / 7–12 / >12 ms (번) | 세션 |
|---|---:|---:|---|---|---:|---|---|---|
| mtp:rb2 | 209.2 | 10.56 | 30.1 / 453.0 | 28.9 / 54.8 | 0.01 | 2 / 4 | 1 / 0 / 0 / 0 / 0 | 20261112-001914 |
| mtp:rt2 | 214.1 | 10.32 | 30.0 / 463.6 | 29.1 / 50.6 | 0.02 | 6 / 11 | 6 / 0 / 0 / 0 / 0 | 20261112-002324 |

## 노드별 DRAM 읽기 (inferwatch dram-bytes, 기록 링 켠 회의 decode 단계, 쉬는 몫 뺌)

| 회 | 노드 | GB/처리 토큰 | decode 중 GB/s | 239.7 대비 | 쉬는 몫 GB/s(중앙값, 3배 넘는 구간 수) | 처리 토큰 |
|---|---|---:|---:|---:|---|---:|
| mtp:rb2 | A | 0.583 | 121.9 | 0.509 | 0.64 (0) | 5332 |
| mtp:rb2 | B | 0.484 | 101.2 | 0.422 | 1.464 (0) | 5332 |
| mtp:rt2 | A | 0.583 | 124.9 | 0.521 | 0.595 (0) | 5332 |
| mtp:rt2 | B | 0.483 | 103.4 | 0.431 | 1.342 (0) | 5332 |

처리 토큰 = 감시 세션 decode 단계가 처리한 토큰(MTP 는 검증 묶음의 토큰까지 — 출력 토큰보다 많다). 85% 목표 값(none): 노드마다 GB/토큰 × 같은 구성 속도 회(기록 링 끔) tok/s ÷ 239.7.
MTP 는 decode 중 GB/s(기록 링 켠 회) 를 본다. 자료: /data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll/fixcost/rebuild-1111/dram
