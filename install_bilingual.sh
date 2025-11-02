#!/usr/bin/env bash
# Anti Bromocorah — Installer (Bilingual ID/EN) — MIT
# iwewe@2025
set -euo pipefail
LANG_CHOICE="id"

# i18n helpers
tr_id(){ case "$1" in
  START) echo "[INFO] Memulai instalasi..." ;;
  PREREQ) echo "[INFO] Memasang prasyarat..." ;;
  PLACE) echo "[INFO] Menempatkan skrip Lua & snippet..." ;;
  DETECT) echo "[INFO] Mendeteksi layanan..." ;;
  INSTALL_OR) echo "[INFO] Memasang OpenResty dari repo resmi..." ;;
  DRY) echo "[DRY-RUN] Pratinjau perubahan (tanpa menulis berkas)" ;;
  NGINX_DETECTED) echo "[INFO] Terdeteksi layanan Nginx (Debian/Ubuntu)" ;;
  ORESTY_DETECTED) echo "[INFO] Terdeteksi layanan OpenResty" ;;
  DONE) echo "[INFO] Selesai." ;;
  RELOAD_SKIP) echo "[WARN] Melewati reload (--no-reload)" ;;
  RELOAD_OK) echo "[INFO] Validasi & reload layanan berhasil" ;;
  FILE_MISS) echo "[WARN] Berkas tidak ditemukan, melewati:" ;;
  NO_SERVER) echo "[ERR] Gagal menemukan server block; periksa --server-name/berkas target" ;;
  INJECT_GLOBAL) echo "[INFO] Menyisipkan proteksi GLOBAL (server-wide)" ;;
  INJECT_LOC) echo "[INFO] Menyisipkan proteksi per-LOCATION" ;;
  INJECT_LOC_AT) echo "[INFO] Menyisipkan location:" ;;
  USING_SITE) echo "[INFO] Menggunakan site file:" ;;
  USING_CONF) echo "[INFO] Menggunakan OpenResty conf:" ;;
  USAGE) cat <<'TXT'
Pemakaian:
  ./install_bilingual.sh [opsi]
Opsi:
  --lang id|en                 Bahasa output (default: id)
  --install-openresty          Pasang OpenResty jika belum ada
  --scope global|location      Mode proteksi (default: global)
  --locations /a,/b,/c         Daftar path (untuk mode location), default: /
  --server-name NAMA           Target server block sesuai server_name
  --shared-dict-size 70m       Ukuran lua_shared_dict (default: 70m)
  --site-file PATH             File site Nginx (default: /etc/nginx/sites-available/default)
  --openresty-conf PATH        OpenResty nginx.conf (default: /usr/local/openresty/nginx/conf/nginx.conf)
  --dry-run                    Tampilkan rencana perubahan saja
  --no-reload                  Jangan reload layanan
TXT
  ;; esac; }
tr_en(){ case "$1" in
  START) echo "[INFO] Starting installation..." ;;
  PREREQ) echo "[INFO] Installing prerequisites..." ;;
  PLACE) echo "[INFO] Placing Lua script & snippet..." ;;
  DETECT) echo "[INFO] Detecting services..." ;;
  INSTALL_OR) echo "[INFO] Installing OpenResty from official repo..." ;;
  DRY) echo "[DRY-RUN] Preview only; no files will be modified" ;;
  NGINX_DETECTED) echo "[INFO] Detected Debian/Ubuntu Nginx service" ;;
  ORESTY_DETECTED) echo "[INFO] Detected OpenResty service" ;;
  DONE) echo "[INFO] Done." ;;
  RELOAD_SKIP) echo "[WARN] Skipping reload (--no-reload)" ;;
  RELOAD_OK) echo "[INFO] Config test & service reload successful" ;;
  FILE_MISS) echo "[WARN] File not found, skipping:" ;;
  NO_SERVER) echo "[ERR] Could not locate server block; check --server-name/target file" ;;
  INJECT_GLOBAL) echo "[INFO] Injecting GLOBAL (server-wide) protection" ;;
  INJECT_LOC) echo "[INFO] Injecting per-LOCATION protection" ;;
  INJECT_LOC_AT) echo "[INFO] Injecting location:" ;;
  USING_SITE) echo "[INFO] Using site file:" ;;
  USING_CONF) echo "[INFO] Using OpenResty conf:" ;;
  USAGE) cat <<'TXT'
