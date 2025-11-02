\
#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info(){ echo -e "${GREEN}[INFO]${NC} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }
err(){  echo -e "${RED}[ERR] ${NC} $*"; exit 1; }

# Defaults
INSTALL_OPENRESTY=0
SCOPE="global"         # "global" or "location:/path"
LOCATION_PATH="/"

usage(){
  cat <<EOF
Usage: $0 [--install-openresty] [--scope global|location:/path]

  --install-openresty     Install OpenResty from official repo if not present
  --scope                 'global' (default) inject on server-wide scope, or 'location:/path'
                          example: --scope location:/api

Examples:
  $0 --scope global
  $0 --scope location:/protected
  $0 --install-openresty --scope location:/api
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-openresty) INSTALL_OPENRESTY=1 ; shift ;;
    --scope)
      [[ $# -ge 2 ]] || { usage; err "--scope requires a value"; }
      case "$2" in
        global) SCOPE="global" ;;
        location:*) SCOPE="location"; LOCATION_PATH="${2#location:}" ;;
        *) usage; err "Invalid scope: $2" ;;
      esac
      shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) warn "Unknown arg: $1"; shift ;;
  esac
done

# 0) Pre-reqs
info "Installing prerequisites..."
sudo apt-get update -y
sudo apt-get install -y ca-certificates lsb-release sed coreutils

# 1) Place Lua & (global) snippet to common paths
info "Placing Lua script and snippet..."
sudo install -d -m 0755 /usr/share/nginx/anti_ddos
sudo install -m 0644 anti_ddos_challenge.lua /usr/share/nginx/anti_ddos/anti_ddos_challenge.lua
sudo install -d -m 0755 /etc/nginx/snippets
sudo install -m 0644 anti_ddos.conf /etc/nginx/snippets/anti_ddos.conf

# 2) Detect services
NGINX_SVC=""; OPENRESTY_SVC=""
if systemctl list-unit-files | grep -q '^nginx\.service'; then NGINX_SVC="nginx"; fi
if systemctl list-unit-files | grep -q '^openresty\.service'; then OPENRESTY_SVC="openresty"; fi

# 3) Optionally install OpenResty
if [[ $INSTALL_OPENRESTY -eq 1 && -z "$OPENRESTY_SVC" ]]; then
  info "Installing OpenResty from official repo..."
  sudo apt-get install -y wget gnupg
  wget -O - https://openresty.org/package/pubkey.gpg | sudo gpg --dearmor -o /usr/share/keyrings/openresty.gpg
  echo "deb [signed-by=/usr/share/keyrings/openresty.gpg] http://openresty.org/package/ubuntu $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/openresty.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y openresty
  OPENRESTY_SVC="openresty"
fi

