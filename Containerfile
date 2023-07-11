# FROM fedora:latest as build
# RUN dnf -y groupinstall "Development Tools" "Development Libraries"
# COPY ./src /src
# WORKDIR /src
# RUN mkdir out && gcc mmap_hp_alloc.c -o out/mmap-hp

FROM fedora:37 as runtime
LABEL description="Run container"

RUN dnf install -y numactl strace ipcalc iptables file bind-utils tcpdump nmap-ncat iputils iproute \
 dhcp-client hwdata openssh-clients wget nmstate procps-ng hwloc-gui hwloc perf stress bridge-utils \
 pciutils python3-pip  iperf iperf3 crictl realtime-tests stress-ng trace-cmd s-tui ethtool lsof conntrack-tools vim pcm kernel-tools \
 sysstat tree dmidecode htop jq && dnf clean all

RUN setcap 'cap_net_raw+ep' /usr/sbin/tcpdump
RUN pip3 install pandas matplotlib

#COPY --from=build /src/out/* /usr/bin/
COPY  bin/* /usr/bin/

USER 0
CMD exec /bin/bash -c "trap : TERM INT; sleep infinity & wait"
