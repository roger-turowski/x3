is_file_exists() {
    local f="$1"
    if [[ -f "$f" ]]; then
        return 0  # Success
    else
        return 1  # Failure
    fi
}

chezmoi-cd() {
  cd "$(chezmoi source-path "$@")"
}

