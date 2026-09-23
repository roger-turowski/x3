#!/usr/bin/env bash

# Remove ncurses5 symlinks if they cause problems

run_ldconfig=false

if [ -L /usr/lib/libncurses.so.5 ]; then
    echo "Removing symlink: libncurses.so.5"
    sudo rm /usr/lib/libncurses.so.5
    run_ldconfig=true
else
    echo "libncurses.so.5 not present"
fi

if [ -L /usr/lib/libtinfo.so.5 ]; then
    echo "Removing symlink: libtinfo.so.5"
    sudo rm /usr/lib/libtinfo.so.5
    run_ldconfig=true
else
    echo "libtinfo.so.5 not present"
fi

if [[ $run_ldconfig == true ]]; then
    echo "Updating link cache"
    sudo ldconfig
fi
