#!/bin/bash

# [Cloudflare IP Ranges Updater for nftables]
# Copyright (C) 2024 Yuiinars
# Repo: https://github.com/Yuiinars/auto-script

API_URL="https://api.cloudflare.com/client/v4/ips"
BASE_PATH="$HOME/auto-script"   # please change this to your own path
NFT_TABLE="inet filter"
NFT_CHAIN="input_cloudflare"
ALLOWED_PORT=("80" "443" "8080" "8443")

Error() { printf "\033[37;41;1;3m%s\033[0m\n"    "[Error]:    $1  "; }
Info() { printf "\033[37;44;1m%s\033[0m\n"       "[Info]:     $1  "; }
Success() { printf "\033[37;42;1m%s\033[0m\n"    "[Success]:  $1  "; }
Warning() { printf "\033[37;43;1;3m%s\033[0m\n"  "[Warning]:  $1  "; }
Notice() { printf "\033[37;40;1m%s\033[0m\n"     "[Notice]:   $1  "; }

# output copyright
Notice "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
Notice "┃ [Cloudflare IP Ranges Updater for nftables] ┃"
Notice "┃         Copyright (c) 2024 Yuiinars         ┃"
Notice "┃          Apache-2.0 License (SPDX)          ┃"
Notice "┃   https://github.com/Yuiinars/auto-script   ┃"
Notice "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"

if [ "$EUID" -ne 0 ]; then
    Error "Error: Please run this script as root."
    exit 1
fi

is_valid_directory() {
    if [ ! -d "$1" ]; then
        Error "Error: $1 is not a valid directory."
        exit 1
    fi
}
# Parse command line arguments
while getopts "b:T:C:p:u:J" opt; do
  case $opt in
    b)
        if ! is_valid_directory "$OPTARG"; then
            Error "Error: $OPTARG is not a valid directory."
            exit 1
        else
            BASE_PATH="$OPTARG"
            Notice "Cache file path set to:  $BASE_PATH  (from execution argument)"
        fi

        echo > "$BASE_PATH"/.cf-ips-base-path

        Notice "Cache file path set to:  $BASE_PATH  (from execution argument)"
    ;;
    T) NFT_TABLE="$OPTARG"
    Notice "nftables table set to:  $NFT_TABLE  (from execution argument)"
    ;;
    C) NFT_CHAIN="$OPTARG"
    Notice "nftables chain set to:  $NFT_CHAIN  (from execution argument)"
    ;;
    p) 
        IFS=',' read -ra input_ports <<< "$OPTARG"
        for port in "${input_ports[@]}"; do
            if [[ "80,443,2052,2082,2083,2086,2087,2095,2096,8080,8443" =~ $port ]]; then
                ALLOWED_PORT+=("$port")
                Notice "Allowed port: $port"
            else
                Error "Invalid port: $port. Allowed ports are \"80,443,2052,2082,2083,2086,2087,2095,2096,8080,8443\"."
            fi
        done
    ;;
    u)
        UNINSTALL="1"
    ;;
    J)
        Notice "Using JD Cloud IP ranges..."
        API_URL="https://api.cloudflare.com/client/v4/ips?networks=jdcloud"
        JDCLOUD="1"
    ;;
    \?)
        Error "Invalid option -$OPTARG"
    ;;
  esac
done

if [[ $UNINSTALL == "1" ]]; then
    Info "Uninstalling Cloudflare IP Ranges Updater for nftables..."
    if ! nft delete table "$NFT_TABLE" "$NFT_CHAIN" 2>/dev/null; then
        Error "Failed to delete nftables chain."
        exit 1
    fi
    if ! nft delete table "$NFT_TABLE" 2>/dev/null; then
        Error "Failed to delete nftables table."
        exit 1
    fi
    Success "nftables rules rolled back successfully."
    if ! rm -rf "$BASE_PATH/.cf-ips-cache"; then
        Error "Failed to delete cache file."
        exit 1
    fi
    Success "Cache file deleted successfully."
    Notice "Uninstalled successfully, you can delete this script now."
    exit 0
fi

check_command() {
    if [[ ! -x "$(command -v "$1")" ]]; then
        Error "Error: $1 is not installed, please install it and try again."
        exit 1
    fi
}


# check if jq/nft/curl is installed
Info "Checking if jq/nft/curl is installed..."
check_command "jq"
check_command "nft"
check_command "curl"

# check BASE_PATH path is exists
if [ ! -d "$BASE_PATH" ]; then
    Warning "Cache file path does not exist. Creating..."

    Notice "+ mkdir -p $BASE_PATH"
    Notice "+ echo > $BASE_PATH/.cf-ips-cache"
    Notice "+ echo $BASE_PATH > $BASE_PATH/.cf-ips-base-path"

    mkdir -p "$BASE_PATH"
    echo > "$BASE_PATH"/.cf-ips-cache
    echo "$BASE_PATH" > "$BASE_PATH"/.cf-ips-base-path

    Success "Cache file path created successfully."
