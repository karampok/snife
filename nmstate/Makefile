NAME = quay.io/karampok/nmstate
VERSION = latest

build: 
	podman build --rm  -t $(NAME):$(VERSION) .

push: build
	podman push $(NAME):$(VERSION)

run: 
	podman run --name nmstate --rm -d $(NAME):$(VERSION)

exec: 
	podman exec -it nmstate /bin/bash



