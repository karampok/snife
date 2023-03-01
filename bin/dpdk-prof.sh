#! /bin/bash
set -euo pipefail

#TODO: arg to define with cache-miss or not
# podman run --privileged --env-file=/home/core/envs -v /tmp:/tmp -v /:/host  --user=root --net=host --pid=host -it --rm quay.io/karampok/snife:latest dpdk-prof.sh
#LEFTMAC="{LEFTMAC-:-'12:20:04:2e:6d:20'}"
#RIGHTMAC="{RIGHTMAC-:-'12:20:04:2e:6d:21'}"
PROCESS=${PROCESS:-"dpdk-testpmd"}
INTERVAL=${INTERVAL:-"10"}

#                    ┌─────────────────────────────────┐
#                    │                                 │
#                    │                                 │
#                    │                                 │
#                    │                                 │
#       leftmac      │           PROCESS-PMD           │   rightmac
# ──────────────────►│                                 ├─────────────────►
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

# TODO// run inside or outside container
f=$(grep cpuset /proc/"$(pidof "$PROCESS")"/cgroup|awk -F: '{print "/host/sys/fs/cgroup/cpuset"$3"/cpuset.cpus"}')
cpus=$(cat "$f")
echo "$cpus" > cpuset

CPU_ARRAY=$(echo "${cpus}" | awk '/-/{for (i=$1; i<=$2; i++)printf "%s%s",i,ORS;next} 1' RS=, FS=-) #1 2 3 4 53 54 55 56
# shellcheck disable=2086,2116
array=$(echo ${CPU_ARRAY})

dmesg &>"$folder"/dmesg-A
cat /host/proc/interrupts &>"$folder"/interrupts-A

# TODO add ens under ENV
ip --json link| jq -r '.[] | select(.ifname | startswith("ens")).ifname' | xargs -i sh -c 'ethtool -S {} &>"$folder"/ethtool-s-{}-A'
echo "TIMESTAMP A - $(date +"%s")"
ip -s -s --json link|jq '.[] | select(.ifname | startswith("ens"))' | jq -s '.' > ip_link_show_A.json
sleep "$INTERVAL"
ip -s -s --json link|jq '.[] | select(.ifname | startswith("ens"))' | jq -s '.' > ip_link_show_B.json
echo "TIMESTAMP B - $(date +"%s")"
ip --json link| jq -r '.[] | select(.ifname | startswith("ens")).ifname' | xargs -i sh -c 'ethtool -S {} &>"$folder"/ethtool-s-{}-B'
cat /host/proc/interrupts &>"$folder"/interrupts-B
dmesg &>"$folder"/dmesg-B

ps -ae -o pid= | xargs -n 1 taskset -cp &>"$folder"/ps-ae-opid-tasket-cp.output || true
ps -eo pid,tid,class,rtprio,ni,pri,psr,pcpu,stat,wchan:14,comm,cls >"$folder"/ps-eo-pid-tid-class.output
sysctl -A >"$folder"/sysctl-A
cat /host/proc/iomem &>"$folder"/iomem
cat /host/proc/sched_debug &>"$folder"/sched_debug

cpupower monitor -i 10 &>"$folder"/cpu_monitor.txt


cat <<EOT > run-perf.sh
#! /bin/bash
set -xeuo pipefail

mkdir -p perf
# $cpus
perf record -z -C "$cpus" sleep "$INTERVAL"
for c in $array;do
  perf report -C \$c --stdio > perf/report_stdio_cpu\$c.output
done

perf report --stdio --sort=comm,dso > perf/report_stdio_sort_commdso.output
perf report --stdio > perf/report_stdio.output

#perf top -C 0 -z -e cache-misses
# TODO// add ./pcm-pcie.x
#for y in pcm pcm-memory pcm-numa; do
#  \$c 5 -i=2 >"$folder"/"\$c"_5_i2.output 2>&1
#done
#TODO:// perf record -C 0 -z -e cache-misses -- check the output file

echo "for f in bad-prof/perf/*;do nvim -d {good,bad}-prof/perf/${f##*/};read -n 1 ;done"
EOT
chmod +x run-perf.sh

cat <<EOT > run-cpu-ftrace.sh
#! /bin/bash
set -xeuo pipefail

# https://www.kernel.org/doc/Documentation/trace/ftrace.txt
#
mkdir -p ftrace
echo function_graph > /host/sys/kernel/debug/tracing/current_tracer
echo 1 > /host/sys/kernel/debug/tracing/tracing_on && sleep 10 && echo 0 > /host/sys/kernel/debug/tracing/tracing_on

# $cpus
for c in $array;do
  cat /host/sys/kernel/debug/tracing/per_cpu/cpu\$c/trace > ftrace/cpu\$c.txt
done
echo nop > /host/sys/kernel/debug/tracing/current_tracer

EOT
chmod +x run-cpu-ftrace.sh


cat <<EOT > run-stats.sh
#! /bin/bash
set -euo pipefail

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
echo "Process: $PROCESS pod"
echo "Interval: $INTERVAL sec"
paste leftmac-rx-A.json leftmac-rx-B.json | awk '/"packets"/{printf "left-RX-pps %g\n", (\$4-\$2)/$INTERVAL}'
paste leftmac-tx-A.json leftmac-tx-B.json | awk '/"tx_packets"/{printf "left-TX-pps %g\n", (\$4-\$2)/$INTERVAL}'
paste leftmac-tx-A.json leftmac-tx-B.json
paste rightmac-tx-A.json rightmac-tx-B.json | awk '/"tx_packets"/{printf "right-TX-pps %g\n", (\$4-\$2)/$INTERVAL}'
paste rightmac-rx-A.json rightmac-rx-B.json | awk '/"packets"/{printf "right-RX-pps %g\n", (\$4-\$2)/$INTERVAL}'
paste rightmac-rx-A.json rightmac-rx-B.json
rm {left,right}mac*.json

EOT
chmod +x run-stats.sh

./run-stats.sh | tee results
# shellcheck disable=2002
#cat results | tr '\n' ',' |  tr ' ' ',' >> /tmp/results.csv
#echo "" >> /tmp/results.csv

echo tar -czvf "${folder##*/}"-tar.gz -C "$folder" .

# TODO
# hwlatdetect --threshold 5 --duration 600 --window 1000000 --width 950000


