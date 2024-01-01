# auto-script
Some original scripts for automation that are simple and "it works".


## Network

### Allow Cloudflare IPs for nftables

[allow-cf.sh](network/allow-cf.sh) is a script that allows Cloudflare IPs for nftables.

Execution argument:
- `-b` - Base Path (default: `$HOME/auto-script`)
- `-T` - Table Name (default: `inet filter`)
- `-C` - Chain Name (default: `input_cloudflare`)
- `-p` - Accept Port (default: `80,443,8080,8443`, accept: `80,443,2052,2082,2083,2086,2087,2095,2096,8080,8443`)
- `-u` - Uninstall script
- `-J` - Use Cloudflare (JD Cloud, China Network) IPs, not Cloudflare IPs

#### Use:

1. Download script
```bash
curl -sL https://raw.githubusercontent.com/Yuiinars/auto-script/main/network/allow-cf.sh > allow-cf.sh

chmod +x allow-cf.sh
```

2. Execute script
- `./allow-cf.sh` - Install script
- `./allow-cf.sh -u` - Uninstall script
- `./allow-cf.sh -p 80` - Install script and accept port 80