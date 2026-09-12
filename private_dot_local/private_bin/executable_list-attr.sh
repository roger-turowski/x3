#!/usr/bin/env bash

ls -1 | while read -r f; do
  c=$(getfattr -n user.comment --only-values "$f" 2>/dev/null)
  [[ -n "$c" ]] && echo "$f  # $c" || echo "$f"
done   
