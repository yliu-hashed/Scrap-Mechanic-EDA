#!/bin/bash
DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get -y install --no-install-recommends \
  ca-certificates libffi8 \
  libreadline8t64 make lz4
apt-get autoclean
apt-get clean
apt-get -y autoremove
update-ca-certificates
rm -rf /var/lib/apt/lists
