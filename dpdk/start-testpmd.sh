#!/usr/bin/env bash
set -euo pipefail

CPUMASK=$(grep Cpus_allowed: /proc/1/status | sed s/,//g | grep -o "[0-9,a-f]*$")
LASTCPU=$(grep processor /proc/cpuinfo  | tail -1 | grep -o "[0-9]*$")

I=0
ACPUS=()
while [ $I -le "$LASTCPU" ] ; do
  if [ "$(((0x"$CPUMASK" >> "$I") & 1))" -eq 1 ] ; then
          ACPUS+=("$I")
  fi
  I=$(("$I" + 1))
done

MASTER="${ACPUS[0]}" && unset 'ACPUS[0]'
SIBLINGS=$(cat /sys/devices/system/cpu/cpu"$MASTER"/topology/core_cpus_list)
LATENCY="${SIBLINGS##*,}"

CPUS=""
NUM=0
for i in "${ACPUS[@]}"; do
  if [ "$i" == "$LATENCY" ]; then
    # We drop all siblings
    break
  fi
  CPUS="$CPUS,$i"
  NUM=$(("$NUM" + 1))
done
CPUS="${CPUS:1}"


X=$(grep k8s.v1.cni.cncf.io/network-status /etc/podnetinfo/annotations| awk -F= '{print $2}')
X=$(echo -e "$X")
X="${X//\\/}"
X="${X%\"}"
X="${X#\"}"
NETINFO=$X
LEFT=$(echo "$NETINFO" | jq -r '.[] | select(.interface=="net1")."device-info".pci."pci-address"')
RIGHT=$(echo "$NETINFO" | jq -r '.[] | select(.interface=="net2")."device-info".pci."pci-address"')

NBCORES=${NBCORES:-$NUM}
: "${CHANNELS:-4}"

dpdk-testpmd -l "$MASTER,$CPUS" -a "$LEFT" -a "$RIGHT" -n "$CHANNELS" \
  -- --nb-cores="$NUM" --forward-mode=mac --rxd=2048 --txd=2048  \
  --eth-peer=0,"$LEFT_MAC" --eth-peer=1,"$RIGHT_MAC" --auto-start --stats-period 10