fi

Notice "[Configuration Information]"
Notice "Base path: $BASE_PATH"
Notice "nftables table: $NFT_TABLE"
Notice "nftables chain: $NFT_CHAIN"
for port in "${ALLOWED_PORT[@]}"; do
    Notice "Allowed port: $port"
done

# pull latest cloudflare ip ranges (using curl and jq)
RESPONSE=$(curl -sL "$API_URL" --header 'Content-Type: application/json')

# check if the response is valids
SUCCESS=$(echo "$RESPONSE" | jq -r '.success')
if [ "$SUCCESS" != "true" ]; then
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.errors[0].message')
    Error "Error: Cloudflare API returned an error: $ERROR_MSG"
    exit 1
else
    REMOTE_ETAG=$(echo "$RESPONSE" | jq -r '.result.etag')
    Success "Cloudflare API is working: [eTag: $REMOTE_ETAG]"
fi

# get local etag from cache file
LOCAL_ETAG=""
if [ -s "$BASE_PATH"/.cf-ips-cache ]; then
    LOCAL_ETAG=$(cat "$BASE_PATH/.cf-ips-cache")
    Success "Local eTag found: $LOCAL_ETAG"
else
    Warning "Local eTag is not found."
fi

# if etags are different, update nftables
if [ "$LOCAL_ETAG" != "$REMOTE_ETAG" ]; then
    Info "Cloudflare IP ranges have changed. Updating nftables..."
    # save new etag to cache file
    echo "$REMOTE_ETAG" > "$BASE_PATH/.cf-ips-cache"

    Info "Deleting old nftables table and chain..."
    # delete old nftables table and chain
    nft delete table "$NFT_TABLE" "$NFT_CHAIN" 2>/dev/null

    # create new nftables table and chain
    Info "Creating new nftables table and chain..."
    nft add table "$NFT_TABLE"
    nft add chain "$NFT_TABLE" "$NFT_CHAIN" '{' type filter hook input priority 0 \; '}'
    Success "nftables table and chain created successfully."

    # if JDCLOUD is set, only add JD Cloud IP ranges
    if [ "$JDCLOUD" = "1" ]; then
        Info "Adding JD Cloud IP ranges to nftables..."
        CIDRS=$(echo "$RESPONSE" | jq -r '.result.jdcloud_cidrs[]')
        for CIDR in $CIDRS; do
            if echo "$CIDR" | grep -q "."; then
                # This is an IPv4 address
                Info "$CIDR adding to $NFT_TABLE..."
                for port in "${ALLOWED_PORT[@]}"; do
                    nft add rule "$NFT_TABLE" "$NFT_CHAIN" ip saddr "$CIDR" tcp dport "$port" accept
                done
                Success "$CIDR added successfully."
            elif echo "$CIDR" | grep -q ":"; then
                # This is an IPv6 address
                Info "$CIDR adding to $NFT_TABLE..."
                for port in "${ALLOWED_PORT[@]}"; do
                    nft add rule "$NFT_TABLE" "$NFT_CHAIN" ip6 saddr "$CIDR" tcp dport "$port" accept
                done
                Success "$CIDR added successfully."
            fi
        done
    else
        # add new cloudflare ip ranges to nftables
        IPV4_CIDRS=$(echo "$RESPONSE" | jq -r '.result.ipv4_cidrs[]')
        for CIDR in $IPV4_CIDRS; do
            Info "$CIDR adding to $NFT_TABLE..."
            for port in "${ALLOWED_PORT[@]}"; do
                nft add rule "$NFT_TABLE" "$NFT_CHAIN" ip saddr "$CIDR" tcp dport "$port" accept
            done
            Success "$CIDR added successfully."
        done

        IPV6_CIDRS=$(echo "$RESPONSE" | jq -r '.result.ipv6_cidrs[]')
        for CIDR in $IPV6_CIDRS; do
            Info "$CIDR adding to $NFT_TABLE..."
            for port in "${ALLOWED_PORT[@]}"; do
                nft add rule "$NFT_TABLE" "$NFT_CHAIN" ip6 saddr "$CIDR" tcp dport "$port" accept
            done
            Success "$CIDR added successfully."
        done
    fi

    # drop all incoming traffic to port 443 except cloudflare
    for port in "${ALLOWED_PORT[@]}"; do
        nft add rule "$NFT_TABLE" "$NFT_CHAIN" tcp dport "$port" drop
    done

    Success "nftables updated successfully."
else
    Success "Cloudflare IP ranges have not changed. No action required."
fi

Success "Done."
exit 0