\
#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

info(){ echo -e "${GREEN}[INFO]${NC} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }
err(){  echo -e "${RED}[ERR] ${NC} $*"; exit 1; }

INSTALL_OPENRESTY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-openresty) INSTALL_OPENRESTY=1 ; shift ;;
    *) warn "Unknown arg: $1"; shift ;;
  esac
done

# 0) Pre-reqs
info "Installing prerequisites..."
sudo apt-get update -y
sudo apt-get install -y ca-certificates lsb-release sed coreutils

# 1) Place Lua & snippet to common paths
info "Placing Lua script and snippet..."
sudo install -d -m 0755 /usr/share/nginx/anti_ddos
sudo install -m 0644 anti_ddos_challenge.lua /usr/share/nginx/anti_ddos/anti_ddos_challenge.lua
sudo install -d -m 0755 /etc/nginx/snippets
sudo install -m 0644 anti_ddos.conf /etc/nginx/snippets/anti_ddos.conf

# 2) Detect services
NGINX_SVC=""
if systemctl list-unit-files | grep -q '^nginx\.service'; then
  NGINX_SVC="nginx"
fi
OPENRESTY_SVC=""
if systemctl list-unit-files | grep -q '^openresty\.service'; then
  OPENRESTY_SVC="openresty"
fi

# 3) Optionally install OpenResty if requested and not present
if [[ $INSTALL_OPENRESTY -eq 1 && -z "$OPENRESTY_SVC" ]]; then
  info "Installing OpenResty from official repo..."
  sudo apt-get install -y wget gnupg
  wget -O - https://openresty.org/package/pubkey.gpg | sudo gpg --dearmor -o /usr/share/keyrings/openresty.gpg
  echo "deb [signed-by=/usr/share/keyrings/openresty.gpg] http://openresty.org/package/ubuntu $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/openresty.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y openresty
  OPENRESTY_SVC="openresty"
fi

# 4) Inject for Debian/Ubuntu Nginx (sites-available/default)
inject_nginx_default(){
  local default="/etc/nginx/sites-available/default"
  if [[ ! -f "$default" ]]; then
    warn "Debian nginx default vhost not found at $default ; skipping Debian-style injection"
    return 0
  fi
  sudo cp -n "$default" "${default}.bak"
  if ! grep -q "include snippets/anti_ddos.conf" "$default"; then
    info "Injecting snippet into $default"
    # Insert after first 'server {' occurrence
    sudo awk '
      BEGIN{ injected=0 }
      /server[[:space:]]*\{/ {
        print; 
        if (!injected) { 
          print "    include snippets/anti_ddos.conf;";
          injected=1 
        }
        next
      }
      { print }
    ' "$default" | sudo tee "$default.new" >/dev/null
    sudo mv "$default.new" "$default"
  else
    info "Snippet already present in $default"
  fi
  sudo nginx -t && sudo systemctl reload nginx
  info "Debian nginx injection complete."
}

# 5) Inject for OpenResty (edit /usr/local/openresty/nginx/conf/nginx.conf)
inject_openresty(){
  local conf="/usr/local/openresty/nginx/conf/nginx.conf"
  if [[ ! -f "$conf" ]]; then
    warn "OpenResty nginx.conf not found at $conf ; skipping OpenResty injection"
    return 0
  fi
  sudo cp -n "$conf" "${conf}.bak"

  # Ensure lua_shared_dict in http {}
  if ! awk '/http[[:space:]]*\{/{inhttp=1} inhttp && /lua_shared_dict[[:space:]]+jspuzzle_tracker/{found=1} /\}/{if(inhttp){inhttp=0}} END{exit found?0:1}' "$conf"; then
    info "Adding lua_shared_dict jspuzzle_tracker 70m; to http{} block"
    sudo awk '
      /http[[:space:]]*\{/ && !added_http {
        print; print "    lua_shared_dict jspuzzle_tracker 70m;"; added_http=1; next
      }
      { print }
    ' "$conf" | sudo tee "$conf.new" >/dev/null
    sudo mv "$conf.new" "$conf"
  else
    info "lua_shared_dict already present in http{}"
  fi

  # Ensure access_by_lua_file inside first server {} in http{}
  if ! awk '
    /http[[:space:]]*\{/ {inhttp=1}
    inhttp && /server[[:space:]]*\{/ {inserver=1}
    inserver && /access_by_lua_file[[:space:]]+\/usr\/share\/nginx\/anti_ddos\/anti_ddos_challenge.lua/ {found=1}
    /\}/ { if(inserver){inserver=0} else if(inhttp){inhttp=0} }
    END{exit found?0:1}
  ' "$conf"; then
    info "Injecting access_by_lua_file into first server{}"
    sudo awk '
      /http[[:space:]]*\{/ {inhttp=1}
      inhttp && /server[[:space:]]*\{/ && !added_server {
        print; print "        access_by_lua_file /usr/share/nginx/anti_ddos/anti_ddos_challenge.lua;"; added_server=1; next
      }
      { print }
    ' "$conf" | sudo tee "$conf.new" >/dev/null
    sudo mv "$conf.new" "$conf"
  else
    info "access_by_lua_file already present in a server{}"
  fi

  sudo openresty -t && sudo systemctl reload openresty
  info "OpenResty injection complete."
}

# Execute injections according to detected services
if [[ -n "$NGINX_SVC" ]]; then
  info "Detected Debian/Ubuntu Nginx service"
  inject_nginx_default
fi

if [[ -n "$OPENRESTY_SVC" ]]; then
  info "Detected OpenResty service"
  inject_openresty
fi

# If neither detected, still attempt Debian-style injection (file may exist without service unit)
if [[ -z "$NGINX_SVC" && -z "$OPENRESTY_SVC" ]]; then
  warn "Neither nginx nor openresty systemd units found. Attempting Debian-style file injection only."
  inject_nginx_default || true
  warn "You may need to reload Nginx/OpenResty manually."
fi

info "Done."
