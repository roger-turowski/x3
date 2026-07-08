# ============================================================
# eza configuration — tailored for security engineer workflow
# ============================================================

# --- Core aliases ---
alias ls='eza --group-directories-first'
alias ll='eza -l --git --group-directories-first'
alias la='eza -la --git --group-directories-first'
alias lr='eza -lR --git --group-directories-first'  # recursive
alias lh='eza -la --sort=size --reverse --group-directories-first'  # largest at bottom

# --- Tree views ---
alias tree='eza --tree --level=2 --group-directories-first'
alias t3='eza --tree --level=3 --group-directories-first'
alias tgit='eza --tree --level=2 --git --group-directories-first'

# --- Security-oriented views ---
# All files with full perms, owner, group, and git status
alias lsec='eza -laH --git --group-directories-first'
# Sort by modification time (newest first) — useful for incident triage
alias lnew='eza -la --sort=modified --reverse --group-directories-first'
# Sort by access time — spot recently-read files
alias laccess='eza -la --sort=accessed --reverse --group-directories-first'
# Show only files modified in the last X minutes — pipe through find instead
alias lmod='find . -maxdepth 1 -type f -mmin -60 -print0 | xargs -0 eza -l'

# --- Quick permissions audit ---
# Directories writable by group/others — common misconfiguration
alias permcheck='find . -maxdepth 3 -type d \( -perm /g=w -o -perm /o=w \) -exec ls -ld {} +'
# SUID/SGID binaries — standard security sweep
alias suidscan='find / -maxdepth 4 -type f \( -perm /u=s -o -perm /g=s \) 2>/dev/null | eza -l --color=always'

# --- Photography workflow ---
# Sort by size to find raw photos eating disk space
alias lphoto='eza -l --sort=size --reverse *.raw *.cr2 *.arw *.dng *.jpg *.jpeg 2>/dev/null'

# --- Home lab / project browsing ---
alias lproj='eza -l --git --icons --group-directories-first'
alias ldocker='eza -la --sort=modified --reverse --group-directories-first'

# --- Color customization (optional) ---
# Uncomment to override defaults — keys are eza file-type codes, values are ANSI
# export EZA_COLORS="da=1;34:di=1;36:ex=1;32:fi=0;37:pi=33:so=35:bd=1;33:cd=1;33:ur=0;33:uw=0;31:ue=0;31:un=0;31:da=1;34"

# --- Default behavior ---
export EZA_STANDARD_OPTIONS="--group-directories-first"

