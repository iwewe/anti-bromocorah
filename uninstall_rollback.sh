\
#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info(){ echo -e "${GREEN}[INFO]${NC} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }
err(){  echo -e "${RED}[ERR] ${NC} $*"; exit 1; }

PURGE=0
RESTORE_BACKUP=1
SCOPE="auto"
LOCATIONS=()
SERVER_NAME=""
SITE_FILE="/etc/nginx/sites-available/default"
ORESTY_CONF="/usr/local/openresty/nginx/conf/nginx.conf"
NO_RELOAD=0

usage(){
  cat <<EOF
Usage: $0 [--purge] [--no-restore] [--scope auto|global|location] [--locations /a,/b] [--server-name NAME] [--site-file PATH] [--openresty-conf PATH] [--no-reload]

Examples:
  $0 --scope global
  $0 --scope location --locations /api,/login
  $0 --purge
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --purge) PURGE=1 ; shift ;;
    --no-restore) RESTORE_BACKUP=0 ; shift ;;
    --scope) [[ $# -ge 2 ]] || { usage; err "--scope requires a value"; }
            case "$2" in auto|global|location) SCOPE="$2" ;; *) usage; err "Invalid scope: $2" ;; esac
            shift 2 ;;
    --locations) [[ $# -ge 2 ]] || { usage; err "--locations requires a value"; } IFS=',' read -r -a LOCATIONS <<< "$2"; shift 2 ;;
    --server-name) [[ $# -ge 2 ]] || { usage; err "--server-name requires a value"; } SERVER_NAME="$2"; shift 2 ;;
    --site-file) [[ $# -ge 2 ]] || { usage; err "--site-file requires a value"; } SITE_FILE="$2"; shift 2 ;;
    --openresty-conf) [[ $# -ge 2 ]] || { usage; err "--openresty-conf requires a value"; } ORESTY_CONF="$2"; shift 2 ;;
    --no-reload) NO_RELOAD=1 ; shift ;;
    -h|--help) usage; exit 0 ;;
    *) warn "Unknown arg: $1"; shift ;;
  esac
done

reload_svc(){
  local test_cmd="$1"; shift
  local svc="$1"; shift
  [[ $NO_RELOAD -eq 1 ]] && { warn "Skipping reload (--no-reload)"; return 0; }
  bash -lc "$test_cmd" && sudo systemctl reload "$svc"
}

remove_marked_locations(){
  local file="$1"
  local tmp="${file}.new"
  cp "$file" "$tmp"
  if [[ "${#LOCATIONS[@]}" -eq 0 ]]; then
    # remove all anti-ddos marked location blocks
    awk '
      BEGIN{block=0}
      /# anti-ddos: begin location / { block=1; next }
      block==1 { if ($0 ~ /# anti-ddos: end location /) { block=0; next } else { next } }
      { print }
    ' "$tmp" > "${tmp}.2"
    mv "${tmp}.2" "$tmp"
  else
    for loc in "${LOCATIONS[@]}"; do
      loc="${loc#/}"; loc="/${loc}"
      awk -v L="$loc" '
        BEGIN{block=0}
        $0 ~ ("# anti-ddos: begin location " L) { block=1; next }
        block==1 { if ($0 ~ ("# anti-ddos: end location " L)) { block=0; next } else { next } }
        { print }
      ' "$tmp" > "${tmp}.2"
      mv "${tmp}.2" "$tmp"
    done
  fi
  mv "$tmp" "$file"
}

rollback_debian(){
  local file="$SITE_FILE"
  [[ -f "$file" ]] || { warn "No $file found; skip"; return 0; }
  if [[ $RESTORE_BACKUP -eq 1 && -f "${file}.bak" ]]; then
    info "Restoring backup ${file}.bak"
    sudo cp -f "${file}.bak" "$file"
  else
    # remove global include marker line
    sudo sed -i '/include[[:space:]]\+snippets\/anti_ddos\.conf;.*anti-ddos: injected (GLOBAL)/d' "$file"
    # remove marked locations
    remove_marked_locations "$file"
  fi
  reload_svc "nginx -t" "nginx" || true
}

rollback_openresty(){
  local conf="$ORESTY_CONF"
  [[ -f "$conf" ]] || { warn "No $conf found; skip"; return 0; }
  if [[ $RESTORE_BACKUP -eq 1 && -f "${conf}.bak" ]]; then
    info "Restoring backup ${conf}.bak"
    sudo cp -f "${conf}.bak" "$conf"
  else
    # remove global marker line
    sudo sed -i '\#access_by_lua_file /usr/share/nginx/anti_ddos/anti_ddos_challenge.lua; # anti-ddos: injected (GLOBAL)#d' "$conf"
    # remove marked locations
    remove_marked_locations "$conf"
    # keep shared dict line; harmless even if left
  fi
  reload_svc "openresty -t" "openresty" || true
}

rollback_debian
rollback_openresty

if [[ $PURGE -eq 1 ]]; then
  info "Purging installed files"
  sudo rm -f /etc/nginx/snippets/anti_ddos.conf || true
  sudo rm -f /usr/share/nginx/anti_ddos/anti_ddos_challenge.lua || true
  rmdir /usr/share/nginx/anti_ddos 2>/dev/null || true
fi

info "Uninstall/Rollback complete."
