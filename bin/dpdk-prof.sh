#! /bin/bash
set -euo pipefail


#                             ┌─────────────────────────────────┐
#                             │                                 │
#                             │                                 │
#                             │                                 │
#                             │                                 │
#                ens1f0v0     │           TEST-PMD              │   ens1f2v1
#  left    ──────────────────►│                                 ├─────────────────►   right
#                             │                                 │
#                             │                                 │
#                             │                                 │
#                             │                                 │
#                             │                                 │
#                             │                                 │
#                             │                                 │
#                             └─────────────────────────────────┘


TS=$(date +"%s")
folder=prof-"$TS"

mkdir -p /tmp/"$folder" && cd /tmp/"$folder"
cp "$0" . || true

f=$(grep cpuset /proc/"$(pidof dpdk-testpmd)"/cgroup|awk -F: '{print "/sys/fs/cgroup/cpuset"$3"/cpuset.cpus"}')
cpus=$(cat "$f")
echo "$cpus" > cpuset


#CPU_ARRAY=$(echo "${cpus}" | awk '/-/{for (i=$1; i<=$2; i++)printf "%s%s",i,ORS;next} 1' RS=, FS=-) #1 2 3 4 53 54 55 56
#array=$(echo ${CPU_ARRAY})

ip -s --json link|jq '.[] | select(.ifname=="ens1f0" or .ifname=="ens1f2")' | jq -s '.' > ip_link_show_A.json
sleep 10 #perf record -z -C $cpus sleep 10
ip -s --json link|jq '.[] | select(.ifname=="ens1f0" or .ifname=="ens1f2")' | jq -s '.' > ip_link_show_B.json


cat <<EOT > run-stats.sh
#! /bin/bash
set -euo pipefail

# $cpus

# TestPMD port 0 /left
jq '.[] | select(.ifname=="ens1f0").vfinfo_list[0].stats.rx' ip_link_show_A.json>  ens1f0-rx-A.json
jq '.[] | select(.ifname=="ens1f0").vfinfo_list[0].stats.rx' ip_link_show_B.json>  ens1f0-rx-B.json
jq '.[] | select(.ifname=="ens1f0").vfinfo_list[0].stats.tx' ip_link_show_A.json>  ens1f0-tx-A.json
jq '.[] | select(.ifname=="ens1f0").vfinfo_list[0].stats.tx' ip_link_show_B.json>  ens1f0-tx-B.json

# TestPMD port 1 /right
jq '.[] | select(.ifname=="ens1f2").vfinfo_list[1].stats.rx' ip_link_show_A.json>  ens1f2-rx-A.json
jq '.[] | select(.ifname=="ens1f2").vfinfo_list[1].stats.rx' ip_link_show_B.json>  ens1f2-rx-B.json
jq '.[] | select(.ifname=="ens1f2").vfinfo_list[1].stats.tx' ip_link_show_A.json>  ens1f2-tx-A.json
jq '.[] | select(.ifname=="ens1f2").vfinfo_list[1].stats.tx' ip_link_show_B.json>  ens1f2-tx-B.json


echo "$folder"
echo "test-pmd pod"
paste ens1f0-rx-A.json ens1f0-rx-B.json | awk    '/"packets"/{printf "left-RX-pps %1.6e\n", (\$4-\$2)/10}'
paste ens1f0-tx-A.json ens1f0-tx-B.json | awk '/"tx_packets"/{printf "right-TX-pps %1.6e\n", (\$4-\$2)/10}'

paste ens1f2-rx-A.json ens1f2-rx-B.json | awk    '/"packets"/{printf "left-RX-pps %1.6e\n", (\$4-\$2)/10}'
paste ens1f2-tx-A.json ens1f2-tx-B.json | awk '/"tx_packets"/{printf "right-TX-pps %1.6e\n", (\$4-\$2)/10}'

rm ens*.json
# TREX /left
jq '.[] | select(.ifname=="ens1f0").vfinfo_list[1].stats.rx' ip_link_show_A.json>  ens1f0-rx-A.json
jq '.[] | select(.ifname=="ens1f0").vfinfo_list[1].stats.rx' ip_link_show_B.json>  ens1f0-rx-B.json
jq '.[] | select(.ifname=="ens1f0").vfinfo_list[1].stats.tx' ip_link_show_A.json>  ens1f0-tx-A.json
jq '.[] | select(.ifname=="ens1f0").vfinfo_list[1].stats.tx' ip_link_show_B.json>  ens1f0-tx-B.json

# TRE port 1 /right
jq '.[] | select(.ifname=="ens1f2").vfinfo_list[0].stats.rx' ip_link_show_A.json>  ens1f2-rx-A.json
jq '.[] | select(.ifname=="ens1f2").vfinfo_list[0].stats.rx' ip_link_show_B.json>  ens1f2-rx-B.json
jq '.[] | select(.ifname=="ens1f2").vfinfo_list[0].stats.tx' ip_link_show_A.json>  ens1f2-tx-A.json
jq '.[] | select(.ifname=="ens1f2").vfinfo_list[0].stats.tx' ip_link_show_B.json>  ens1f2-tx-B.json

echo "TREX"
paste ens1f0-rx-A.json ens1f0-rx-B.json | awk    '/"packets"/{printf "left-RX-pps %1.6e\n", (\$4-\$2)/10}'
paste ens1f0-tx-A.json ens1f0-tx-B.json | awk '/"tx_packets"/{printf "right-TX-pps %1.6e\n", (\$4-\$2)/10}'

paste ens1f2-rx-A.json ens1f2-rx-B.json | awk    '/"packets"/{printf "left-RX-pps %1.6e\n", (\$4-\$2)/10}'
paste ens1f2-tx-A.json ens1f2-tx-B.json | awk '/"tx_packets"/{printf "right-TX-pps %1.6e\n", (\$4-\$2)/10}'

rm ens*.json

EOT

chmod +x run-stats.sh
./run-stats.sh | tee results
