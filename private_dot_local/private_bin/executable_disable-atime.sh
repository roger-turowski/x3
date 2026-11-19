#!/usr/bin/env bash


sed -i '\~[[:blank:]]/home[[:blank:]]~ s~relatime~noatime~; \~[[:blank:]]/data[[:blank:]]~ s~relatime~noatime~' /etc/fstab || \
    echo "Failed to update fstab with xfs noatime parameters"
