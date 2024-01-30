#! /bin/bash
set -euo pipefail

#TODO: arg to define with cache-miss or not
# podman run --privileged --cpuset-cpus=0 --env-file=/home/core/envs -v /tmp:/tmp -v /:/host --user=root --net=host --pid=host -it --rm quay.io/karampok/snife:latest pprof.sh
LEFTMAC=${LEFTMAC:-""}
RIGHTMAC=${RIGHTMAC:-""}
PROCESS=${PROCESS:-"dpdk-testpmd"}
PID=${PID:-"$(pidof "$PROCESS")"}
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


TS=$(awk -F . '{print $1;}' /proc/uptime)
folder=/tmp/pprof-"${PROCESS// /_}"/"$TS"

mkdir -p "$folder"/ethtool-{A,B} && cd "$folder"
cp "$0" . || true

# TODO// run inside or outside container
#
cdir=$(grep cpu,cpuacct /proc/"$PID"/cgroup | awk -F: '{print "/host/sys/fs/cgroup/cpu,cpuacct"$3}')
f=$(grep cpuset /proc/"$PID"/cgroup|awk -F: '{print "/host/sys/fs/cgroup/cpuset"$3"/cpuset.cpus"}')
cpus=$(cat "$f")
echo "$cpus" > cpuset

f=$(grep cpuset /proc/"$PID"/cgroup|awk -F: '{print "/host/sys/fs/cgroup/cpuset"$3"/cpuset.cpus"}')

