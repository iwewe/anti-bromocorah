# Nginx-Lua-Anti-DDoS — Ubuntu/Debian Port

This package installs the Lua challenge script and an Nginx snippet so you can enable protection quickly.

## Requirements

- Ubuntu 20.04/22.04/24.04 (Debian-based)
- Nginx with Lua support **either**:
  - `libnginx-mod-http-lua` (recommended on Ubuntu), or
  - `nginx-extras`, or
  - OpenResty (provides built-in Lua)

## Quick Start (no packaging)

If you don't want a `.deb`, you can install manually:

```bash
sudo apt update
sudo apt install -y nginx libnginx-mod-http-lua
sudo install -d -o root -g root -m 0755 /usr/share/nginx/anti_ddos
sudo install -o root -g root -m 0644 anti_ddos_challenge.lua /usr/share/nginx/anti_ddos/
sudo install -D -o root -g root -m 0644 anti_ddos.conf /etc/nginx/snippets/anti_ddos.conf

# Include the snippet in your server block, e.g. /etc/nginx/sites-available/default
# inside the 'server { ... }' add:
#   include snippets/anti_ddos.conf;

sudo nginx -t && sudo systemctl reload nginx
```

## Build as .deb

```bash
sudo apt update
sudo apt install -y build-essential devscripts debhelper
dpkg-buildpackage -us -uc -b
# This will produce ../nginx-lua-anti-ddos-challenge_1.0-1_all.deb
sudo apt install -y ../nginx-lua-anti-ddos-challenge_1.0-1_all.deb
```

## Uninstall

```bash
sudo apt remove nginx-lua-anti-ddos-challenge
```

## Notes

- The Lua script path is `/usr/share/nginx/anti_ddos/anti_ddos_challenge.lua`.
- The snippet file is `/etc/nginx/snippets/anti_ddos.conf` and uses `access_by_lua_file` to hook protection.
- Adjust `lua_shared_dict` size depending on traffic.
