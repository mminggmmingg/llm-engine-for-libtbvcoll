#!/usr/bin/env bash
# CPUs that do not take Thunderbolt NHI interrupts, as a taskset list (e.g. "0,1,7-20"): tbcpus.sh [min interrupt count, default 100000]
# Each NHI vector's interrupts are finished by a per-CPU kworker on the system workqueue of the CPU that took them
# (thunderbolt ring_work). A busy-polling engine thread on that CPU shares it with that kworker in 3 ms scheduler slices,
# so a message that lands there can wait milliseconds (fixcost/lnk-1107). The kernel picks these CPUs at boot, so read them
# here instead of hard-coding them. Vectors with fewer interrupts than the threshold (control rings) are ignored.
min=${1:-100000}
skip=$(awk -v m="$min" '/thunderbolt/{s=0; for(i=2;i<NF;i++) if($i ~ /^[0-9]+$/) s+=$i; if(s>=m){sub(":","",$1); print $1}}' /proc/interrupts |
       while read -r irq; do cat /proc/irq/$irq/effective_affinity_list; done | tr ',' '\n' | sort -nu)
python3 -I - "$(nproc --all)" $skip <<'EOF'
import sys
n, skip = int(sys.argv[1]), {int(x) for x in sys.argv[2:]}
keep = [c for c in range(n) if c not in skip]
out, i = [], 0
while i < len(keep):
    j = i
    while j + 1 < len(keep) and keep[j + 1] == keep[j] + 1:
        j += 1
    out.append(str(keep[i]) if i == j else f"{keep[i]}-{keep[j]}")
    i = j + 1
print(",".join(out))
EOF
