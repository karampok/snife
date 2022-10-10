#!/usr/bin/env bash
set -xeuo pipefail

/opt/create-trex-config.sh  > /etc/trex_cfg.yaml
env
cd /opt/trex
/opt/trex/t-rex-64 --no-ofed-check --no-hw-flow-stat -i
