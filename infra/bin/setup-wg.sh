#!/bin/bash

server_privkey=$(wg genkey)
server_pubkey=$(echo "$server_privkey" | wg pubkey)

peer_privkey=$(wg genkey)
peer_pubkey=$(echo "$peer_privkey" | wg pubkey)

cat <<EOF > "/etc/wireguard/wg0.conf"
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = ${server_privkey}

[Peer]
PublicKey = ${peer_pubkey}
AllowedIPs = 10.0.0.0/24
EOF

wg-quick up wg0
iptables -t nat -I POSTROUTING 1 -s 10.0.0.0/24 -o baremetal.10 -j MASQUERADE

echo "
cat <<EOF > /tmp/lab.conf
[Interface]
PrivateKey = $peer_privkey
Address = 10.0.0.2/24
PostUp =resolvectl dns lab 10.10.20.10; sudo resolvectl domain lab eric.vlab

[Peer]
PublicKey = $server_pubkey
AllowedIPs = 10.0.0.0/24, 10.10.10.0/24, 10.10.20.0/24
Endpoint = ${PUBLICIP:-IP}:51820
PersistentKeepalive = 25
EOF

sudo wg-quick up /tmp/lab.conf

sudo resolvectl dns lab 10.10.20.10
sudo resolvectl domain lab eric.vlab
"
