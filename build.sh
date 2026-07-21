#!/usr/bin/env bash
set -ex
NIXPKGS=. nix-build $NIXPKGS -A jito-solana

# Deep copy the link so we can mess with the binaries as we wish
cp -R result new-build
