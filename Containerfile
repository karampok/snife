# FROM fedora:latest as build
# RUN dnf -y groupinstall "Development Tools" "Development Libraries"
# COPY ./src /src
# WORKDIR /src
# RUN mkdir out && gcc mmap_hp_alloc.c -o out/mmap-hp


FROM fedora:latest as runtime
LABEL description="Run container"

RUN dnf install -y numactl strace ipcalc iptables file bind-utils tcpdump nmap-ncat iputils iproute \
 util-linux-core dhcp-client hwdata openssh-clients wget nmstate procps-ng hwloc-gui hwloc perf stress bridge-utils nicstat \
 pciutils python3-pip iperf iperf3 crictl realtime-tests stress-ng trace-cmd s-tui ethtool lsof conntrack-tools vim pcm kernel-tools \
 xdp-tools bpftool libpcap nftables less sysstat tree dmidecode htop jq && dnf clean all

RUN setcap 'cap_net_raw+ep' /usr/sbin/tcpdump
#RUN pip3 install pandas matplotlib

#COPY --from=build /src/out/* /usr/bin/
COPY bin/* /usr/bin/
COPY --from=quay.io/retis/retis:latest /usr/bin/retis /usr/local/bin/retis
COPY --from=quay.io/retis/retis:latest /etc/retis/profiles /etc/retis/profiles
COPY --from=docker.io/cilium/pwru:latest /usr/local/bin/pwru /usr/local/bin/pwru


USER 0
CMD exec /bin/bash -c "trap : TERM INT; sleep infinity & wait"
