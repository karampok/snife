FROM fedora:35
RUN dnf install -y bind-utils tcpdump nmap-ncat iputils iproute procps-ng stress && dnf clean all
RUN setcap 'cap_net_raw+ep' /usr/sbin/tcpdump
RUN cd /tmp && curl https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest-4.9/openshift-client-linux.tar.gz -o openshift-client-linux.tar.gz && tar xvfz openshift-client-linux.tar.gz \
&& mv oc kubectl /usr/bin/ && chmod +x /usr/bin/{oc,kubectl} && rm -f README.md openshift-client-linux.tar.gz
USER 9999
CMD ["sleep", "infinity" ]
