##! /bin/bash
set -euo pipefail

echo "WORKDIR= $(pwd)"
FILE=.ts-auth

tsup (){
  echo 'tsed...'

  tailscaled 1>/tmp/tsed.logs 2>&1 &
  sleep 10
  if [ ! -S /var/run/tailscale/tailscaled.sock ]; then
      echo "tailscaled.sock does not exist. exit!"
      exit 1
  fi

  HOST=$(cat /proc/sys/kernel/hostname)
  ROUTES=${ROUTES:-$(ip route list proto kernel | cut -d " " -f1 |tr '\n' ','| sed -e 's/,$/\n/')}
  #TODO: ipv6

  until tailscale up \
      --authkey="$(cat .ts-auth)" \
      --ssh --hostname="${HOST}" \
      --advertise-routes "$ROUTES" \
      --advertise-tags "tag:unsafe" 1>/tmp/tsup.logs 2>&1 
  do
      sleep 0.1
  done
  echo "tailscale up --hostname=${HOST} --ssh --advertise-routes $ROUTES"
  echo "mosh root@${HOST} -- tmux attach -t 0 -d"
  echo "mutagen sync create --name=${HOST} (pwd) root@${HOST}:/workdir -i=bin --ignore-vcs"
}

mutagen-agent install
setup-wg.sh

if test -f "$FILE"; then
  tsup
else
  while read -r f
  do
    if [ "$f" = "${FILE}" ]
    then
      tsup
    fi
  done < <(inotifywait -m -q -e create --format %f ./)
fi

trap : TERM INT; sleep infinity & wait
