NAME = quay.io/karampok/dpdk
VERSION = latest
#https://catalog.redhat.com/software/containers/openshift4/dpdk-base-rhel8/5e32be6cdd19c77896004a41?container-tabs=overview


build:
	podman build --authfile=/home/kka/.pull-secret.json --rm --build-arg FROMTAG=$(VERSION) -t $(NAME):$(VERSION) .

push: build
	podman push $(NAME):$(VERSION)

run:
	podman run --rm -it --cap-add SYS_PTRACE  $(NAME):$(VERSION) /bin/bash
