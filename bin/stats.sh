#! /bin/bash
set -euo pipefail

LEFTMAC=${2:-"10:00:00:00:00:12"}
RIGHTMAC=${1:-"20:00:00:00:00:13"}

echo "TS,\$TX,\$RX"
sTXA=$(ip -s -s --json link|jq '.[] | select(.ifname | startswith("ens"))' | jq -s '.'| jq -r --arg mac "$LEFTMAC" '.[].vfinfo_list[]? | select(.address==$mac).stats.tx.tx_packets')
sRXA=$(ip -s -s --json link|jq '.[] | select(.ifname | startswith("ens"))' | jq -s '.'| jq -r --arg mac "$RIGHTMAC" '.[].vfinfo_list[]? | select(.address==$mac).stats.rx.packets')

TXA=$sTXA
RXA=$sRXA

trap ctrl_c INT

function ctrl_c() {
  eTXB=$(ip -s -s --json link|jq '.[] | select(.ifname | startswith("ens"))' | jq -s '.'| jq -r --arg mac "$LEFTMAC" '.[].vfinfo_list[]? | select(.address==$mac).stats.tx.tx_packets')
  eRXB=$(ip -s -s --json link|jq '.[] | select(.ifname | startswith("ens"))' | jq -s '.'| jq -r --arg mac "$RIGHTMAC" '.[].vfinfo_list[]? | select(.address==$mac).stats.rx.packets')
  echo ""
  echo "#TOTAL", $(( eTXB - sTXA )), $(( eRXB - sRXA ))
  exit
}

while true;do
  sleep 1
  ip -s -s --json link|jq '.[] | select(.ifname | startswith("ens"))' | jq -s '.' > /tmp/data.json
  TXB=$(jq -r --arg mac "$LEFTMAC" '.[].vfinfo_list[]? | select(.address==$mac).stats.tx.tx_packets' /tmp/data.json)
  RXB=$(jq -r --arg mac "$RIGHTMAC" '.[].vfinfo_list[]? | select(.address==$mac).stats.rx.packets' /tmp/data.json)
  echo "$(date +%s)", $(( TXB - TXA )), $(( RXB - RXA ))
  TXA=$TXB
  RXA=$RXB
done
