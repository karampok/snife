##! /bin/bash
set -euo pipefail

echo "WORKDIR= $(pwd)"
FILE=.ts-auth
if test -f "$FILE"; then
  echo 'tsed...'

  tailscaled 1>/tmp/tsed.logs 2>&1 &
  sleep 10
  if [ ! -S /var/run/tailscale/tailscaled.sock ]; then
      echo "tailscaled.sock does not exist. exit!"
      exit 1
  fi

  ROUTES=$(ip route list proto kernel | cut -d " " -f1 |tr '\n' ','| sed -e 's/,$/\n/')
  HOST=$(cat /proc/sys/kernel/hostname)

  #TODO: ipv6

  until tailscale up \
      --authkey="$(cat .ts-auth)" \
      --ssh --hostname="${HOST}" \
      --advertise-routes "$ROUTES" \
      --advertise-tags "tag:unsafe" 1>/tmp/tsup.logs 2>&1 
  do
      sleep 0.1
  done
  echo "mosh root@${HOST} -- tmux attach -t 0 -d"
  echo "mutagen sync create --name=${HOST} (pwd) root@${HOST}:/workdir -i=bin --ignore-vcs"
  echo "--advertise-routes $ROUTES"
fi

mutagen-agent install

trap : TERM INT; sleep infinity & wait