ppid=$(grep  PPid /proc/"$PID"/status  |awk '{ print $2}')
cpumask=$(grep Cpus_allowed: /proc/"$ppid"/status|awk '{print $2}')
f=$(cat /host/sys/fs/cgroup/cpuset/cpuset.cpus)
allcpus=${f//-/ }

CPU_ARRAY=$(echo "${cpus}" | awk '/-/{for (i=$1; i<=$2; i++)printf "%s%s",i,ORS;next} 1' RS=, FS=-) #1 2 3 4 53 54 55 56
# shellcheck disable=2086,2116
array=$(echo ${CPU_ARRAY})

dmesg &>"$folder"/dmesg-A
numastat -p "$PID" &>"$folder"/numastat-A
cat /host/proc/interrupts &>"$folder"/proc_interrupts-A
cd "$cdir";grep -rRH . &>"$folder"/cgroup-cpu-A ; cd - >/dev/null

# TODO add ens under ENV
# TODO ethtool folder to be given as var
ip --json link| jq -r '.[] | select(.ifname | startswith("ens")).ifname' | xargs -i sh -c 'ethtool -S {} &> ethtool-A/s-{}'
#echo "TIMESTAMP A - $(date +"%s")"
ip -s -s --json link|jq '.[] | select(.ifname | startswith("ens"))' | jq -s '.' > ip_link_show_A.json
sleep "$INTERVAL"
ip -s -s --json link|jq '.[] | select(.ifname | startswith("ens"))' | jq -s '.' > ip_link_show_B.json
#echo "TIMESTAMP B - $(date +"%s")"
ip --json link| jq -r '.[] | select(.ifname | startswith("ens")).ifname' | xargs -i sh -c 'ethtool -S {} &> ethtool-B/s-{}'

cd "$cdir";grep -rRH . &>"$folder"/cgroup-cpu-A ; cd - >/dev/null
cat /host/proc/interrupts &>"$folder"/proc_interrupts-B
dmesg &>"$folder"/dmesg-B
numastat -p "$PID" &>"$folder"/numastat-B

ps -ae -o pid= | xargs -n 1 taskset -cp &>"$folder"/ps-ae-opid-tasket-cp || true
ps -eo pid,tid,class,rtprio,ni,pri,psr,pcpu,stat,wchan:14,comm,cls >"$folder"/ps-eo-pid-tid-class
ps  -o uname,pid,ppid,cmd,cls,psr --deselect &>"$folder"/ps-o_unmae,pid,ppid,cmd,cls,psr--deselect
pstree -p "$PID" &>"$folder"/pstree-p-process

#https://github.com/openshift-kni/debug-tools
knit cpuaff -P /host/proc >"$folder"/knit_cpuaff_c
knit cpuaff -P /host/proc -C "$cpus" >"$folder"/knit_cpuaff_c
knit irqaff -P /host/proc  >"$folder"/knit_irqaff
knit irqaff -P /host/proc -C "$cpus" >"$folder"/knit_irqaff_c
knit irqaff -P /host/proc -s -C "$cpus" >"$folder"/knit_irqaff_s_c

cat /host/proc/iomem &>"$folder"/proc_iomem
cat /host/proc/sched_debug &>"$folder"/proc_sched_debug || true
cat /host/proc/cmdline &>"$folder"/proc_cmdline
lscpu &>"$folder"/lscpu
top -b -n 2 -H -p "$PID" &>"$folder"/top-b-n2-H-p-process
knit irqwatch -P /host/proc -C "$cpus" -J -T 10 |jq . > "$folder"/knit_irqwatch_C_t10.json
sysctl -A >"$folder"/sysctl-A

tar -czvf "$folder"/cpu_info.tar.gz /sys/devices/system/cpu/ || true
# cd /sys/devices/system/cpu/cpu0/cpufreq/
# $ paste <(ls *) <(cat *) | column -s $'\t' -t
#oc debug node/x -- bash -c 'tar --ignore-failed-read  -czf - /sys/devices/system/cpu/ 2>/dev/null' > x.tar.gz

cat <<EOT > run-pcm.sh
#! /bin/bash
set -euo pipefail

mkdir -p pcm
for c in pcm pcm-memory pcm-numa pcm-iio pcm-power; do
  \$c 5 -i=2 >pcm/"\$c"_5_i2 2>&1
done

lscpu --all --extended &>pcm/lscpu_all_extended
lstopo -f pcm/lstopo.png 2>/dev/null
cpupower monitor -i 10 &>pcm/cpu_monitor
s-tui -j > pcm/s-tui.json
EOT
chmod +x run-pcm.sh

cat <<EOT > run-perf.sh
#! /bin/bash
set -euo pipefail

mkdir -p perf
# $cpus
perf record -z -C "$cpus" -- sleep "$INTERVAL" 2>/dev/null
for c in $array;do
  perf report -C \$c --stdio > perf/report_stdio_cpu\$c.out
done

perf report --stdio --sort=comm,dso > perf/report_stdio_sort_commdso
perf report --stdio > perf/report_stdio

perf sched record -z -C "$cpus" -- sleep "$INTERVAL" 2>/dev/null
for c in $array;do
  perf sched timehist -C \$c  2>&1  > perf/sched_timehist_\$c.out
done
EOT
chmod +x run-perf.sh

cat <<EOT > run-ftrace.sh
#! /bin/bash
set -uo pipefail

# https://www.kernel.org/doc/Documentation/trace/ftrace.txt
# $cpus
echo $cpumask > /host/sys/kernel/debug/tracing/tracing_cpumask

for tracer in function_graph; do
  mkdir -p ftrace-\$tracer
  echo \$tracer > /host/sys/kernel/debug/tracing/current_tracer
  echo 1 > /host/sys/kernel/debug/tracing/tracing_on && sleep 10 && echo 0 > /host/sys/kernel/debug/tracing/tracing_on

# for c in \$(seq $allcpus);do
for c in $array;do
    cat /host/sys/kernel/debug/tracing/per_cpu/cpu\$c/trace > ftrace-\$tracer/cpu\$c.trace
  done
  echo nop > /host/sys/kernel/debug/tracing/current_tracer
done

mkdir -p ftrace-sched_irq_vectors
echo sched irq_vectors > /host/sys/kernel/debug/tracing/set_event
echo 1 > /host/sys/kernel/debug/tracing/tracing_on && sleep 10 && echo 0 > /host/sys/kernel/debug/tracing/tracing_on

# for c in \$(seq $allcpus);do
for c in $array;do
  cat /host/sys/kernel/debug/tracing/per_cpu/cpu\$c/trace > ftrace-sched_irq_vectors/cpu\$c.trace
done
echo > /host/sys/kernel/debug/tracing/set_event

# TODO echo  ffffffff,ffffffff > /host/sys/kernel/debug/tracing/tracing_cpumask
trace-cmd reset
EOT
chmod +x run-ftrace.sh


cat <<EOT > run-event-trace.sh
#! /bin/bash
set -uo pipefail

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
set -uo pipefail

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

LRX=\$(paste leftmac-rx-A.json leftmac-rx-B.json | awk '/"packets"/{printf "%d\n", (\$4-\$2)/10}')
LTX=\$(paste leftmac-tx-A.json leftmac-tx-B.json | awk '/"tx_packets"/{printf "%d\n", (\$4-\$2)/10}')
RRX=\$(paste rightmac-rx-A.json rightmac-rx-B.json | awk '/"packets"/{printf "%d\n", (\$4-\$2)/10}')
RTX=\$(paste rightmac-tx-A.json rightmac-tx-B.json | awk '/"tx_packets"/{printf "%d\n", (\$4-\$2)/10}')
rm {left,right}mac*.json
echo "== [ens1fX|vf $LEFTMAC] --- <$PROCESS> --- [vf $RIGHTMAC|ens1fY] == "
echo "TS(sec),LRX(pps),RRX(pps),LTX(pps),RTX(pps),profile"
echo "$TS,\$LRX,\$RRX,\$LTX,\$RTX,$folder"
echo "$TS,\$LRX,\$RRX,\$LTX,\$RTX,$folder" >> /$folder/../results.csv
EOT
chmod +x run-stats.sh

[[ "${LEFTMAC}" != "" ]] && ./run-stats.sh | tee results
[[ "${FTRACE:-""}" != "" ]] && ./run-ftrace.sh
#./run-perf.sh
#./run-pcm.sh
#./run-event-trace.sh || true

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
#
#Rx means the application doesn't pull fast enough
#
# perf record -C "$cpus" -A -a -e irq_vectors:local_timer_entry sleep 10 2>/dev/null
# trace-cmd record -M $cpumask -e sched -e irq_vectors sleep 10 2>/dev/null
##perf top -C 0 -z -e cache-misses
# TODO// add ./pcm-pcie.x
#TODO:// perf record -C 0 -z -e cache-misses -- check the file
# echo "for f in bad-prof/perf/*;do nvim -d {good,bad}-prof/perf/${f##*/};read -n 1 ;done"
# perf stat -C "$cpus" -A -a -e irq_vectors:* -e timer:*  sleep 10 2>&1 > perf/perf_stat
#


# Notes
# isolcpus=list of critical cores – isolate the critical cores so that the
# kernel scheduler will not migrate tasks from other cores into them
# irqaffinity=list of non-critical cores – protect the critical cores from IRQs.
# rcu_nocbs=list of critical cores – stop RCU callbacks from getting called
# into the critical cores.
# nohz=off – The kernel's “dynamic ticks” mode of managing scheduling-clock ticks
# is known to impact latencies while exiting CPU idle states. This option turns
# that mode off. 
# nohz_full=list of critical cores – this will activate dynamic ticks mode of
# managing scheduling-clock ticks. The cores in the list will not get
# scheduling-clock ticks if there is only a single task running or if the core is
# idle. 

#WP feature
# pgrep "systemd|crio|kubelet" | while read i; do echo "CPUSet $(taskset -cp $i | grep -Po '[0-9]+[-,]+[0-9]+.*') for process $(ps -p $i -o comm=)"; done
# pgrep "ovn|apiserver" | while read i; do echo "CPUSet $(taskset -cp $i | grep -Po '[0-9]+[-,]+[0-9]+.*') for process $(ps -p $i -o comm=)"; done
# cat /etc/crio/crio.conf.d/01-workload-partitioning
