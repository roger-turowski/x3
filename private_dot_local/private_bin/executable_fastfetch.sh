#!/usr/bin/env bash

# ~/.local/bin/fastfetch.sh
source /etc/os-release

case "$ID" in
  opensuse-tumbleweed)
    #exec fastfetch --logo-color-1 "38;2;115;186;37" --logo-color-2 "38;2;23;147;209"
    exec fastfetch --logo-color-1 blue --logo-color-2 bright_blue
    ;;
  arch)
    exec fastfetch --logo-color-1 cyan
    ;;
  *)
    exec fastfetch
    ;;
esac

