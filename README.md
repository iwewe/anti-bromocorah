[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](#)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%20|%2022.04%20|%2024.04-E95420)](#)
[![Nginx](https://img.shields.io/badge/Nginx-Lua-blue)](#)
[![OpenResty](https://img.shields.io/badge/OpenResty-supported-4A9EA3)](#)
[![Bilingual](https://img.shields.io/badge/Docs-ID%20%7C%20EN-5A67D8)](#)
[![CI](https://img.shields.io/badge/GitHub%20Actions-ready-informational)](#)


# Anti Bromocorah — Nginx/OpenResty Lua Anti‑DDoS (Ubuntu)

> Perlindungan sederhana namun efektif untuk website **NGO/LSM**, **gerakan masyarakat sipil**, dan **pemerintah daerah**.  
> Anti Bromocorah menghadirkan lapisan Anti‑DDoS berbasis **Lua** untuk **Nginx/OpenResty**, dengan tantangan JavaScript singkat sebelum akses.
> Proyek ini adalah _fork_ dari solusi Anti‑DDoS Lua untuk Nginx (MIT); kredit upstream tetap dijaga sesuai lisensi, sambil memusatkan fokus pada pengalaman **Ubuntu Server**.

---

## ✨ Fitur Utama
- **Mode fleksibel**: proteksi **global (server‑wide)** atau **per‑lokasi** (`/api`, `/login`, dll.).
- **Target server tertentu**: pilih **server block** via `--server-name`.
- **Multi‑lokasi sekali jalan**: `--locations /a,/b,/c`.
- **Tuning performa**: `--shared-dict-size 70m|128m|256m`.
- **Aman untuk CI/CD**: `--dry-run` (pratinjau) & `--no-reload`.
- **Rollback bersih**: uninstaller paham **marker** & backup `.bak`.
- **Kompatibel**: Nginx (Debian/Ubuntu) & OpenResty.

### Lapisan perlindungan (contoh)
- Pembatasan request / mitigasi **IP flooding**.  
- Whitelist/Blacklist: **IP**, **subnet**, **User‑Agent**.  
- Pemeriksaan **header/URL/POST/cookie** (gaya WAF) terhadap pola berbahaya.  
- Filter **Range header** (mitigasi **slowloris/slowhttp**).  
- **Minify/kompresi** untuk efisiensi bandwidth.

---

## 🧩 Kebutuhan Sistem
- Ubuntu **20.04 / 22.04 / 24.04**  
- **Nginx + Lua** (`libnginx-mod-http-lua` / `nginx-extras`) **atau** **OpenResty**

---

## 🚀 Instalasi Cepat (Ubuntu)
Ekstrak rilis, masuk ke foldernya, lalu:

### A) Nginx Debian/Ubuntu — mode global
```bash
sudo apt update
sudo apt install -y nginx libnginx-mod-http-lua
sudo ./install_bilingual.sh --scope global
```

### B) Nginx — per‑lokasi (multi path)
```bash
sudo ./install_bilingual.sh --scope location --locations /api,/login,/admin
```

### C) OpenResty (opsional auto‑install)
```bash
sudo ./install_bilingual.sh --install-openresty --scope global
# atau
sudo ./install_bilingual.sh --install-openresty --scope location --locations /api
```

> Skrip otomatis **uji konfigurasi** (`nginx -t` / `openresty -t`) dan **reload** service (bisa dinonaktifkan dengan `--no-reload`).

---

## ⚙️ Opsi Penting
- `--scope global | location`  
- `--locations /a,/b,/c` (per‑lokasi, multi sekaligus)  
- `--server-name example.org` (pilih server block target)  
- `--shared-dict-size 256m` (atur ukuran `lua_shared_dict`)  
- `--site-file /etc/nginx/sites-available/myapp` (Debian/Ubuntu)  
- `--openresty-conf /etc/openresty/nginx.conf` (OpenResty)  
- `--dry-run`, `--no-reload`

---

## ♻️ Uninstall / Rollback
```bash
# Restore .bak (jika ada) + hapus injeksi bermarker
sudo ./uninstall_bilingual.sh

# Hanya buang injeksi (tanpa restore .bak)
sudo ./uninstall_bilingual.sh --no-restore

# Bersih total file terpasang
sudo ./uninstall_bilingual.sh --purge

# Hapus hanya lokasi tertentu
sudo ./uninstall_bilingual.sh --locations /api,/login
```

---

## 🔒 Catatan Keamanan
- Terapkan **layered defense**: rate‑limit/WAF, firewall (UFW), validasi aplikasi.
- Gunakan **staging + `--dry-run`** untuk audit perubahan.
- Pantau log layanan:
```bash
sudo tail -f /var/log/nginx/access.log /var/log/nginx/error.log
```

---


---

## 🚧 Fitur & Keunggulan Perlindungan
### 🛡️ Advanced DDoS Attack Protection
Anti Bromocorah membantu **meredam DDoS tanpa batasan kuota** agar performa dan ketersediaan tetap terjaga. Serangan kini makin canggih—lebih terdistribusi, volumenya besar, dan menyasar **lapisan aplikasi (L7)**. Serangan sukses bukan hanya menambah biaya infrastruktur & tim IT, tetapi juga merusak kepercayaan pengguna. Karena itu, solusi harus **tangguh, skalabel, dan cerdas**.

**Contoh tipe serangan umum (L7)**  
- **HTTP Flood** (GET/POST) dari banyak sumber → membuat layanan melambat/tidak tersedia.  
- Pola trafik anomali yang meniru pengguna manusia.  

### 🤖 Blokir Bot Jahat
Cegah bot penyalahguna: **content scraping**, **fraudulent checkout**, hingga **account takeover**.

### 🔐 Lindungi Data Pengguna
Kurangi risiko pencurian kredensial, kartu, dan informasi pribadi yang sensitif.

### 🧱 Layered Security Defense
Pendekatan **berlapis** menggabungkan beberapa teknik mitigasi: **menahan trafik buruk** sekaligus **meloloskan trafik baik**, sehingga situs, aplikasi, dan API tetap **available** dan **ngebut**.

### 🌊 HTTP Flood (Layer 7)
Mitigasi lonjakan **HTTP/GET/POST** berskala besar yang menargetkan aplikasi. Tujuan: **tetap responsif** bahkan saat beban puncak.

### 🧠 Kecerdasan Kolektif (Shared Intelligence)
Semakin banyak yang mengadopsi dan berkontribusi, semakin kuat pola deteksi—**membantu mengidentifikasi ancaman baru** di seluruh jaringan pengguna.

### ⚡ Tanpa Mengorbankan Performa
Integrasi langsung di server kamu → **minim latensi tambahan**. Tidak wajib bergantung pada layanan pihak ketiga; kamu memegang kendali penuh.

### 🔒 Web Application Firewall (WAF)
Pemeriksaan terhadap **SQLi, XSS, CSRF**, header/URL/POST/cookie, serta **User‑Agent**. Mendukung **whitelist/blacklist** IP & subnet (IPv4/IPv6).

### 🚦 Rate Limiting
Atur ambang batas (threshold), respons, dan insight per‑URL/endpoint. Efektif untuk **DoS**, **brute‑force login**, dan **penyalahgunaan** lain—sekaligus menekan biaya bandwidth akibat lonjakan trafik yang tak diinginkan.

## 📝 Lisensi & Atribusi
- Lisensi **MIT**.  
- Proyek ini adalah fork dari solusi Anti‑DDoS berbasis Lua untuk Nginx; atribusi upstream dipertahankan sesuai lisensi, dengan fokus penerapan di **Ubuntu Server**.

---

## 📦 Isi Rilis (ringkas)
```
anti_ddos_challenge.lua        # Skrip Lua inti
anti_ddos.conf                 # Snippet Nginx (mode global)
install_bilingual.sh           # Installer bilingual (ID/EN)
uninstall_bilingual.sh         # Uninstaller/rollback bilingual
README.md / README.en.md       # Dokumentasi
```
