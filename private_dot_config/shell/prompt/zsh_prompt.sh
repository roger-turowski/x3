autoload -Uz colors && colors

__build_prompt() {
    local rc=$?

    # Last command status
    local status_part
    if (( rc == 0 )); then
        status_part="%{$fg[green]%}OK%{$reset_color%} "
    else
        status_part="%{$fg[red]%}ERR(${rc})%{$reset_color%} "
    fi

    # Shell level
    local shlvl_part=""
    if (( SHLVL > 1 )); then
        shlvl_part=" %{$fg[red]%}(${SHLVL})%{$reset_color%}"
    fi

    # User color: red for root, green for normal
    local user_color
    if (( EUID == 0 )); then
        user_color="$fg[red]"
    else
        user_color="$fg[green]"
    fi

    # Git info
    local git_part=""
    local git_branch
    git_branch=$(git symbolic-ref --short HEAD 2>/dev/null) \
        || git_branch=$(git rev-parse --short HEAD 2>/dev/null)
    if [[ -n "$git_branch" ]]; then
        local git_color="$fg[magenta]"
        if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
            git_color="$fg[yellow]"
        fi
        git_part=" %{${git_color}%}[${git_branch}]%{$reset_color%}"
    fi

    # Background jobs
    local r_count t_count
    r_count=$(jobs -r 2>/dev/null | wc -l)
    t_count=$(jobs -s 2>/dev/null | wc -l)

    local jobs_part=""
    if (( r_count > 0 || t_count > 0 )); then
        local r_part=""
        local t_part=""

        if (( r_count > 0 )); then
            r_part="%{$fg[cyan]%}R:${r_count}%{$reset_color%}"
        fi
        if (( t_count > 0 )); then
            t_part="%{$fg[yellow]%}T:${t_count}%{$reset_color%}"
        fi

        if [[ -n "$r_part" && -n "$t_part" ]]; then
            jobs_part=" (${r_part},${t_part})"
        elif [[ -n "$r_part" ]]; then
            jobs_part=" (${r_part})"
        else
            jobs_part=" (${t_part})"
        fi
    fi

    PROMPT="${status_part}${user_color}%n%{$reset_color%}@%{$fg[blue]%}%m%{$reset_color%}:%{$fg[yellow]%}%~%{$reset_color%}${git_part}${shlvl_part}${jobs_part}%# "
}

precmd() {
    __build_prompt
}
