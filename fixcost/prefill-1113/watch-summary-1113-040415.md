# 추론 감시 비교 (2026-11-13 04:04:15, RUNS="none:mma mtp:mma")

기록 링을 켠 회라 tok/s 는 속도 회보다 ≈6% 낮다. 세션 폴더: runs/watch/<세션>/(report.html, receipt.md, stalls.txt).
감시기 판: inferwatch iw-20261110-1 (reads ring format GGRPCTR1 v1..v1) (/data/parksThink/inferwatch-iw-20261110-1)

| 설정 | 감시기 tok/s | ms/단계 | AR 지연 A→B 중앙 / p99 µs | B→A | 1 ms 넘는 기다림 ms/단계 | 그중 링크 / 상대 계산 (번) | 링크 늦음 1–2.5 / 2.5–3.5 / 3.5–7 / 7–12 / >12 ms (번) | 세션 |
|---|---:|---:|---|---|---:|---|---|---|
| none:mma | 43.7 | 23.23 | 18.4 / 66.0 | 18.1 / 39.1 | 0.02 | 0 / 5 | 0 / 0 / 0 / 0 / 0 | 20261113-035743 |
| mtp:mma | 216.4 | 10.21 | 32.5 / 473.6 | 29.8 / 44.8 | 0.01 | 4 / 5 | 3 / 1 / 0 / 0 / 0 | 20261113-040226 |

## 노드별 DRAM 읽기 (inferwatch dram-bytes, 기록 링 켠 회의 decode 단계, 쉬는 몫 뺌)

| 회 | 노드 | GB/처리 토큰 | decode 중 GB/s | 239.7 대비 | 쉬는 몫 GB/s(중앙값, 3배 넘는 구간 수) | 처리 토큰 |
|---|---|---:|---:|---:|---|---:|
| none:mma | A | 3.184 | 139.0 | 0.58 | 0.43 (0) | 1427 |
| none:mma | B | 3.184 | 139.0 | 0.58 | 0.171 (4) | 1427 |
| mtp:mma | A | 0.595 | 128.8 | 0.537 | 0.44 (0) | 5354 |
| mtp:mma | B | 0.482 | 104.3 | 0.435 | 0.189 (7) | 5354 |

처리 토큰 = 감시 세션 decode 단계가 처리한 토큰(MTP 는 검증 묶음의 토큰까지 — 출력 토큰보다 많다). 85% 목표 값(none): 노드마다 GB/토큰 × 같은 구성 속도 회(기록 링 끔) tok/s ÷ 239.7.
MTP 는 decode 중 GB/s(기록 링 켠 회) 를 본다. 자료: /data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll/fixcost/prefill-1113/dram
