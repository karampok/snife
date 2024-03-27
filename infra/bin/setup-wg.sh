#!/bin/bash
set -euo pipefail

WGFILE=.wg-auth
if [ -f "$WGFILE" ]; then
  source $WGFILE
fi

WGPRIVKEY=${WGPRIVKEY:-""}
server_privkey=$WGPRIVKEY
if [ "$WGPRIVKEY" == "" ]; then
    server_privkey=$(wg genkey)
    echo "export WGPRIVKEY=$server_privkey" > $WGFILE
fi
server_pubkey=$(echo "$server_privkey" | wg pubkey)

WGPEERPRIVKEY=${WGPEERPRIVKEY:-""}
peer_privkey=$WGPEERPRIVKEY
WGPEERPUBKEY=${WGPEERPUBKEY:-""}
peer_pubkey=$WGPEERPUBKEY
if [ "$WGPEERPUBKEY" == "" ]; then
  peer_privkey=$(wg genkey)
  echo "export WGPEERPRIVKEY=$peer_privkey" >> $WGFILE
  peer_pubkey=$(echo "$peer_privkey" | wg pubkey)
  echo "export WGPEERPUBKEY=$peer_pubkey" >> $WGFILE
fi

cat <<EOF > "/etc/wireguard/wg0.conf"
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
MTU = 1280
PrivateKey = ${server_privkey} #public (${server_pubkey})
PreUp=iptables -t nat -I POSTROUTING 1 -s 10.0.0.0/24 -o access -j MASQUERADE

[Peer]
PublicKey = ${peer_pubkey} #private (${peer_privkey})
AllowedIPs = 10.0.0.2/32
EOF

wg-quick up wg0

echo "
###################################################
echo \"
[Interface]
PrivateKey = $peer_privkey
Address = 10.0.0.2/24
PostUp =resolvectl dns %i 10.10.20.10; sudo resolvectl domain %i ~telco.vlab; sudo resolvectl dnsovertls %i no

[Peer]
PublicKey = $server_pubkey
AllowedIPs = 10.0.0.0/24, 10.10.10.0/24, 10.10.20.0/24, 192.168.100.0/24
Endpoint = ${PUBLICIP:-x.y.z.k}:51820
PersistentKeepalive = 25
\" > /tmp/lab.conf
sudo wg-quick up /tmp/lab.conf

mutagen sync create --name=$(hostname) (pwd) root@10.0.0.1:2022:/workspace
mosh --ssh=\"ssh -p 2022\" root@10.0.0.1
###################################################
" | tee /tmp/wgup

#add-wg-user.sh
