#!/usr/bin/env bash
NIXPKGS=. nix-build $NIXPKGS -A jito-solana
