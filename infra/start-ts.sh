##! /bin/bash
set -euo pipefail

echo 'Starting up tailscale...'

tailscaled 1>/tmp/tsed.logs 2>&1  &
sleep 5
if [ ! -S /var/run/tailscale/tailscaled.sock ]; then
    echo "tailscaled.sock does not exist. exit!"
    exit 1
fi

ROUTES=$(ip route list proto kernel | cut -d " " -f1 |tr '\n' ','| sed -e 's/,$/\n/')
HOST=$(cat /proc/sys/kernel/hostname)

#TODO: ipv6

until tailscale up \
    --authkey="${TS_AUTH}" \
    --ssh --hostname="${HOST}" \
    --advertise-routes "$ROUTES" \
    --advertise-tags "tag:unsafe" 1>/tmp/tsup.logs 2>&1 
do
    sleep 0.1
done

mutagen-agent install
echo "mosh root@workstation -- tmux attach -t 0 -d"

trap : TERM INT; sleep infinity & wait
