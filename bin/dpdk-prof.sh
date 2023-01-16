#! /bin/bash
set -euo pipefail

#LEFTMAC="{LEFTMAC-:-'12:20:04:2e:6d:20'}"
#RIGHTMAC="{RIGHTMAC-:-'12:20:04:2e:6d:21'}"
PROCESS=${PROCESS:-"dpdk-testpmd"}

#                    ┌─────────────────────────────────┐
#                    │                                 │
#                    │                                 │
#                    │                                 │
#                    │                                 │
#       leftmac      │           PROCESS-PMD           │   rightmac
# ──────────────────►│                                 ├─────────────────►   right
#                    │                                 │
#                    │                                 │
#                    │                                 │
#                    │                                 │
#                    │                                 │
#                    │                                 │
#                    │                                 │
#                    └─────────────────────────────────┘


TS=$(date +"%s")
folder=prof-"$TS"

mkdir -p /tmp/"$folder" && cd /tmp/"$folder"
cp "$0" . || true

f=$(grep cpuset /proc/"$(pidof "$PROCESS")"/cgroup|awk -F: '{print "/sys/fs/cgroup/cpuset"$3"/cpuset.cpus"}')
cpus=$(cat "$f")
echo "$cpus" > cpuset


#CPU_ARRAY=$(echo "${cpus}" | awk '/-/{for (i=$1; i<=$2; i++)printf "%s%s",i,ORS;next} 1' RS=, FS=-) #1 2 3 4 53 54 55 56
#array=$(echo ${CPU_ARRAY})

ip -s -s --json link|jq '.[] | select(.ifname | startswith("ens"))' | jq -s '.' > ip_link_show_A.json
sleep 10 #perf record -z -C $cpus sleep 10
ip -s -s --json link|jq '.[] | select(.ifname | startswith("ens"))' | jq -s '.' > ip_link_show_B.json


cat <<EOT > run-stats.sh
#! /bin/bash
set -euo pipefail

# $cpus

# $PROCESS port 0 /left
jq '.[].vfinfo_list[] | select(.address=="$LEFTMAC").stats.rx' ip_link_show_A.json >  leftmac-rx-A.json
jq '.[].vfinfo_list[] | select(.address=="$LEFTMAC").stats.rx' ip_link_show_B.json >  leftmac-rx-B.json
jq '.[].vfinfo_list[] | select(.address=="$LEFTMAC").stats.tx' ip_link_show_A.json >  leftmac-tx-A.json
jq '.[].vfinfo_list[] | select(.address=="$LEFTMAC").stats.tx' ip_link_show_B.json >  leftmac-tx-B.json

# $PROCESS port 0 /right
jq '.[].vfinfo_list[] | select(.address=="$RIGHTMAC").stats.rx' ip_link_show_A.json >  rightmac-rx-A.json
jq '.[].vfinfo_list[] | select(.address=="$RIGHTMAC").stats.rx' ip_link_show_B.json >  rightmac-rx-B.json
jq '.[].vfinfo_list[] | select(.address=="$RIGHTMAC").stats.tx' ip_link_show_A.json >  rightmac-tx-A.json
jq '.[].vfinfo_list[] | select(.address=="$RIGHTMAC").stats.tx' ip_link_show_B.json >  rightmac-tx-B.json

echo "$folder"
echo "$PROCESS pod"
paste leftmac-rx-A.json leftmac-rx-B.json | awk    '/"packets"/{printf "left-RX-pps %1.6e\n", (\$4-\$2)/10}'
paste rightmac-tx-A.json rightmac-tx-B.json | awk '/"tx_packets"/{printf "right-TX-pps %1.6e\n", (\$4-\$2)/10}'

paste leftmac-rx-A.json leftmac-rx-B.json | awk    '/"packets"/{printf "left-RX-pps %1.6e\n", (\$4-\$2)/10}'
paste rightmac-tx-A.json rightmac-tx-B.json | awk '/"tx_packets"/{printf "right-TX-pps %1.6e\n", (\$4-\$2)/10}'

rm {left,right}mac*.json
EOT

chmod +x run-stats.sh
./run-stats.sh | tee results
