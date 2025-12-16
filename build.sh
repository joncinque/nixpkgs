#!/usr/bin/env bash
set -ex
NIXPKGS=. nix-build $NIXPKGS -A jito-solana

# Deep copy the link so we can mess with the binaries as we wish
cp -R result new-build
sudo setcap cap_net_raw,cap_net_admin,cap_bpf,cap_perfmon=p ./new-build/bin/agave-validator
