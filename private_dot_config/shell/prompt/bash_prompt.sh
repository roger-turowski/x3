__build_ps1() {
    local rc=$?

    local status_part
    if (( rc == 0 )); then
        status_part='\[\e[32m\]OK\[\e[0m\] '
    else
        status_part="\[\e[31m\]ERR(${rc})\[\e[0m\] "
    fi

    local shlvl_part=""
    if (( SHLVL > 1 )); then
        shlvl_part=" \[\e[31m\](${SHLVL})\[\e[0m\]"
    fi

    local user_color
    if (( EUID == 0 )); then
        user_color='\[\e[31m\]'
    else
        user_color='\[\e[32m\]'
    fi

    local git_part=""
    local git_branch
    git_branch=$(git symbolic-ref --short HEAD 2>/dev/null) \
        || git_branch=$(git rev-parse --short HEAD 2>/dev/null)
    if [[ -n "$git_branch" ]]; then
        local git_color='\[\e[35m\]'
        if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
            git_color='\[\e[33m\]'
        fi
        git_part=" ${git_color}[${git_branch}]\[\e[0m\]"
    fi

    local r_count t_count
    r_count=$(jobs -pr 2>/dev/null | wc -l)   # running
    t_count=$(jobs -ps 2>/dev/null | wc -l)   # stopped/suspended

    local jobs_part=""
    if (( r_count > 0 || t_count > 0 )); then
        local r_part=""
        local t_part=""

        if (( r_count > 0 )); then
            r_part="\[\e[36m\]R:${r_count}\[\e[0m\]"
        fi
        if (( t_count > 0 )); then
            t_part="\[\e[33m\]T:${t_count}\[\e[0m\]"
        fi

        if [[ -n "$r_part" && -n "$t_part" ]]; then
            jobs_part=" (${r_part},${t_part})"
        elif [[ -n "$r_part" ]]; then
            jobs_part=" (${r_part})"
        else
            jobs_part=" (${t_part})"
        fi
    fi

    PS1="${status_part}${user_color}\u\[\e[0m\]@\[\e[34m\]\h\[\e[0m\]:\[\e[33m\]\w\[\e[0m\]${git_part}${shlvl_part}${jobs_part} \$ "
}
PROMPT_COMMAND=__build_ps1

