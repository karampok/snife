NAME = quay.io/karampok/pktgen
VERSION = latest

build:
	podman build --rm  -t $(NAME):$(VERSION) .

push: build
	podman push $(NAME):$(VERSION)

run:
	podman run --rm -it --cap-add SYS_PTRACE  $(NAME):$(VERSION) /bin/bash

try:
	oc port-forward pktgen 22022 &
	oc rsync scripts/ pktgen:/opt/scripts
  #@echo socat - TCP4:localhost:22022 < ./run.cmd
