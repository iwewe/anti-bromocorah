# Anti Bromocorah 2025.11.02-032305Z

A Lua-based Anti-DDoS layer for Nginx/OpenResty on Ubuntu. Brief JS challenge, flexible global/per-location modes,
bilingual installer/uninstaller, and clean rollback. 

## Highlights
- Global or per-location injection
- Target server block via `--server-name`
- Multiple locations with `--locations /a,/b,/c`
- `--dry-run`, `--no-reload`, and adjustable `--shared-dict-size`
- Works with Nginx (Debian/Ubuntu) and OpenResty
- README in Bahasa Indonesia and English

## Files in this release
- `install_bilingual.sh` — Installer
- `uninstall_bilingual.sh` — Uninstaller / rollback
- `anti_ddos_challenge.lua` — Core Lua script
- `anti_ddos.conf` — Nginx snippet for global mode
- `README.md` / `README.en.md`
- `debian/` — Packaging skeleton (optional)
- `VERSION`

## Quick Start
```bash
tar -xzf nginx-lua-anti-ddos-ubuntu-release.tar.gz
cd nginx-lua-anti-ddos-ubuntu-release
sudo ./install_bilingual.sh --scope global --server-name example.org
# or per-location
sudo ./install_bilingual.sh --scope location --locations /api,/login
```

## Debian package (optional)
```bash
sudo apt-get update && sudo apt-get install -y build-essential debhelper devscripts
dpkg-buildpackage -us -uc -b
# .deb will be created one level above this folder
```

## Checksums
SHA256 will be shown on the Assets item in the GitHub Release (also shared in chat).
