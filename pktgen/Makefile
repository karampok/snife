NAME = quay.io/karampok/pktgen
TAG = 22.07
DPDK_VERSION = 22.07
PKTGEN_VERSION = 22.07.1

build:
	podman build --rm --build-arg PKTGEN_VERSION=$(PKTGEN_VERSION) --build-arg DPDK_VERSION=$(DPDK_VERSION) -t $(NAME):$(TAG) .

push: build
	podman push $(NAME):$(TAG)

run:
	podman run --rm -it --cap-add SYS_PTRACE $(NAME):$(VERSION) /bin/bash

try:
	oc port-forward pktgen 22022 &
	oc rsync scripts/ pktgen:/opt/scripts
  #@echo socat - TCP4:localhost:22022 < ./run.cmd
