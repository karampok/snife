#!/usr/bin/env bash
set -euo pipefail

CPUMASK=$(grep Cpus_allowed: /proc/1/status | sed s/,//g | grep -o "[0-9,a-f]*$")
LASTCPU=$(grep processor /proc/cpuinfo | tail -1 | grep -o "[0-9]*$")

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
    break # We drop all siblings
  fi
  CPUS="$CPUS,$i"
  NUM=$(("$NUM" + 1))
  if [[ "$NUM" == "${NBCORES:--1}" ]]; then # forwarding cores
    break
  fi
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
M=$(echo "$CPUS" | awk -F, '{ print $1".0,"$2".1" }')

# https://pktgen-dpdk.readthedocs.io/en/latest/usage_pktgen.html
echo tmux new-session pktgen -vvv -l "$MASTER,$CPUS" -a "$LEFT" -a "$RIGHT" -n "${CHANNELS:-4}" \
  -- -P -m \""$M"\" -l /tmp/pktgen.log -T -f /opt/black-yellow.theme -f /opt/pktgen.pkt
