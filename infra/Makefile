NAME = quay.io/karampok/infra
VERSION = latest

build: stop
	podman build --rm  -t $(NAME):$(VERSION) .

push: 
	podman push $(NAME):$(VERSION)

stop:
	podman stop tinfra || true

run: 
	podman run --name tinfra -d --hostname=tinfra --rm --sysctl net.ipv4.ip_forward=1 --security-opt label=disable \
	-e TS_AUTH=$(TS_AUTH) -v /var/run/dbus:/var/run/dbus --privileged $(NAME):$(VERSION)
	podman exec -it tinfra /bin/bash

#mutagen sync create --name=infra-worspace (pwd) root@100.78.229.100:/workdir -i=openshift-install --ignore-vcs

