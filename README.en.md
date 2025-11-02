[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](#)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%20|%2022.04%20|%2024.04-E95420)](#)
[![Nginx](https://img.shields.io/badge/Nginx-Lua-blue)](#)
[![OpenResty](https://img.shields.io/badge/OpenResty-supported-4A9EA3)](#)
[![Bilingual](https://img.shields.io/badge/Docs-ID%20%7C%20EN-5A67D8)](#)
[![CI](https://img.shields.io/badge/GitHub%20Actions-ready-informational)](#)


# Anti Bromocorah — Nginx/OpenResty Lua Anti‑DDoS (Ubuntu)

> A straightforward, effective Anti‑DDoS layer for **NGOs**, **civil society**, and **local governments**.  
> Anti Bromocorah adds a Lua‑powered protection to **Nginx/OpenResty** with a brief JavaScript challenge before access.
> This project is a fork of a Lua Anti‑DDoS solution for Nginx (MIT); upstream credit is preserved per license while focusing on **Ubuntu Server** usability.

---

## ✨ Highlights
- **Flexible modes**: **global (server‑wide)** or **per‑location** (`/api`, `/login`, etc.).
- **Target specific server blocks** via `--server-name`.
- **Multiple locations at once**: `--locations /a,/b,/c`.
- **Performance tuning**: `--shared-dict-size 70m|128m|256m`.
- **CI/CD friendly**: `--dry-run` (preview) & `--no-reload`.
- **Clean rollback**: uninstaller with **markers** & `.bak` backups.
- **Compatible** with Debian/Ubuntu Nginx and OpenResty.

### Defense layers (examples)
- Request limiting / **IP flooding** mitigation.  
- Whitelists/Blacklists for **IP**, **subnets**, **User‑Agent**.  
- **Header/URL/POST/cookie** inspection (WAF‑style) for malicious patterns.  
- **Range header** filtering (mitigates **slowloris/slowhttp**).  
- **Minify/compress** responses to save bandwidth.

---

## 🧩 Requirements
- Ubuntu **20.04 / 22.04 / 24.04**  
- **Nginx + Lua** (`libnginx-mod-http-lua` / `nginx-extras`) **or** **OpenResty**

---

## 🚀 Quick Start (Ubuntu)
Extract the release, enter the folder, then:

### A) Debian/Ubuntu Nginx — global mode
```bash
sudo apt update
sudo apt install -y nginx libnginx-mod-http-lua
sudo ./install_bilingual.sh --scope global
```

### B) Nginx — per‑location (multi paths)
```bash
sudo ./install_bilingual.sh --scope location --locations /api,/login,/admin
```

### C) OpenResty (optional auto‑install)
```bash
sudo ./install_bilingual.sh --install-openresty --scope global
# or
sudo ./install_bilingual.sh --install-openresty --scope location --locations /api
```

> The script automatically **validates config** (`nginx -t` / `openresty -t`) and **reloads** services (can be disabled with `--no-reload`).

---

## ⚙️ Key Flags
- `--scope global | location`  
- `--locations /a,/b,/c` (per‑location, multiple at once)  
- `--server-name example.org` (choose the target server block)  
- `--shared-dict-size 256m` (set `lua_shared_dict` size)  
- `--site-file /etc/nginx/sites-available/myapp` (Debian/Ubuntu)  
- `--openresty-conf /etc/openresty/nginx.conf` (OpenResty)  
- `--dry-run`, `--no-reload`

---

## ♻️ Uninstall / Rollback
```bash
# Restore .bak (if present) + remove marked injections
sudo ./uninstall_bilingual.sh

# Remove injections only (no .bak restore)
sudo ./uninstall_bilingual.sh --no-restore

# Full cleanup of installed files
sudo ./uninstall_bilingual.sh --purge

# Remove selected locations only
sudo ./uninstall_bilingual.sh --locations /api,/login
```

---

## 🔒 Security Notes
- Apply **layered defense**: rate‑limit/WAF, firewall (UFW), app‑level checks.
- Use **staging + `--dry-run`** to audit changes.
- Monitor logs:
```bash
sudo tail -f /var/log/nginx/access.log /var/log/nginx/error.log
```

---


---

## 🚧 Features & Protection Highlights
### 🛡️ Advanced DDoS Attack Protection
Anti Bromocorah provides **unmetered‑style DDoS mitigation** to keep performance and uptime steady. Modern attacks are **distributed, high‑volume, and application‑layer (L7)**. A successful hit raises infrastructure & staffing costs and erodes user trust. The answer: a solution that is **resilient, scalable, and intelligent**.

**Common L7 patterns**  
- **HTTP Floods** (GET/POST) from many sources → degrade or take down apps.  
- Anomalous traffic that mimics real users.  

### 🤖 Block Malicious Bots
Stop abusive automation: **content scraping**, **fraudulent checkout**, and **account takeovers**.

### 🔐 Prevent Data Breach
Reduce risk around stolen credentials, cards, and other personally identifiable information.

### 🧱 Layered Security Defense
A **layered** approach combines multiple mitigation techniques: **hold back bad traffic** while **letting good traffic through**, keeping sites, apps, and APIs **available** and **fast**.

### 🌊 HTTP Flood (Layer 7)
Handle large waves of **HTTP/GET/POST** targeting the app layer so the services remain **responsive** even under pressure.

### 🧠 Shared / Collective Intelligence
The more adopters and contributors, the stronger the patterns—**helping identify emerging threats** across the community.

### ⚡ No Performance Trade‑offs
Runs close to your stack, adding **minimal latency**. No hard dependency on third‑party CDNs; you stay in control.

### 🔒 Web Application Firewall (WAF)
Inspection against **SQLi, XSS, CSRF**, plus header/URL/POST/cookie analysis and **User‑Agent** controls. Supports IP & subnet (IPv4/IPv6) **whitelists/blacklists**.

### 🚦 Rate Limiting
Set thresholds, responses, and per‑URL insights. Effective against **DoS**, **brute‑force logins**, and other abuse—while helping cut bandwidth costs from unpredictable spikes.

## 📝 License & Credit
- **MIT** license.  
- This fork preserves upstream credit per license while focusing on **Ubuntu Server** deployment.

---

## 📦 Release Contents (brief)
```
anti_ddos_challenge.lua        # Core Lua script
anti_ddos.conf                 # Nginx snippet (global mode)
install_bilingual.sh           # Bilingual installer (ID/EN)
uninstall_bilingual.sh         # Bilingual uninstaller/rollback
README.md / README.en.md       # Documentation
```
