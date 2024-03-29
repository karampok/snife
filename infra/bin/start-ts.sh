##! /bin/bash
set -euo pipefail

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
  echo "# tailscale up --hostname=${HOST} --ssh --advertise-routes $ROUTES"
  echo "tailscale ssh root@${HOST}"
  echo "mosh root@${HOST} -- tmux attach -t 0 -d"
  echo "mutagen sync create --name=${HOST} (pwd) root@${HOST}:/workdir -i=bin --ignore-vcs"
  rm $FILE
}

mutagen-agent install
setup-wg.sh || true
setup-gitlabci.sh &

python3 -m http.server 9000 -d /share 1>/tmp/http.log 2>&1  &
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
ssh-keygen -A && /usr/sbin/sshd -D -p 2022 1>/tmp/sshd.log 2>&1 &

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

cleanup() {
    echo "Cleaning stuff up..."
    tailscale down
    exit
}
trap cleanup TERM INT; sleep infinity & wait
