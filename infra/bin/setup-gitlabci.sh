#!/bin/bash
set -euo pipefail

GITLAB=.gitlabci-token
gitlabup (){
  #if [ -f "$GITLAB" ]; then
  source $GITLAB
  #fi

  echo 'gitlabci up...'

  URL=${URL:-"gitlab.cee.redhat.com"}
  mkdir -p /etc/gitlab-runner/certs/
  openssl s_client -showcerts -connect "$URL":443 -servername  "$URL"  < /dev/null 2>/dev/null | openssl x509 -outform PEM > /etc/gitlab-runner/certs/"$URL".crt

  gitlab-runner register  --url https://"$URL"  --token "$TOKEN" --non-interactive --executor "shell" --name "$(hostname)-runner"
  gitlab-runner run >/tmp/gitlabrunner.log 2>&1  &

}

if test -f "$GITLAB"; then
  gitlabup
else
  while read -r f
  do
    if [ "$f" = "${GITLAB}" ]
    then
      gitlabup
    fi
  done < <(inotifywait -m -q -e create --format %f ./)
fi
