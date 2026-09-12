#!/usr/bin/env bash

ls -1 | while read -r f; do
  d=$(awk -v f="$f" '$1==f{print substr($0, length(f)+2)}' .dsc 2>/dev/null)
  printf "%-30s \033[34m%s\033[0m\n" "$f" "$d"
done
