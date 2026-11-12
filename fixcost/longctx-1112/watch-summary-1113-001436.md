# 추론 감시 비교 (2026-11-13 00:14:36, RUNS="none:new mtp:new")

기록 링을 켠 회라 tok/s 는 속도 회보다 ≈6% 낮다. 세션 폴더: runs/watch/<세션>/(report.html, receipt.md, stalls.txt).
감시기 판: inferwatch iw-20261110-1 (reads ring format GGRPCTR1 v1..v1) (/data/parksThink/inferwatch-iw-20261110-1)

| 설정 | 감시기 tok/s | ms/단계 | AR 지연 A→B 중앙 / p99 µs | B→A | 1 ms 넘는 기다림 ms/단계 | 그중 링크 / 상대 계산 (번) | 링크 늦음 1–2.5 / 2.5–3.5 / 3.5–7 / 7–12 / >12 ms (번) | 세션 |
|---|---:|---:|---|---|---:|---|---|---|
| none:new | 29.7 | 35.35 | 18.3 / 115.8 | 18.0 / 66.7 | 1.03 | 0 / 57 | 0 / 0 / 0 / 0 / 0 | 20261112-234929 |
| mtp:new | 106.6 | 20.94 | 38.9 / 313.0 | 26.3 / 78.2 | 0.03 | 0 / 4 | 0 / 0 / 0 / 0 / 0 | 20261113-000346 |

## 노드별 DRAM 읽기 (inferwatch dram-bytes, 기록 링 켠 회의 decode 단계, 쉬는 몫 뺌)

| 회 | 노드 | GB/처리 토큰 | decode 중 GB/s | 239.7 대비 | 쉬는 몫 GB/s(중앙값, 3배 넘는 구간 수) | 처리 토큰 |
|---|---|---:|---:|---:|---|---:|
| none:new | A | 3.246 | 96.4 | 0.402 | 0.162 (6) | 424 |
| none:new | B | 3.173 | 94.2 | 0.393 | 1.397 (0) | 424 |
| mtp:new | A | 0.67 | 71.4 | 0.298 | 0.186 (6) | 1449 |
| mtp:new | B | 0.5 | 53.4 | 0.223 | 1.417 (0) | 1449 |

처리 토큰 = 감시 세션 decode 단계가 처리한 토큰(MTP 는 검증 묶음의 토큰까지 — 출력 토큰보다 많다). 85% 목표 값(none): 노드마다 GB/토큰 × 같은 구성 속도 회(기록 링 끔) tok/s ÷ 239.7.
MTP 는 decode 중 GB/s(기록 링 켠 회) 를 본다. 자료: /data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll/fixcost/longctx-1112/dram
