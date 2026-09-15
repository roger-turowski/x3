__build_ps1() {
    local rc=$?

    local status_part
    if (( rc == 0 )); then
        status_part='\[\e[32m\]✓\[\e[0m\] '
    else
        status_part="\[\e[31m\]✘(${rc})\[\e[0m\] "
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

#    local git_part=""
#    local git_branch
#    git_branch=$(git symbolic-ref --short HEAD 2>/dev/null) \
#        || git_branch=$(git rev-parse --short HEAD 2>/dev/null)

#   if [[ -n "$git_branch" ]]; then
#	local git_dirty=""
#        local git_color='\[\e[32m\]'
#        if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
#            git_color='\[\e[31m\]'
#	    git_dirty="*"
#        fi
#        git_part=" ${git_color}[${git_branch}${git_dirty}]\[\e[0m\]"
#    fi

#    if [[ -n "$git_branch" ]]; then
#        local git_dirty=""
#        local git_ahead=""
#        local git_color='\[\e[32m\]'   # clean, synced
#
#        if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
#            git_color='\[\e[31m\]'     # dirty working tree
#            git_dirty="*"
#        fi
#
#        local ahead_count
#        ahead_count=$(git rev-list --count '@{u}..HEAD' 2>/dev/null)
#        if [[ "$ahead_count" =~ ^[0-9]+$ ]] && (( ahead_count > 0 )); then
#            git_ahead="↑${ahead_count}"
#            if [[ -z "$git_dirty" ]]; then
#                git_color='\[\e[33m\]' # committed, not pushed
#            fi
#        fi
#
#        git_part=" ${git_color}[${git_branch}${git_dirty}${git_ahead}]\[\e[0m\]"
#    fi

    local git_part=""
    local git_branch git_status_out
    git_status_out=$(git status --porcelain=v1 --branch 2>/dev/null)
    if [[ -n "$git_status_out" ]]; then
        local header dirty_files=""
        header=${git_status_out%%$'\n'*}
        if [[ "$git_status_out" == *$'\n'* ]]; then
            dirty_files=${git_status_out#*$'\n'}
        fi

        local git_dirty=""
        local git_ahead=""
        local git_color='\[\e[32m\]'   # clean, synced

        # Branch name from header: "## main...origin/main" or detached: "## HEAD (no branch)"
        if [[ "$header" == "## HEAD (no branch)"* ]]; then
            git_branch=$(git rev-parse --short HEAD 2>/dev/null)
        else
            git_branch=${header#\#\# }
            git_branch=${git_branch%%...*}
        fi

        if [[ -n "$dirty_files" ]]; then
            git_color='\[\e[31m\]'     # dirty working tree
            git_dirty="*"
        fi

        if [[ "$header" =~ \[ahead\ ([0-9]+) ]]; then
            git_ahead="↑${BASH_REMATCH[1]}"
            if [[ -z "$git_dirty" ]]; then
                git_color='\[\e[33m\]' # committed, not pushed
            fi
        fi

        if [[ "$header" == *'[gone]'* ]]; then
            git_ahead="✗?"                       # upstream is gone
            if [[ -z "$git_dirty" ]]; then
                git_color='\[\e[35m\]'           # magenta: no upstream to push to
            fi
        fi

        if [[ -n "$git_branch" ]]; then
            git_part=" ${git_color}[${git_branch}${git_dirty}${git_ahead}]\[\e[0m\]"
        fi
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

    PS1="${status_part}${user_color}\u\[\e[0m\]@\[\e[34m\]\h\[\e[0m\]:\[\e[33m\]\w\[\e[0m\]${git_part}${shlvl_part}${jobs_part}❯ "
}
PROMPT_COMMAND=__build_ps1

