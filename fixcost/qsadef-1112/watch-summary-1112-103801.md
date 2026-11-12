# 추론 감시 비교 (2026-11-12 10:38:01, RUNS="mtp:def none:def")

기록 링을 켠 회라 tok/s 는 속도 회보다 ≈6% 낮다. 세션 폴더: runs/watch/<세션>/(report.html, receipt.md, stalls.txt).
감시기 판: inferwatch iw-20261110-1 (reads ring format GGRPCTR1 v1..v1) (/data/parksThink/inferwatch-iw-20261110-1)

| 설정 | 감시기 tok/s | ms/단계 | AR 지연 A→B 중앙 / p99 µs | B→A | 1 ms 넘는 기다림 ms/단계 | 그중 링크 / 상대 계산 (번) | 링크 늦음 1–2.5 / 2.5–3.5 / 3.5–7 / 7–12 / >12 ms (번) | 세션 |
|---|---:|---:|---|---|---:|---|---|---|
| mtp:def | 206.4 | 10.70 | 30.5 / 460.8 | 29.1 / 52.0 | 0.18 | 2 / 59 | 2 / 0 / 0 / 0 / 0 | 20261112-103202 |
| none:def | 43.3 | 23.45 | 18.5 / 72.2 | 18.1 / 38.5 | 0.05 | 1 / 7 | 0 / 1 / 0 / 0 / 0 | 20261112-103605 |

## 노드별 DRAM 읽기 (inferwatch dram-bytes, 기록 링 켠 회의 decode 단계, 쉬는 몫 뺌)

| 회 | 노드 | GB/처리 토큰 | decode 중 GB/s | 239.7 대비 | 쉬는 몫 GB/s(중앙값, 3배 넘는 구간 수) | 처리 토큰 |
|---|---|---:|---:|---:|---|---:|
| mtp:def | A | 0.585 | 120.7 | 0.504 | 0.324 (1) | 5354 |
| mtp:def | B | 0.48 | 99.1 | 0.413 | 1.429 (0) | 5354 |
| none:def | A | 3.182 | 137.7 | 0.574 | 0.322 (0) | 1427 |
| none:def | B | 3.147 | 136.1 | 0.568 | 1.473 (0) | 1427 |

처리 토큰 = 감시 세션 decode 단계가 처리한 토큰(MTP 는 검증 묶음의 토큰까지 — 출력 토큰보다 많다). 85% 목표 값(none): 노드마다 GB/토큰 × 같은 구성 속도 회(기록 링 끔) tok/s ÷ 239.7.
MTP 는 decode 중 GB/s(기록 링 켠 회) 를 본다. 자료: /data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll/fixcost/qsadef-1112/dram
