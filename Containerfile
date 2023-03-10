# FROM fedora:latest as build
# RUN dnf -y groupinstall "Development Tools" "Development Libraries"
# COPY ./src /src
# WORKDIR /src
# RUN mkdir out && gcc mmap_hp_alloc.c -o out/mmap-hp

FROM fedora:37 as runtime
LABEL description="Run container"

RUN dnf install -y numactl strace ipcalc iptables file bind-utils tcpdump nmap-ncat iputils iproute \ 
  dhcp-client hwdata openssh-clients wget nmstate procps-ng hwloc-gui hwloc perf stress bridge-utils \ 
  crictl stress-ng trace-cmd s-tui ethtool lsof conntrack-tools vim pcm kernel-tools dmidecode htop jq && dnf clean all

RUN setcap 'cap_net_raw+ep' /usr/sbin/tcpdump

RUN cd /tmp \ 
  && curl https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest-4.11/openshift-client-linux.tar.gz -o openshift-client-linux.tar.gz && tar xvfz openshift-client-linux.tar.gz \
  && mv oc kubectl /usr/bin/ && chmod +x /usr/bin/{oc,kubectl} && rm -f README.md openshift-client-linux.tar.gz

#https://github.com/gcla/termshark/archive/refs/tags/v2.3.0.tar.gz


#COPY --from=build /src/out/* /usr/bin/
COPY  bin/* /usr/bin/

USER 9999
CMD ["sleep", "infinity" ]
