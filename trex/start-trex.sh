#!/usr/bin/env bash
set -euo pipefail

#CPUSET=$(cat /sys/fs/cgroup/cpuset/cpuset.cpus) # e.g. 1-4,53-56
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
SOCKET=$(cat /sys/bus/pci/devices/"$LEFT"/numa_node)

cat << EOF > /etc/trex_cfg.yaml
- port_limit: 2
  version: 2
  interfaces: ["${LEFT}", "${RIGHT}"]
  port_info:
   - ip: 10.10.10.2
     default_gw: 10.10.10.1
   - ip: 10.10.20.2
     default_gw: 10.10.20.1
  platform:
   master_thread_id: ${MASTER}
   latency_thread_id: ${LATENCY}
   dual_if:
     - socket: ${SOCKET}
       threads: [${CPUS%,}]
EOF

/opt/trex/t-rex-64 --no-ofed-check --no-hw-flow-stat -i --no-scapy-server
