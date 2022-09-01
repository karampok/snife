NAME = quay.io/karampok/dpdk
VERSION = 21.11.1

build: 
	podman build --rm --build-arg DPDK_VERSION=$(VERSION) -t $(NAME):$(VERSION) .

push: build
	podman push $(NAME):$(VERSION)

run:
	podman run --rm -it --cap-add SYS_PTRACE  $(NAME):$(VERSION) /bin/bash
