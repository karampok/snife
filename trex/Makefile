NAME = quay.io/karampok/trex
VERSION = 3.00

build: 
	podman build --rm  --build-arg TREX_VERSION=$(VERSION)  -t $(NAME):$(VERSION) .

push: build
	podman push $(NAME):$(VERSION)

run:
	sudo podman run --rm -it --pull=always --cpuset-cpus=4  $(NAME):$(VERSION) /bin/bash
