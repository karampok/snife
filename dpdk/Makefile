NAME = quay.io/karampok/dpdk
VERSION = latest

build:
	podman build --authfile=/home/kka/.pull-secret.json --rm --build-arg FROMTAG=$(VERSION) -t $(NAME):$(VERSION) .

push: build
	podman push $(NAME):$(VERSION)

run:
	podman run --rm -it --cap-add SYS_PTRACE  $(NAME):$(VERSION) /bin/bash
