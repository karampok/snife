#! /bin/bash
set -euo pipefail

#TODO: arg to define with cache-miss or not
# podman run --privileged --env-file=/home/core/envs -v /tmp:/tmp -v /:/host  --user=root --net=host --pid=host -it --rm quay.io/karampok/snife:latest dpdk-prof.sh
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
folder=/tmp/prof-"$TS"

mkdir -p "$folder" && cd "$folder"
cp "$0" . || true

# TODO// dmesg -c and at end dmesg

# TODO// run inside or outside container
f=$(grep cpuset /proc/"$(pidof "$PROCESS")"/cgroup|awk -F: '{print "/host/sys/fs/cgroup/cpuset"$3"/cpuset.cpus"}')
cpus=$(cat "$f")
echo "$cpus" > cpuset

CPU_ARRAY=$(echo "${cpus}" | awk '/-/{for (i=$1; i<=$2; i++)printf "%s%s",i,ORS;next} 1' RS=, FS=-) #1 2 3 4 53 54 55 56
# shellcheck disable=2086,2116
array=$(echo ${CPU_ARRAY})

cat /host/proc/interrupts &>"$folder"/interrupts-A
ip -s -s --json link|jq '.[] | select(.ifname | startswith("ens"))' | jq -s '.' > ip_link_show_A.json
perf record -z -C "$cpus" sleep 10
ip -s -s --json link|jq '.[] | select(.ifname | startswith("ens"))' | jq -s '.' > ip_link_show_B.json
cat /host/proc/interrupts &>"$folder"/interrupts-B

ps -ae -o pid= | xargs -n 1 taskset -cp &>"$folder"/ps-ae-opid-tasket-cp.output || true
ps -eo pid,tid,class,rtprio,ni,pri,psr,pcpu,stat,wchan:14,comm,cls >"$folder"/ps-eo-pid-tid-class.output
sysctl -A >"$folder"/sysctl-A
cat /host/proc/iomem &>"$folder"/iomem
cat /host/proc/sched_debug &>"$folder"/sched_debug
# TODO// add ./pcm-pcie.x
for c in pcm pcm-memory pcm-numa; do
  $c 5 -i=2 >"$folder"/"$c"_5_i2.output 2>&1
done
#TODO:// perf record -C 0 -z -e cache-misses -- check the output file

cat <<EOT > run-stats.sh
#! /bin/bash
set -euo pipefail

# $cpus

perf report --stdio --sort=comm,dso > perf_report_stdio_sort_commdso.output
perf report --stdio > perf_report_stdio.output
for c in $array;do
  perf report -C \$c --stdio > perf_report_stdio_cpu\$c.output
done
#perf top -C 0 -z -e cache-misses

# $PROCESS port 0 /left
jq '.[].vfinfo_list[] | select(.address=="$LEFTMAC").stats.rx' ip_link_show_A.json > leftmac-rx-A.json
jq '.[].vfinfo_list[] | select(.address=="$LEFTMAC").stats.rx' ip_link_show_B.json > leftmac-rx-B.json
jq '.[].vfinfo_list[] | select(.address=="$LEFTMAC").stats.tx' ip_link_show_A.json > leftmac-tx-A.json
jq '.[].vfinfo_list[] | select(.address=="$LEFTMAC").stats.tx' ip_link_show_B.json > leftmac-tx-B.json

# $PROCESS port 0 /right
jq '.[].vfinfo_list[] | select(.address=="$RIGHTMAC").stats.rx' ip_link_show_A.json > rightmac-rx-A.json
jq '.[].vfinfo_list[] | select(.address=="$RIGHTMAC").stats.rx' ip_link_show_B.json > rightmac-rx-B.json
jq '.[].vfinfo_list[] | select(.address=="$RIGHTMAC").stats.tx' ip_link_show_A.json > rightmac-tx-A.json
jq '.[].vfinfo_list[] | select(.address=="$RIGHTMAC").stats.tx' ip_link_show_B.json > rightmac-tx-B.json

echo "$folder"
echo "$PROCESS pod"
paste leftmac-rx-A.json leftmac-rx-B.json | awk '/"packets"/{printf "left-RX-pps %1.6e\n", (\$4-\$2)/10}'
paste rightmac-tx-A.json rightmac-tx-B.json | awk '/"tx_packets"/{printf "right-TX-pps %1.6e\n", (\$4-\$2)/10}'

paste rightmac-rx-A.json rightmac-rx-B.json | awk '/"packets"/{printf "right-RX-pps %1.6e\n", (\$4-\$2)/10}'
paste leftmac-tx-A.json leftmac-tx-B.json | awk '/"tx_packets"/{printf "left-TX-pps %1.6e\n", (\$4-\$2)/10}'

rm {left,right}mac*.json
EOT

chmod +x run-stats.sh
./run-stats.sh | tee results
# shellcheck disable=2002
cat results | tr '\n' ',' |  tr ' ' ',' >> /tmp/results.csv
echo "" >> /tmp/results.csv
