FROM fedora:latest as build
RUN dnf -y groupinstall "Development Tools" "Development Libraries"
COPY ./src /src
WORKDIR /src
RUN mkdir out && gcc mmap_hp_alloc.c -o out/mmap-hp

FROM fedora:35 as runtime
LABEL description="Run container"

RUN dnf install -y numactl strace file bind-utils tcpdump nmap-ncat iputils iproute procps-ng stress && dnf clean all
RUN setcap 'cap_net_raw+ep' /usr/sbin/tcpdump
RUN cd /tmp \ 
    && curl https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest-4.9/openshift-client-linux.tar.gz -o openshift-client-linux.tar.gz && tar xvfz openshift-client-linux.tar.gz \
&& mv oc kubectl /usr/bin/ && chmod +x /usr/bin/{oc,kubectl} && rm -f README.md openshift-client-linux.tar.gz

COPY --from=build /src/out/* /usr/bin/

USER 9999
CMD ["sleep", "infinity" ]
