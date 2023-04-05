NAME = quay.io/karampok/nmstate
VERSION = latest

build: 
	podman build --rm  -t $(NAME):$(VERSION) .

push: build
	podman push $(NAME):$(VERSION)

run: 
	podman run --cap-add=NET_ADMIN,SYS_ADMIN --name nmstate --rm -d $(NAME):$(VERSION)

exec: 
	podman exec -it nmstate /bin/bash