Usage:
  ./install_bilingual.sh [options]
Options:
  --lang id|en                 Output language (default: id)
  --install-openresty          Install OpenResty if not present
  --scope global|location      Protection mode (default: global)
  --locations /a,/b,/c         Paths for location mode (default: /)
  --server-name NAME           Target server block with that server_name
  --shared-dict-size 70m       lua_shared_dict size (default: 70m)
  --site-file PATH             Debian/Ubuntu Nginx site file (default: /etc/nginx/sites-available/default)
  --openresty-conf PATH        OpenResty nginx.conf (default: /usr/local/openresty/nginx/conf/nginx.conf)
  --dry-run                    Show plan only
  --no-reload                  Do not reload services
TXT
  ;; esac; }
T(){ if [[ "${LANG_CHOICE}" == "en" ]]; then tr_en "$1"; else tr_id "$1"; fi; }

# defaults
INSTALL_OPENRESTY=0; SCOPE="global"; LOCATIONS=("/"); SERVER_NAME=""; SHARED_DICT_SIZE="70m"
DRY_RUN=0; NO_RELOAD=0
SITE_FILE="/etc/nginx/sites-available/default"
ORESTY_CONF="/usr/local/openresty/nginx/conf/nginx.conf"

# parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --lang) LANG_CHOICE="${2:-id}"; shift 2;;
    --install-openresty) INSTALL_OPENRESTY=1; shift;;
    --scope) SCOPE="${2:-global}"; shift 2;;
    --locations) IFS=',' read -r -a LOCATIONS <<< "${2:-/}"; shift 2;;
    --server-name) SERVER_NAME="${2:-}"; shift 2;;
    --shared-dict-size) SHARED_DICT_SIZE="${2:-70m}"; shift 2;;
    --site-file) SITE_FILE="${2:-$SITE_FILE}"; shift 2;;
    --openresty-conf) ORESTY_CONF="${2:-$ORESTY_CONF}"; shift 2;;
    --dry-run) DRY_RUN=1; shift;;
    --no-reload) NO_RELOAD=1; shift;;
    -h|--help) T USAGE; exit 0;;
    *) echo "[WARN] Unknown arg: $1"; shift;;
  esac
done

T START
T PREREQ
sudo apt-get update -y
sudo apt-get install -y ca-certificates lsb-release sed coreutils awk nginx || true

T PLACE
if [[ ! -f "anti_ddos_challenge.lua" || ! -f "anti_ddos.conf" ]]; then
  echo "[ERR] Please run from the release folder containing anti_ddos_challenge.lua and anti_ddos.conf"
  exit 1
fi
sudo install -d -m 0755 /usr/share/nginx/anti_ddos
sudo install -m 0644 anti_ddos_challenge.lua /usr/share/nginx/anti_ddos/anti_ddos_challenge.lua
sudo install -d -m 0755 /etc/nginx/snippets
sed "s/lua_shared_dict jspuzzle_tracker .*;/lua_shared_dict jspuzzle_tracker ${SHARED_DICT_SIZE}; # anti-ddos (GLOBAL)/" anti_ddos.conf | sudo tee /etc/nginx/snippets/anti_ddos.conf >/dev/null

T DETECT
NGINX_SVC=""; OPENRESTY_SVC=""
systemctl list-unit-files | grep -q '^nginx\.service' && NGINX_SVC="nginx" || true
systemctl list-unit-files | grep -q '^openresty\.service' && OPENRESTY_SVC="openresty" || true

if [[ $INSTALL_OPENRESTY -eq 1 && -z "$OPENRESTY_SVC" ]]; then
  T INSTALL_OR
  sudo apt-get install -y wget gnupg
  wget -O - https://openresty.org/package/pubkey.gpg | sudo gpg --dearmor -o /usr/share/keyrings/openresty.gpg
  echo "deb [signed-by=/usr/share/keyrings/openresty.gpg] http://openresty.org/package/ubuntu $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/openresty.list >/dev/null
  sudo apt-get update -y && sudo apt-get install -y openresty
  OPENRESTY_SVC="openresty"
