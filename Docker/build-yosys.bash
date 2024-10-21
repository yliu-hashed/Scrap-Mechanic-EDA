#!/bin/bash
DEBIAN_FRONTEND=noninteractive
export PREFIX=/yosys

apt-get update -qq
apt-get -y install --no-install-recommends \
  build-essential clang lld ca-certificates curl \
  libffi-dev libreadline-dev tcl-dev python3 \
  bison flex gawk git iverilog pkg-config
apt-get autoclean
apt-get clean
apt-get -y autoremove
update-ca-certificates
rm -rf /var/lib/apt/lists

git clone https://github.com/YosysHQ/yosys repo

cd repo
git checkout 0.48
git submodule update --init
make -j 4 config-clang
make -j 4 install
