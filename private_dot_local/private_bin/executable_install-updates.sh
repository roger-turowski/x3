#!/usr/bin/env bash
# install-updates.sh

logpath="${XDG_STATE_HOME}/install-updates"
logfile="${logpath}/install-updates.log"

if [[ ! -d "${logpath}" ]]; then mkdir -p "${logpath}"; fi

source /etc/os-release

case "$ID" in
    opensuse-tumbleweed)
	time sudo zypper ref | tee -a "${logfile}" && \
	time sudo zypper --non-interactive dup --auto-agree-with-licenses --allow-vendor-change | tee -a "${logfile}"
	;;
    arch)
	time  pacman -Syu | tee -a "${logfile}"
	;;
    *)
	echo "OS not implemented yet!"
	;;
esac