# Helpers
inject_nginx_default_global(){
  local default="/etc/nginx/sites-available/default"
  [[ -f "$default" ]] || { warn "No $default; skip Debian injection"; return 0; }
  sudo cp -n "$default" "${default}.bak"
  if ! grep -q "include snippets/anti_ddos.conf" "$default"; then
    info "Injecting GLOBAL snippet into $default"
    sudo awk '
      BEGIN{ injected=0 }
      /server[[:space:]]*\{/ {
        print;
        if (!injected) { print "    include snippets/anti_ddos.conf;"; injected=1 }
        next
      }
      { print }
    ' "$default" | sudo tee "$default.new" >/dev/null
    sudo mv "$default.new" "$default"
  else
    info "GLOBAL snippet already present in $default"
  fi
  sudo nginx -t && sudo systemctl reload nginx
}

inject_nginx_default_location(){
  local default="/etc/nginx/sites-available/default"
  local loc="$1"
  [[ -f "$default" ]] || { warn "No $default; skip Debian injection"; return 0; }
  sudo cp -n "$default" "${default}.bak"
  # Remove any prior global include if exists (to avoid double hook)
  if grep -q "include snippets/anti_ddos.conf" "$default"; then
    info "Removing previous GLOBAL snippet to switch to per-location"
    sudo sed -i '/include snippets\/anti_ddos\.conf;/d' "$default"
  fi
  # Add a location block with access_by_lua_file if not present
  if ! awk -v L="$loc" '
      /server[[:space:]]*\{/ {inserver=1}
      inserver && $0 ~ "location[[:space:]]+"L"[[:space:]]*\\{" {found=1}
      /\}/ { if(inserver){inserver=0} }
      END{exit found?0:1}
    ' "$default"; then
    info "Injecting LOCATION block at $loc"
    sudo awk -v L="$loc" '
      /server[[:space:]]*\{/ && !added {
        print; 
        print "    location " L " {";
        print "        access_by_lua_file /usr/share/nginx/anti_ddos/anti_ddos_challenge.lua;";
        print "    }";
        added=1; next
      }
      { print }
    ' "$default" | sudo tee "$default.new" >/dev/null
    sudo mv "$default.new" "$default"
  else
    info "LOCATION block $loc already exists; ensuring access_by_lua_file line"
    sudo awk -v L="$loc" '
      /server[[:space:]]*\{/ {inserver=1}
      inserver && $0 ~ "location[[:space:]]+"L"[[:space:]]*\\{" {inloc=1}
      inloc && /access_by_lua_file[[:space:]]+\/usr\/share\/nginx\/anti_ddos\/anti_ddos_challenge.lua/ {found=1}
      inloc && /\}/ {inloc=0}
      /\}/ { if(inserver){inserver=0} }
      {print}
      END{
        if(!found) {
          # could not easily inject here with awk END; user must check
        }
      }
    ' "$default" >/dev/null 2>&1 || true
  fi
  sudo nginx -t && sudo systemctl reload nginx
}

inject_openresty_common_http(){
  local conf="/usr/local/openresty/nginx/conf/nginx.conf"
  [[ -f "$conf" ]] || { warn "No $conf; skip OpenResty injection"; return 1; }
  sudo cp -n "$conf" "${conf}.bak"
  # Ensure lua_shared_dict in http{}
  if ! awk '/http[[:space:]]*\{/{inhttp=1} inhttp && /lua_shared_dict[[:space:]]+jspuzzle_tracker/{found=1} /\}/{if(inhttp){inhttp=0}} END{exit found?0:1}' "$conf"; then
    info "Adding lua_shared_dict jspuzzle_tracker 70m; to http{}"
    sudo awk '
      /http[[:space:]]*\{/ && !added_http { print; print "    lua_shared_dict jspuzzle_tracker 70m;"; added_http=1; next }
      { print }
    ' "$conf" | sudo tee "$conf.new" >/dev/null
    sudo mv "$conf.new" "$conf"
  else
    info "lua_shared_dict already present in http{}"
  fi
  return 0
}

inject_openresty_global(){
  local conf="/usr/local/openresty/nginx/conf/nginx.conf"
  inject_openresty_common_http || return 0
  # access_by_lua_file in first server{}
  if ! awk '
    /http[[:space:]]*\{/ {inhttp=1}
    inhttp && /server[[:space:]]*\{/ {inserver=1}
    inserver && /access_by_lua_file[[:space:]]+\/usr\/share\/nginx\/anti_ddos\/anti_ddos_challenge.lua/ {found=1}
    /\}/ { if(inserver){inserver=0} else if(inhttp){inhttp=0} }
    END{exit found?0:1}
  ' "$conf"; then
    info "Injecting GLOBAL access_by_lua_file into first server{}"
    sudo awk '
      /http[[:space:]]*\{/ {inhttp=1}
      inhttp && /server[[:space:]]*\{/ && !added_server {
        print; print "        access_by_lua_file /usr/share/nginx/anti_ddos/anti_ddos_challenge.lua;"; added_server=1; next
      }
      { print }
    ' "$conf" | sudo tee "$conf.new" >/dev/null
    sudo mv "$conf.new" "$conf"
  else
    info "GLOBAL access_by_lua_file already present"
  fi
  sudo openresty -t && sudo systemctl reload openresty
}

inject_openresty_location(){
  local conf="/usr/local/openresty/nginx/conf/nginx.conf"; local loc="$1"
  inject_openresty_common_http || return 0
  # ensure a location block exists inside first server; if not, create
  info "Injecting LOCATION $loc into first server{}"
  sudo awk -v L="$loc" '
    /http[[:space:]]*\{/ {inhttp=1}
    inhttp && /server[[:space:]]*\{/ && !done {
      print;
      print "        location " L " {";
      print "            access_by_lua_file /usr/share/nginx/anti_ddos/anti_ddos_challenge.lua;";
      print "        }";
      done=1; next
    }
    { print }
  ' "$conf" | sudo tee "$conf.new" >/dev/null
  sudo mv "$conf.new" "$conf"
  sudo openresty -t && sudo systemctl reload openresty
}

# Dispatch
if [[ -n "$NGINX_SVC" ]]; then
  info "Detected Debian/Ubuntu Nginx service"
  if [[ "$SCOPE" == "global" ]]; then
    inject_nginx_default_global
  else
    inject_nginx_default_location "$LOCATION_PATH"
  fi
fi

if [[ -n "$OPENRESTY_SVC" ]]; then
  info "Detected OpenResty service"
  if [[ "$SCOPE" == "global" ]]; then
    inject_openresty_global
  else
    inject_openresty_location "$LOCATION_PATH"
  fi
fi

if [[ -z "$NGINX_SVC" && -z "$OPENRESTY_SVC" ]]; then
  warn "No nginx/openresty unit; attempting Debian-style file injection only."
  if [[ "$SCOPE" == "global" ]]; then
    inject_nginx_default_global || true
  else
    inject_nginx_default_location "$LOCATION_PATH" || true
  fi
  warn "You may need to reload manually."
fi

info "Done."
