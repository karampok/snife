#! /bin/bash
set -euo pipefail

#TODO: arg to define with cache-miss or not
# podman run --privileged --env-file=/home/core/envs -v /tmp:/tmp -v /:/host --user=root --net=host --pid=host -it --rm quay.io/karampok/snife:latest dpdk-prof.sh
#LEFTMAC="{LEFTMAC-:-'12:20:04:2e:6d:20'}"
#RIGHTMAC="{RIGHTMAC-:-'12:20:04:2e:6d:21'}"
PROCESS=${PROCESS:-"dpdk-testpmd"}
PID=$(pgrep -f "$PROCESS")
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

mkdir -p "$folder"/ethtool && cd "$folder"
cp "$0" . || true

# TODO// run inside or outside container
f=$(grep cpuset /proc/"$PID"/cgroup|awk -F: '{print "/host/sys/fs/cgroup/cpuset"$3"/cpuset.cpus"}')
cpus=$(cat "$f")
echo "$cpus" > cpuset

ppid=$(grep  PPid /proc/"$PID"/status  |awk '{ print $2}')
cpumask=$(grep Cpus_allowed: /proc/"$ppid"/status|awk '{print $2}')
f=$(cat /host/sys/fs/cgroup/cpuset/cpuset.cpus)
allcpus=${f//-/ }

CPU_ARRAY=$(echo "${cpus}" | awk '/-/{for (i=$1; i<=$2; i++)printf "%s%s",i,ORS;next} 1' RS=, FS=-) #1 2 3 4 53 54 55 56
# shellcheck disable=2086,2116
array=$(echo ${CPU_ARRAY})

dmesg &>"$folder"/dmesg-A
cat /host/proc/interrupts &>"$folder"/proc_interrupts-A

# TODO add ens under ENV
# TODO ethtool folder to be given as var
ip --json link| jq -r '.[] | select(.ifname | startswith("ens")).ifname' | xargs -i sh -c 'ethtool -S {} &> ethtool/s-{}-A'
echo "TIMESTAMP A - $(date +"%s")"
ip -s -s --json link|jq '.[] | select(.ifname | startswith("ens"))' | jq -s '.' > ip_link_show_A.json
sleep "$INTERVAL"
ip -s -s --json link|jq '.[] | select(.ifname | startswith("ens"))' | jq -s '.' > ip_link_show_B.json
echo "TIMESTAMP B - $(date +"%s")"
ip --json link| jq -r '.[] | select(.ifname | startswith("ens")).ifname' | xargs -i sh -c 'ethtool -S {} &> ethtool/s-{}-B'
cat /host/proc/interrupts &>"$folder"/proc_interrupts-B
dmesg &>"$folder"/dmesg-B

ps -ae -o pid= | xargs -n 1 taskset -cp &>"$folder"/ps-ae-opid-tasket-cp.output || true
ps -eo pid,tid,class,rtprio,ni,pri,psr,pcpu,stat,wchan:14,comm,cls >"$folder"/ps-eo-pid-tid-class.output
#https://github.com/openshift-kni/debug-tools
knit cpuaff -P /host/proc -C "$cpus" >"$folder"/knit_cpuaff_c.output
knit irqaff -P /host/proc -C "$cpus" >"$folder"/knit_irqaff_c.output
knit irqaff -P /host/proc -s -C "$cpus" >"$folder"/knit_irqaff_s_c.output
knit irqwatch -P /host/proc -C "$cpus" -J -T 10 |jq . > "$folder"/knit_irqwatch_C_t10.json
s-tui -j > "$folder"/s-tui.json
lscpu --all --extended &>"$folder"/lscpu_all_extended
lstopo -f "$folder"/lstopo.png 2>/dev/null
sysctl -A >"$folder"/sysctl-A
cat /host/proc/iomem &>"$folder"/proc_iomem
cat /host/proc/sched_debug &>"$folder"/proc_sched_debug
cat /host/proc/cmdline &>"$folder"/proc_cmdline

cpupower monitor -i 10 &>"$folder"/cpu_monitor.output
pstree -p "$PID" &>"$folder"/pstree-p-process.output
top -b -n 2 -H -p "$PID" &>"$folder"/top-b-n2-H-p-process.output

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


perf sched record -z -C  "$cpus"  -- sleep 10
perf sched timehist > perf/perf_sched_timehist
perf stat -C "$cpus" -A -a -e irq_vectors:* -e timer:*  sleep 10 2>&1 > perf/perf_stat


#perf top -C 0 -z -e cache-misses
# TODO// add ./pcm-pcie.x
#for y in pcm pcm-memory pcm-numa; do
#  \$c 5 -i=2 >"$folder"/"\$c"_5_i2.output 2>&1
#done
#TODO:// perf record -C 0 -z -e cache-misses -- check the output file

echo "for f in bad-prof/perf/*;do nvim -d {good,bad}-prof/perf/${f##*/};read -n 1 ;done"
EOT
chmod +x run-perf.sh

cat <<EOT > run-ftrace.sh
#! /bin/bash
set -euo pipefail

# https://www.kernel.org/doc/Documentation/trace/ftrace.txt
# $cpus
# echo $cpumask > /host/sys/kernel/debug/tracing/tracing_cpumask

for tracer in function_graph; do
  mkdir -p ftrace-\$tracer
  echo \$tracer > /host/sys/kernel/debug/tracing/current_tracer
  echo 1 > /host/sys/kernel/debug/tracing/tracing_on && sleep 10 && echo 0 > /host/sys/kernel/debug/tracing/tracing_on

  for c in $array;do
    cat /host/sys/kernel/debug/tracing/per_cpu/cpu\$c/trace > ftrace-\$tracer/cpu\$c.txt
  done
  echo nop > /host/sys/kernel/debug/tracing/current_tracer
done

mkdir -p ftrace-sched_irq_vectors
echo sched irq_vectors > /host/sys/kernel/debug/tracing/set_event
echo 1 > /host/sys/kernel/debug/tracing/tracing_on && sleep 10 && echo 0 > /host/sys/kernel/debug/tracing/tracing_on
for c in $array;do
  cat /host/sys/kernel/debug/tracing/per_cpu/cpu\$c/trace > ftrace-sched_irq_vectors/cpu\$c.trace
done
echo > /host/sys/kernel/debug/tracing/set_event

perf record -C "$cpus" -A -a -e irq_vectors:local_timer_entry sleep 10 2>/dev/null
trace-cmd record -M $cpumask -e sched -e irq_vectors sleep 10 2>/dev/null
# TODO echo  ffffffff,ffffffff > /host/sys/kernel/debug/tracing/tracing_cpumask
EOT
chmod +x run-ftrace.sh


cat <<EOT > run-event-trace.sh
#! /bin/bash
set -euo pipefail

#echo ff,ffffffff,ffffffff,ffffffff > /host/sys/kernel/debug/tracing/tracing_cpumask
#echo ffffffff,ffffffff > /host/sys/kernel/debug/tracing/tracing_cpumask

#enable the events you need :cat /host/sys/kernel/debug/tracing/available_events|grep irq
echo irq_vectors:* sched:* > /host/sys/kernel/debug/tracing/set_event
# enable stacktrace for the specific even to find the function call
# echo stacktrace > /host/sys/kernel/debug/tracing/events/sched/sched_switch/trigger
# echo stacktrace > /host/sys/kernel/debug/tracing/events/irq_vectors/reschedule_entry/trigger
# e.g. reschedule_entry/ smp_reschedule_interrupt cause by function send_ipi
# find that in all CPUS
#echo *send_IPI* *send_ipi* > /host/sys/kernel/debug/set_ftrace_filter
#echo function > /host/sys/kernel/debug/tracing/current_tracer
echo 1 > /host/sys/kernel/debug/tracing/tracing_on && sleep 10 && echo 0 > /host/sys/kernel/debug/tracing/tracing_on

mkdir -p events-trace
cat /host/sys/kernel/debug/tracing/trace > events-trace/trace
for c in \$(seq $allcpus);do
  cat /host/sys/kernel/debug/tracing/per_cpu/cpu\$c/trace > events-trace/cpu\$c.trace
  echo > /host/sys/kernel/debug/tracing/per_cpu/cpu\$c/trace
done

trace-cmd reset

EOT
chmod +x run-event-trace.sh


cat <<EOT > run-stats.sh
#! /bin/bash
set -euo pipefail

# $PROCESS port 0 /left
jq '.[].vfinfo_list[]? | select(.address=="$LEFTMAC").stats.rx' ip_link_show_A.json > leftmac-rx-A.json
jq '.[].vfinfo_list[]? | select(.address=="$LEFTMAC").stats.rx' ip_link_show_B.json > leftmac-rx-B.json
jq '.[].vfinfo_list[]? | select(.address=="$LEFTMAC").stats.tx' ip_link_show_A.json > leftmac-tx-A.json
jq '.[].vfinfo_list[]? | select(.address=="$LEFTMAC").stats.tx' ip_link_show_B.json > leftmac-tx-B.json

# $PROCESS port 0 /right
jq '.[].vfinfo_list[]? | select(.address=="$RIGHTMAC").stats.rx' ip_link_show_A.json > rightmac-rx-A.json
jq '.[].vfinfo_list[]? | select(.address=="$RIGHTMAC").stats.rx' ip_link_show_B.json > rightmac-rx-B.json
jq '.[].vfinfo_list[]? | select(.address=="$RIGHTMAC").stats.tx' ip_link_show_A.json > rightmac-tx-A.json
jq '.[].vfinfo_list[]? | select(.address=="$RIGHTMAC").stats.tx' ip_link_show_B.json > rightmac-tx-B.json

echo "$folder"
echo "Process: $PROCESS pod"
echo "Interval: $INTERVAL sec"
#paste leftmac-rx-A.json leftmac-rx-B.json | awk '/"packets"/{printf "left-RX-pps %g\n", (\$4-\$2)/$INTERVAL}'
paste leftmac-rx-A.json leftmac-rx-B.json | awk '/"packets"/{printf "left-RX-pps %d\n", (\$4-\$2)}'
#paste leftmac-tx-A.json leftmac-tx-B.json | awk '/"tx_packets"/{printf "left-TX-pps %g\n", (\$4-\$2)/$INTERVAL}'
paste leftmac-tx-A.json leftmac-tx-B.json | awk '/"tx_packets"/{printf "left-TX-pps %d\n", (\$4-\$2)}'
paste leftmac-tx-A.json leftmac-tx-B.json > paste-left
#paste rightmac-tx-A.json rightmac-tx-B.json | awk '/"tx_packets"/{printf "right-TX-pps %g\n", (\$4-\$2)/$INTERVAL}'
paste rightmac-tx-A.json rightmac-tx-B.json | awk '/"tx_packets"/{printf "right-TX-pps %d\n", (\$4-\$2)}'
#paste rightmac-rx-A.json rightmac-rx-B.json | awk '/"packets"/{printf "right-RX-pps %g\n", (\$4-\$2)/$INTERVAL}'
paste rightmac-rx-A.json rightmac-rx-B.json | awk '/"packets"/{printf "right-RX-pps %d\n", (\$4-\$2)}'
paste rightmac-rx-A.json rightmac-rx-B.json > paste-right
rm {left,right}mac*.json

EOT
chmod +x run-stats.sh

./run-stats.sh | tee results
./run-perf.sh | true
./run-ftrace.sh | true
./run-event-trace.sh | true
# shellcheck disable=2002
#cat results | tr '\n' ',' |  tr ' ' ',' >> /tmp/results.csv
#echo "" >> /tmp/results.csv

echo tar -czvf "${folder##*/}".tar.gz -C "$folder" .

# TODO
# hwlatdetect --threshold 5 --duration 600 --window 1000000 --width 950000

# cho 0 > /sys/kernel/debug/tracing/tracing_on
#echo 1 > /sys/kernel/debug/tracing/options/stacktrace
#echo > /sys/kernel/debug/tracing/trace
#echo 1 > /sys/kernel/debug/tracing/events/timer/enable
#echo 1 > /sys/kernel/debug/tracing/events/workqueue/enable
#echo 1 > /sys/kernel/debug/tracing/events/sched/sched_switch/enable
#echo 1 > /sys/kernel/debug/tracing/events/sched/sched_migrate_task/enable
#echo 1 > /sys/kernel/debug/tracing/events/sched/sched_wakeup/enable
#echo 1 > /sys/kernel/debug/tracing/events/irq/enable
#echo 1 > /sys/kernel/debug/tracing/events/irq_vectors/enable
##echo 1 > /sys/kernel/debug/tracing/events/probe/enable
#echo 1 > /sys/kernel/debug/tracing/tracing_on
#cat /sys/kernel/debug/tracing/trace > trace.txt
# do not forget to turn off the tracer
#echo 0 > /sys/kernel/debug/tracing/tracing_on

#TX is driver or firmware bc it means the application put the packets but the nic is nlt able to pull fast enough
#Rx means the application doesn't pull fast enough
