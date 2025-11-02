#!/usr/bin/env bash
# Anti Bromocorah — Uninstaller/Rollback (Bilingual ID/EN) — MIT
# iwewe@2025
set -euo pipefail
LANG_CHOICE="id"
T(){ case "$1:$LANG_CHOICE" in
  START:id) echo "[INFO] Memulai uninstall/rollback..." ;; START:en) echo "[INFO] Starting uninstall/rollback..." ;;
  MODE:id) echo "[INFO] Mode: hapus injeksi bermarker & restore .bak bila ada" ;; MODE:en) echo "[INFO] Mode: remove marked injections & restore .bak when available" ;;
  PURGE:id) echo "[INFO] Purge: hapus file terpasang" ;; PURGE:en) echo "[INFO] Purge: remove installed files" ;;
  SITE:id) echo "[INFO] File site Nginx:" ;; SITE:en) echo "[INFO] Nginx site file:" ;;
  CONF:id) echo "[INFO] File OpenResty conf:" ;; CONF:en) echo "[INFO] OpenResty conf file:" ;;
  DONE:id) echo "[INFO] Selesai." ;; DONE:en) echo "[INFO] Done." ;;
  USAGE:id) cat <<'TXT'
Pemakaian:
  ./uninstall_bilingual.sh [opsi]
  --lang id|en
  --no-restore                 Jangan restore .bak; hapus injeksi saja
  --purge                      Hapus berkas terpasang
  --site-file PATH             Default: /etc/nginx/sites-available/default
  --openresty-conf PATH        Default: /usr/local/openresty/nginx/conf/nginx.conf
  --locations /a,/b            Hapus hanya lokasi ini (opsional)
TXT
  ;; USAGE:en) cat <<'TXT'
Usage:
  ./uninstall_bilingual.sh [options]
  --lang id|en
  --no-restore                 Do not restore .bak; remove injections only
  --purge                      Remove installed files
  --site-file PATH             Default: /etc/nginx/sites-available/default
  --openresty-conf PATH        Default: /usr/local/openresty/nginx/conf/nginx.conf
  --locations /a,/b            Remove only these locations (optional)
TXT
  ;; esac; }
NO_RESTORE=0; PURGE=0
SITE_FILE="/etc/nginx/sites-available/default"
ORESTY_CONF="/usr/local/openresty/nginx/conf/nginx.conf"
LOCATIONS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --lang) LANG_CHOICE="${2:-id}"; shift 2 ;;
    --no-restore) NO_RESTORE=1; shift ;;
    --purge) PURGE=1; shift ;;
    --site-file) SITE_FILE="${2:-$SITE_FILE}"; shift 2 ;;
    --openresty-conf) ORESTY_CONF="${2:-$ORESTY_CONF}"; shift 2 ;;
    --locations) IFS=',' read -r -a LOCATIONS <<< "${2:-}"; shift 2 ;;
    -h|--help) T USAGE; exit 0 ;;
    *) echo "[WARN] Unknown arg: $1"; shift ;;
  esac
done
T START; T MODE; [[ $PURGE -eq 1 ]] && T PURGE

remove_marked_locations(){
  local file="$1"; local tmp="${file}.new"; cp "$file" "$tmp"
  if [[ "${#LOCATIONS[@]}" -eq 0 ]]; then
    awk 'BEGIN{block=0} /# anti-ddos: begin location /{block=1; next} block==1{ if($0 ~ /# anti-ddos: end location /){block=0; next}else{next}} {print}' "$tmp" > "${tmp}.2"
    mv "${tmp}.2" "$tmp"
  else
    for loc in "${LOCATIONS[@]}"; do [[ "$loc" != /* ]] && loc="/$loc"
      awk -v L="$loc" 'BEGIN{block=0} $0 ~ ("# anti-ddos: begin location " L){block=1; next} block==1{ if($0 ~ ("# anti-ddos: end location " L)){block=0; next}else{next}} {print}' "$tmp" > "${tmp}.2"
      mv "${tmp}.2" "$tmp"
    done
  fi
  mv "$tmp" "$file"
}
rollback_debian(){
  local file="$SITE_FILE"; if [[ ! -f "$file" ]]; then T SITE; echo "$file (MISSING)"; return 0; fi
  T SITE; echo "$file"
  if [[ $NO_RESTORE -eq 0 && -f "${file}.bak" ]]; then cp -f "${file}.bak" "$file"
  else sed -i '/include[[:space:]]\+snippets\/anti_ddos\.conf;.*anti-ddos/d' "$file" || true; remove_marked_locations "$file"; fi
  nginx -t && systemctl reload nginx || true
}
rollback_openresty(){
  local conf="$ORESTY_CONF"; if [[ ! -f "$conf" ]]; then T CONF; echo "$conf (MISSING)"; return 0; fi
  T CONF; echo "$conf"
  if [[ $NO_RESTORE -eq 0 && -f "${conf}.bak" ]]; then cp -f "${conf}.bak" "$conf"
  else sed -i '\#access_by_lua_file /usr/share/nginx/anti_ddos/anti_ddos_challenge.lua; .*anti-ddos#d' "$conf" || true; remove_marked_locations "$conf"; fi
  openresty -t && systemctl reload openresty || true
}
rollback_debian; rollback_openresty
if [[ $PURGE -eq 1 ]]; then rm -f /etc/nginx/snippets/anti_ddos.conf || true; rm -f /usr/share/nginx/anti_ddos/anti_ddos_challenge.lua || true; rmdir /usr/share/nginx/anti_ddos 2>/dev/null || true; fi
T DONE
