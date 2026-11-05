재현(2026-11-05 23:30 – 11-06 01:40). repro.sh 가 node-ab.sh 를 돌리고, 같은 동안 hogmon 이 벤치(spec_bench) 중에만 B 에 부하를 건다.
repro.log: 메모리 부하(파이썬 256 MB 복사 2개 — 그때의 hogmon 은 이 판으로 덮여 없음), 나머지: GPU 띄엄띄엄 부하(hogmon-gpubursts.sh).
repro-gpu 기본 / repro-nofuse DISABLE_FUSION+COMM_FUSE=0 / repro-commfuse0 / repro-nogdnnorm / repro-fixed GDN norm 겹침 검사 / repro-fixed2 모든 검사.
