#!/usr/bin/env bash

# Create symbolic links for ncurses5 to ncurses6, for compatibility with PassMark Performance Test for Linux

run_ldconfig=false

if [ "$(readlink /usr/lib/libncurses.so.5 2>/dev/null)" != "/usr/lib/libncursesw.so.6" ]; then
    echo "Creating symlink: libncurses.so.5"
    sudo ln -sf /usr/lib/libncursesw.so.6 /usr/lib/libncurses.so.5
    run_ldgonfig=true
else
    echo "libncurses.so.5 already correct"
fi

if [ "$(readlink /usr/lib/libtinfo.so.5 2>/dev/null)" != "/usr/lib/libtinfo.so.6" ]; then
    echo "Creating symlink: libtinfo.so.5"
    sudo ln -sf /usr/lib/libtinfo.so.6 /usr/lib/libtinfo.so.5
    run_ldconfig=true
else
    echo "libtinfo.so.5 already correct"
fi

if [[ $run_ldconfig == true ]]; then
    echo updating link cache
    sudo ldconfig
fi
