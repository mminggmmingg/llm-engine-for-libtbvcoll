# 추론 감시 비교 (2026-11-11 23:40:57, RUNS="mtp:rb mtp:rt")

기록 링을 켠 회라 tok/s 는 속도 회보다 ≈6% 낮다. 세션 폴더: runs/watch/<세션>/(report.html, receipt.md, stalls.txt).
감시기 판: inferwatch iw-20261110-1 (reads ring format GGRPCTR1 v1..v1) (/data/parksThink/inferwatch-iw-20261110-1)

| 설정 | 감시기 tok/s | ms/단계 | AR 지연 A→B 중앙 / p99 µs | B→A | 1 ms 넘는 기다림 ms/단계 | 그중 링크 / 상대 계산 (번) | 링크 늦음 1–2.5 / 2.5–3.5 / 3.5–7 / 7–12 / >12 ms (번) | 세션 |
|---|---:|---:|---|---|---:|---|---|---|
| mtp:rb | 205.6 | 10.74 | 30.3 / 466.7 | 29.1 / 50.6 | 0.01 | 0 / 5 | 0 / 0 / 0 / 0 / 0 | 20261111-233151 |
| mtp:rt | 213.1 | 10.37 | 30.0 / 460.8 | 28.9 / 57.2 | 0.02 | 9 / 7 | 7 / 2 / 1 / 0 / 0 | 20261111-233907 |

## 노드별 DRAM 읽기 (inferwatch dram-bytes, 기록 링 켠 회의 decode 단계, 쉬는 몫 뺌)

| 회 | 노드 | GB/처리 토큰 | decode 중 GB/s | 239.7 대비 | 쉬는 몫 GB/s(중앙값, 3배 넘는 구간 수) | 처리 토큰 |
|---|---|---:|---:|---:|---|---:|
| mtp:rb | A | 0.584 | 120.0 | 0.501 | 0.561 (0) | 5332 |
| mtp:rb | B | 0.484 | 99.5 | 0.415 | 1.489 (0) | 5332 |
| mtp:rt | A | 0.584 | 124.4 | 0.519 | 0.577 (2) | 5332 |
| mtp:rt | B | 0.49 | 104.4 | 0.435 | 0.243 (38) | 5332 |

처리 토큰 = 감시 세션 decode 단계가 처리한 토큰(MTP 는 검증 묶음의 토큰까지 — 출력 토큰보다 많다). 85% 목표 값(none): 노드마다 GB/토큰 × 같은 구성 속도 회(기록 링 끔) tok/s ÷ 239.7.
MTP 는 decode 중 GB/s(기록 링 켠 회) 를 본다. 자료: /data/parksThink/macos_reversing/codex/zbook-rdma/llm-engine-for-libtbvcoll/fixcost/rebuild-1111/dram
