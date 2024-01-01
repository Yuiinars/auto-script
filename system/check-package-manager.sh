#!/bin/bash

RESULT_ONLY=$1 # if set to 1, only output the package manager name

Error() { printf "\033[37;41;1;3m%s\033[0m\n"    "[Error]:    $1"; }
Success() { printf "\033[37;42;1m%s\033[0m\n"    "[Success]:  $1"; }
Notice() { printf "\033[37;40;1m%s\033[0m\n"     "[Notice]:   $1"; }

# output copyright
Notice "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
Notice "┃ [Cloudflare IP Ranges Updater for nftables] ┃"
Notice "┃         Copyright (c) 2024 Yuiinars         ┃"
Notice "┃          Apache-2.0 License (SPDX)          ┃"
Notice "┃   https://github.com/Yuiinars/auto-script   ┃"
Notice "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"

OS=$(uname -a)

if echo "$OS" | grep -i "ubuntu\|debian"; then
    MANAGERS=("apt" "apt-get")
elif echo "$OS" | grep -i "centos\|fedora\|rhel"; then
    MANAGERS=("yum" "dnf")
elif echo "$OS" | grep -i "arch"; then
    MANAGERS=("pacman")
elif echo "$OS" | grep -i "gentoo"; then
    MANAGERS=("emerge")
elif echo "$OS" | grep -i "suse"; then
    MANAGERS=("zypper")
elif echo "$OS" | grep -i "alpine"; then
    MANAGERS=("apk")
else
    # fallback
    MANAGERS=("apt" "apt-get" "yum" "dnf" "pacman" "zypper" "emerge" "apk")
fi

# unix-like (macos, freebsd, etc.)
if echo "$OS" | grep -i "darwin\|bsd\|bsd\|freebsd\|openbsd\|netbsd"; then
    MANAGERS=("brew" "port" "pkg")
fi

for manager in "${MANAGERS[@]}"; do
    if command -v "$manager" >/dev/null 2>&1; then
        if [ "$RESULT_ONLY" = "1" ]; then
            echo "$manager"
            exit 0
        else
            Success "Operating System: $OS"
            Success "Package manager found: $manager"
            exit 0
        fi
    fi
done

if [ "$RESULT_ONLY" = "1" ]; then
    echo ""
    exit 1
else
    Error "Operating System: $OS"
    Error "Package manager not found."
    exit 1
fi