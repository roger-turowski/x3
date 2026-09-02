#!/usr/bin/env bash
#
# top_files.sh - Show the top 10 largest files in a directory (recursively)
#
# Usage: ./top_files.sh [directory]
#        Defaults to the current directory if no argument is given.

set -euo pipefail

# Use the directory from $1, or fall back to "."
TARGET_DIR="${1:-.}"

# Validate that the directory exists and is a directory
if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Error: '$TARGET_DIR' is not a valid directory." >&2
    exit 1
fi

# find  : walk the tree recursively and only pick regular files (-type f)
# xargs : pass them to du -h for human-readable sizes
# sort  : sort numerically on the last field (the size), reverse order
# head  : keep only the top 10
find "$TARGET_DIR" -type f -not -path '*/.git/*' \
    | xargs -r du -h 2>/dev/null \
    | sort -rh \
    | head -n 10
