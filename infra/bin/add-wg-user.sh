#!/bin/bash
set -euo pipefail

WGFILE=.wg-auth
if [ -f "$WGFILE" ]; then
  source $WGFILE
fi

WGPRIVKEY=${WGPRIVKEY:-""}
server_privkey=$WGPRIVKEY
server_pubkey=$(echo "$server_privkey" | wg pubkey)

peer_privkey=$(wg genkey)
peer_pubkey=$(echo "$peer_privkey" | wg pubkey)

cat <<EOF >> "/etc/wireguard/wg0.conf"

[Peer]
PublicKey = ${peer_pubkey} #private (${peer_privkey})
AllowedIPs = 10.0.0.0/24
EOF

wg syncconf wg0 <(wg-quick strip wg0)

echo "
###################################################
cat <<EOF > /tmp/lab.conf
[Interface]
PrivateKey = $peer_privkey
Address = 10.0.0.3/24
PostUp =resolvectl dns %i 10.10.20.10; sudo resolvectl domain %i ~telco.vlab; sudo resolvectl dnsovertls %i no

[Peer]
PublicKey = $server_pubkey
AllowedIPs = 10.0.0.0/24, 10.10.10.0/24, 10.10.20.0/24, 192.168.100.0/24
Endpoint = ${PUBLICIP:-x.y.z.k}:51820
PersistentKeepalive = 25
EOF

sudo wg-quick up /tmp/lab.conf
###################################################
" | tee -a /tmp/wgup
