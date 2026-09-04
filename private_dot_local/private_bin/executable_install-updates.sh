#!/usr/bin/env bash
# install-updates.sh

logpath="${XDG_STATE_HOME}/install-updates"
logfile="${logpath}/install-updates.log"

if [[ ! -d "${logpath}" ]]; then mkdir -p "${logpath}"; fi

source /etc/os-release

case "$ID" in
    opensuse-tumbleweed)
	time sudo zypper ref 2>&1 | tee -a "${logfile}" && \
	time sudo zypper --non-interactive dup --auto-agree-with-licenses --allow-vendor-change 2>&1 | tee -a "${logfile}"
	;;
    arch)
	time sudo pacman -Syu --noconfirm 2>&1 | tee -a "${logfile}"
	;;
    *)
	echo "OS not implemented yet: ${ID}" 2>&1 | tee -a "${logfile}" 
	;;
esac
