#!/usr/bin/env bash
set -euo pipefail

CPUSET=$(cat /sys/fs/cgroup/cpuset/cpuset.cpus) # e.g. 1-4,53-56
CPU=$(echo "${CPUSET}" | awk '/-/{for (i=$1; i<=$2; i++)printf "%s%s",i,ORS;next} 1' RS=, FS=-) # 1 2 3 4 53 54 55 56
arr=($(echo "$CPU" | tr " " "\n"))
MASTER="${arr[0]}" && unset 'arr[0]'
SIBLING=$(cat /sys/devices/system/cpu/cpu"$MASTER"/topology/core_cpus_list)
SIBLING="1,53"
LATENCY="${SIBLING##*,}"
cpus=${arr[@]/$LATENCY}
CPUS=""
for i in "${arr[@]}"
do
  if [ "$i" == $LATENCY ]
  then
    continue
  fi
  CPUS="$CPUS,$i"
done
CPUS="${CPUS:1}"

#export PCIDEVICE_OPENSHIFT_IO_SRIOVLEFTDPDKMELLANOX=0000:3b:00.6,0000:3b:00.7

SOCKET=0 #TODO
lscpu|grep node1 | awk '{print $NF}' | awk '/-/{for (i=$1; i<=$2; i++)printf "%s%s",i,ORS;next} 1' RS=, FS=- |grep ^"MASTER"$ && SOCKET=1

PCIS=$(env |grep PCIDEVICE_OPENSHIFT_IO)
INTS="${PCIS##*=}"
INTERFACES=$(echo "$INTS" | sed 's/[^,]*/"&"/g')


cat << EOF
- port_limit: 2
  version: 2
  interfaces: [${INTERFACES}]
  port_bandwidth_gb: ${PORT_BANDWIDTH_GB-5}
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
exit 

export NUMBER_THREADS="${#CPUS[@]}"

