#!/usr/bin/env bash
printf "Reinstalling fzf...\n"
eval "$(fzf --bash)"
printf "Sourcing .bashrc file...\n"
source "${HOME}/.bashrc"
printf "Done.\n"

