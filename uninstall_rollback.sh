\
#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info(){ echo -e "${GREEN}[INFO]${NC} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }
err(){  echo -e "${RED}[ERR] ${NC} $*"; exit 1; }

PURGE=0
RESTORE_BACKUP=1  # prefer restore .bak if available
SCOPE="auto"      # auto = remove both global and per-location traces
LOCATION_PATH="/"

usage(){
  cat <<EOF
Usage: $0 [--purge] [--no-restore] [--scope global|location:/path|auto]

  --purge         Also remove installed files (Lua and snippet)
  --no-restore    Do not restore *.bak files; only remove inserted lines
  --scope         Removal scope: 'auto' (default), 'global', or 'location:/path'

Examples:
  $0
  $0 --purge
  $0 --scope location:/api
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --purge) PURGE=1 ; shift ;;
    --no-restore) RESTORE_BACKUP=0 ; shift ;;
    --scope)
      [[ $# -ge 2 ]] || { usage; err "--scope requires a value"; }
      case "$2" in
        auto) SCOPE="auto" ;;
        global) SCOPE="global" ;;
        location:*) SCOPE="location"; LOCATION_PATH="${2#location:}" ;;
        *) usage; err "Invalid scope: $2" ;;
      esac
      shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) warn "Unknown arg: $1"; shift ;;
  esac
done

rollback_nginx_default(){
  local default="/etc/nginx/sites-available/default"
  [[ -f "$default" ]] || { warn "No $default found; skip"; return 0; }
  if [[ $RESTORE_BACKUP -eq 1 && -f "${default}.bak" ]]; then
    info "Restoring backup ${default}.bak"
    sudo cp -f "${default}.bak" "$default"
  else
    info "Removing injected lines from $default"
    sudo sed -i '/include snippets\\/anti_ddos\\.conf;/d' "$default"
    if [[ "$SCOPE" == "location" || "$SCOPE" == "auto" ]]; then
      # Remove any location block we created containing access_by_lua_file
      sudo awk '
        BEGIN{skip=0}
        /location[[:space:]]+[^ ]+[[:space:]]*{/ && locstart==0 {
          block=1; buf=$0; next
        }
        block==1 {
          buf=buf"\n"$0
          if ($0 ~ /}/) {
            # close of location
            if (buf ~ /access_by_lua_file[[:space:]]+\/usr\/share\/nginx\/anti_ddos\/anti_ddos_challenge.lua/) {
              # skip printing this block
              block=0; buf=""; next
            } else {
              print buf; block=0; buf=""; next
            }
          }
          next
        }
        { print }
      ' "$default" | sudo tee "$default.new" >/dev/null && sudo mv "$default.new" "$default"
    fi
  fi
  sudo nginx -t && sudo systemctl reload nginx || true
}

rollback_openresty(){
  local conf="/usr/local/openresty/nginx/conf/nginx.conf"
  [[ -f "$conf" ]] || { warn "No $conf found; skip"; return 0; }
  if [[ $RESTORE_BACKUP -eq 1 && -f "${conf}.bak" ]]; then
    info "Restoring backup ${conf}.bak"
    sudo cp -f "${conf}.bak" "$conf"
  else
    info "Removing injected lines from $conf"
    # Remove global access_by_lua_file
    if [[ "$SCOPE" == "global" || "$SCOPE" == "auto" ]]; then
      sudo sed -i '\#access_by_lua_file /usr/share/nginx/anti_ddos/anti_ddos_challenge.lua;#d' "$conf"
    fi
    # Remove location blocks with our access_by_lua_file
    if [[ "$SCOPE" == "location" || "$SCOPE" == "auto" ]]; then
      sudo awk '
        /location[[:space:]]+[^ ]+[[:space:]]*{/ && locstart==0 {
          block=1; buf=$0; next
        }
        block==1 {
          buf=buf"\n"$0
          if ($0 ~ /}/) {
            if (buf ~ /access_by_lua_file[[:space:]]+\/usr\/share\/nginx\/anti_ddos\/anti_ddos_challenge.lua/) {
              block=0; buf=""; next
            } else {
              print buf; block=0; buf=""; next
            }
          }
          next
        }
        { print }
      ' "$conf" | sudo tee "$conf.new" >/dev/null && sudo mv "$conf.new" "$conf"
    fi
    # Optionally remove lua_shared_dict (we leave it; harmless)
  fi
  sudo openresty -t && sudo systemctl reload openresty || true
}

rollback_nginx_default
rollback_openresty

if [[ $PURGE -eq 1 ]]; then
  info "Purging installed files"
  sudo rm -f /etc/nginx/snippets/anti_ddos.conf || true
  sudo rm -f /usr/share/nginx/anti_ddos/anti_ddos_challenge.lua || true
  rmdir /usr/share/nginx/anti_ddos 2>/dev/null || true
fi

info "Uninstall/Rollback complete."