fi

apply_file(){ local NEW="$1" DST="$2"; if [[ $DRY_RUN -eq 1 ]]; then T DRY; echo "  -> $DST"; return 0; fi; sudo mv "$NEW" "$DST"; }
reload_svc(){ local test_cmd="$1" svc="$2"; if [[ $NO_RELOAD -eq 1 ]]; then T RELOAD_SKIP; return 0; fi; if bash -lc "$test_cmd"; then sudo systemctl reload "$svc"; T RELOAD_OK; else echo "[ERR] Config test failed: $test_cmd"; exit 1; fi; }

# helpers to find server blocks
find_debian_server_block(){ local file="$1"; awk -v name="$SERVER_NAME" '
  BEGIN{level=0; ss=0; found=0; hasname=0}
  {n_open=gsub(/\{/,"{"); n_close=gsub(/\}/,"}"); level+=(n_open-n_close);
   if ($0 ~ /server[[:space:]]*\{/ && ss==0){ss=NR; hasname=0}
   if (ss>0 && $0 ~ /server_name[[:space:]]+/){ if (name=="" || $0 ~ name) hasname=1 }
   if (ss>0 && $0 ~ /\}/){ if (hasname || name==""){ print ss, NR; exit } else { ss=0; hasname=0 } } }' "$file"; }
find_openresty_server_block(){ local conf="$ORESTY_CONF"; awk -v name="$SERVER_NAME" '
  BEGIN{level=0; inhttp=0; ss=0; hasname=0}
  /http[[:space:]]*\{/ && !inhttp {inhttp=1; next}
  {n_open=gsub(/\{/,"{"); n_close=gsub(/\}/,"}"); level+=(n_open-n_close);
   if ($0 ~ /server[[:space:]]*\{/ && inhttp && ss==0){ss=NR; hasname=0}
   if (ss>0 && $0 ~ /server_name[[:space:]]+/){ if (name=="" || $0 ~ name) hasname=1 }
   if (ss>0 && $0 ~ /\}/ && inhttp){ if (hasname || name==""){ print ss, NR; exit } else { ss=0; hasname=0 } } }' "$conf"; }

# Debian/Ubuntu injections
inject_debian_global(){
  local file="$SITE_FILE"; [[ -f "$file" ]] || { T FILE_MISS; echo "$file"; return 0; }
  T USING_SITE; echo "$file"; sudo cp -n "$file" "${file}.bak"; T INJECT_GLOBAL
  local start=0 end=0; read start end < <(find_debian_server_block "$file")
  if [[ -z "$start" || "$start" -eq 0 ]]; then start=$(awk '/server[[:space:]]*\{/{print NR; exit}' "$file"); [[ -z "$start" || "$start" -eq 0 ]] && { T NO_SERVER; exit 1; }; fi
  awk -v s="$start" 'NR==s{print; print "    include snippets/anti_ddos.conf; # anti-ddos (GLOBAL)"; next} {print}' "$file" | sudo tee "${file}.new" >/dev/null
  apply_file "${file}.new" "$file"; reload_svc "nginx -t" "nginx"
}
inject_debian_locations(){
  local file="$SITE_FILE"; [[ -f "$file" ]] || { T FILE_MISS; echo "$file"; return 0; }
  T USING_SITE; echo "$file"; sudo cp -n "$file" "${file}.bak"; T INJECT_LOC
  sudo sed -i '/include[[:space:]]\+snippets\/anti_ddos\.conf;.*anti-ddos/d' "$file" || true
  local start=0 end=0; read start end < <(find_debian_server_block "$file"); [[ -z "$start" || "$start" -eq 0 ]] && { T NO_SERVER; exit 1; }
  local tmp="${file}.new"; cp "$file" "$tmp"
  for loc in "${LOCATIONS[@]}"; do [[ -z "$loc" ]] && continue; [[ "$loc" != /* ]] && loc="/$loc"; T INJECT_LOC_AT; echo "$loc"
    awk -v s="$start" -v L="$loc" 'NR==s{print; print "    # anti-ddos: begin location " L; print "    location " L " {"; print "        access_by_lua_file /usr/share/nginx/anti_ddos/anti_ddos_challenge.lua; # anti-ddos"; print "    }"; print "    # anti-ddos: end location " L; next } {print}' "$tmp" | sudo tee "${tmp}.2" >/dev/null
    mv "${tmp}.2" "$tmp"; read start end < <(find_debian_server_block "$tmp")
  done
  apply_file "$tmp" "$file"; reload_svc "nginx -t" "nginx"
}

# OpenResty injections
ensure_openresty_http_shared_dict(){
  local conf="$ORESTY_CONF"; [[ -f "$conf" ]] || { T FILE_MISS; echo "$conf"; return 1; }
  T USING_CONF; echo "$conf"; sudo cp -n "$conf" "${conf}.bak"
  if grep -q 'lua_shared_dict[[:space:]]\+jspuzzle_tracker' "$conf"; then
    sudo sed -i "s/lua_shared_dict[[:space:]]\+jspuzzle_tracker[[:space:]]\+[0-9a-zA-Z]\+;/lua_shared_dict jspuzzle_tracker ${SHARED_DICT_SIZE}; # anti-ddos/" "$conf" || true
  else
    awk '/http[[:space:]]*\{/ && !added{print; print "    lua_shared_dict jspuzzle_tracker SIZEX; # anti-ddos"; added=1; next} {print}' "$conf" | sed "s/SIZEX/${SHARED_DICT_SIZE}/" | sudo tee "${conf}.new" >/dev/null
    apply_file "${conf}.new" "$conf"
  fi
  return 0
}
inject_openresty_global(){
  local conf="$ORESTY_CONF"; ensure_openresty_http_shared_dict || return 0; T INJECT_GLOBAL
  local start=0 end=0; read start end < <(find_openresty_server_block); [[ -z "$start" || "$start" -eq 0 ]] && { T NO_SERVER; exit 1; }
  awk -v s="$start" 'NR==s{print; print "        access_by_lua_file /usr/share/nginx/anti_ddos/anti_ddos_challenge.lua; # anti-ddos (GLOBAL)"; next} {print}' "$conf" | sudo tee "${conf}.new" >/dev/null
  apply_file "${conf}.new" "$conf"; reload_svc "openresty -t" "openresty"
}
inject_openresty_locations(){
  local conf="$ORESTY_CONF"; ensure_openresty_http_shared_dict || return 0; T INJECT_LOC
  local start=0 end=0; read start end < <(find_openresty_server_block); [[ -z "$start" || "$start" -eq 0 ]] && { T NO_SERVER; exit 1; }
  local tmp="${conf}.new"; cp "$conf" "$tmp"
  for loc in "${LOCATIONS[@]}"; do [[ -z "$loc" ]] && continue; [[ "$loc" != /* ]] && loc="/$loc"; T INJECT_LOC_AT; echo "$loc"
    awk -v s="$start" -v L="$loc" 'NR==s{print; print "        # anti-ddos: begin location " L; print "        location " L " {"; print "            access_by_lua_file /usr/share/nginx/anti_ddos/anti_ddos_challenge.lua; # anti-ddos"; print "        }"; print "        # anti-ddos: end location " L; next } {print}' "$tmp" | sudo tee "${tmp}.2" >/dev/null
    mv "${tmp}.2" "$tmp"; read start end < <(find_openresty_server_block)
  done
  apply_file "$tmp" "$conf"; reload_svc "openresty -t" "openresty"
}

# dispatch
if [[ -n "${NGINX_SVC}" ]]; then T NGINX_DETECTED; [[ "$SCOPE" == "global" ]] && inject_debian_global || inject_debian_locations; fi
if [[ -n "${OPENRESTY_SVC}" ]]; then T ORESTY_DETECTED; [[ "$SCOPE" == "global" ]] && inject_openresty_global || inject_openresty_locations; fi
if [[ -z "${NGINX_SVC}" && -z "${OPENRESTY_SVC}" ]]; then echo "[WARN] No nginx/openresty service detected; attempting Debian-style injection."; [[ "$SCOPE" == "global" ]] && inject_debian_global || inject_debian_locations; echo "[WARN] Reload may need to be manual."; fi
T DONE
