NAME = quay.io/karampok/pktgen
VERSION = latest

build:
	podman build --rm  -t $(NAME):$(VERSION) .

push: build
	podman push $(NAME):$(VERSION)

run:
	podman run --rm -it --cap-add SYS_PTRACE  $(NAME):$(VERSION) /bin/bash
