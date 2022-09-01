#!/usr/bin/env bash
set -euo pipefail

CPU=$(cat /sys/fs/cgroup/cpuset/cpuset.cpus)
PCIS=$(env | grep PCIDEVICE_OPENSHIFT_IO)
IFS=', ' read -r -a INT <<< "${PCIS##*=}"

dpdk-testpmd -l "${CPU}" -a "${INT[0]}" -a "${INT[1]}" -n 4 \
    -- -i --nb-cores=4 --rxd=4096 --txd=4096 --rxq=7 --txq=7 \
    --forward-mode=mac \
    --eth-peer=0,50:00:00:00:00:01 --eth-peer=1,50:00:00:00:00:02
