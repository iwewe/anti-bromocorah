\
#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info(){ echo -e "${GREEN}[INFO]${NC} $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }
err(){  echo -e "${RED}[ERR] ${NC} $*"; exit 1; }

# Defaults
INSTALL_OPENRESTY=0
SCOPE="global"             # global | location
LOCATIONS=()               # multiple: /api,/login
SERVER_NAME=""             # target specific server_name block
SHARED_DICT_SIZE="70m"
DRY_RUN=0
NO_RELOAD=0
SITE_FILE="/etc/nginx/sites-available/default"        # Debian/Ubuntu default site
ORESTY_CONF="/usr/local/openresty/nginx/conf/nginx.conf"

usage(){
  cat <<EOF
Usage: $0 [flags]

  --install-openresty         Install OpenResty if not present
  --scope global|location     Scope of protection (default: global)
  --locations /a,/b,...       Comma-separated paths for per-location mode (default: /)
  --server-name NAME          Target server block by server_name (both Debian & OpenResty)
  --shared-dict-size SIZE     Size for lua_shared_dict (default: 70m)
  --site-file PATH            Debian/Ubuntu site file (default: /etc/nginx/sites-available/default)
  --openresty-conf PATH       OpenResty nginx.conf path (default: /usr/local/openresty/nginx/conf/nginx.conf)
  --dry-run                   Show changes but do not modify files
  --no-reload                 Do not reload services after changes
  -h, --help                  Show this help

Examples:
  # Global protection to server_name example.org
  $0 --scope global --server-name example.org

  # Protect multiple locations at once
  $0 --scope location --locations /api,/login

  # Tune shared dict size
  $0 --shared-dict-size 256m --scope global
EOF
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-openresty) INSTALL_OPENRESTY=1 ; shift ;;
    --scope)
      [[ $# -ge 2 ]] || { usage; err "--scope requires a value"; }
      case "$2" in global) SCOPE="global" ;; location|per-location) SCOPE="location" ;; *) usage; err "Invalid scope: $2" ;; esac
      shift 2 ;;
    --locations)
      [[ $# -ge 2 ]] || { usage; err "--locations requires a value"; }
      IFS=',' read -r -a LOCATIONS <<< "$2"
      shift 2 ;;
    --server-name) [[ $# -ge 2 ]] || { usage; err "--server-name requires a value"; } SERVER_NAME="$2"; shift 2 ;;
    --shared-dict-size) [[ $# -ge 2 ]] || { usage; err "--shared-dict-size requires a value"; } SHARED_DICT_SIZE="$2"; shift 2 ;;
    --site-file) [[ $# -ge 2 ]] || { usage; err "--site-file requires a value"; } SITE_FILE="$2"; shift 2 ;;
    --openresty-conf) [[ $# -ge 2 ]] || { usage; err "--openresty-conf requires a value"; } ORESTY_CONF="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1 ; shift ;;
    --no-reload) NO_RELOAD=1 ; shift ;;
    -h|--help) usage; exit 0 ;;
    *) warn "Unknown arg: $1"; shift ;;
  esac
done

# Defaults
if [[ "${#LOCATIONS[@]}" -eq 0 ]]; then LOCATIONS=("/"); fi

# Pre-reqs
info "Installing prerequisites..."
sudo apt-get update -y
sudo apt-get install -y ca-certificates lsb-release sed coreutils awk

# Place files
info "Placing Lua script and snippet..."
sudo install -d -m 0755 /usr/share/nginx/anti_ddos
sudo install -m 0644 anti_ddos_challenge.lua /usr/share/nginx/anti_ddos/anti_ddos_challenge.lua
sudo install -d -m 0755 /etc/nginx/snippets
# Also rewrite snippet shared dict size to user-provided value
sed "s/lua_shared_dict jspuzzle_tracker .*;/lua_shared_dict jspuzzle_tracker ${SHARED_DICT_SIZE}; # anti-ddos: injected (GLOBAL)/" anti_ddos.conf | sudo tee /etc/nginx/snippets/anti_ddos.conf >/dev/null

# Detect services
NGINX_SVC=""; OPENRESTY_SVC=""
if systemctl list-unit-files | grep -q '^nginx\.service'; then NGINX_SVC="nginx"; fi
if systemctl list-unit-files | grep -q '^openresty\.service'; then OPENRESTY_SVC="openresty"; fi

# Optionally install OpenResty
if [[ $INSTALL_OPENRESTY -eq 1 && -z "$OPENRESTY_SVC" ]]; then
  info "Installing OpenResty from official repo..."
  sudo apt-get install -y wget gnupg
  wget -O - https://openresty.org/package/pubkey.gpg | sudo gpg --dearmor -o /usr/share/keyrings/openresty.gpg
  echo "deb [signed-by=/usr/share/keyrings/openresty.gpg] http://openresty.org/package/ubuntu $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/openresty.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y openresty
  OPENRESTY_SVC="openresty"
fi

apply_file(){
  local NEW="$1" DST="$2"
  if [[ $DRY_RUN -eq 1 ]]; then
    info "[DRY-RUN] Would update $DST"
    return 0
  fi
  sudo mv "$NEW" "$DST"
}

reload_svc(){
  local test_cmd="$1"; shift
  local svc="$1"; shift
  [[ $NO_RELOAD -eq 1 ]] && { warn "Skipping reload (--no-reload)"; return 0; }
  bash -lc "$test_cmd" && sudo systemctl reload "$svc"
}

# =============== Debian/Ubuntu Nginx injection =================

find_debian_server_block(){
  # echo start_line end_line for server block (1st match) that contains server_name $SERVER_NAME
  # If SERVER_NAME empty, return first server block.
  local file="$1"
  awk -v name="$SERVER_NAME" '
    BEGIN{ level=0; inhttp=0; server_start=0; found=0; hasname=0 }
    /http[[:space:]]*\{/ && !inhttp {inhttp=1; level=1; next}
    {
      # track braces
      n_open=gsub(/\{/,"{");
      n_close=gsub(/\}/,"}");
      level += (n_open - n_close);

      if ($0 ~ /server[[:space:]]*\{/ && level>=1 && server_start==0) {
        server_start=NR;
        hasname=0;
      }
      if (server_start>0 && $0 ~ /server_name[[:space:]]+/) {
        if (name=="" || $0 ~ name) { hasname=1 }
      }
      if (server_start>0 && $0 ~ /\}/ && level>=1) {
        # potential end of server block (best-effort)
        if (hasname || name=="") {
          print server_start, NR;
          found=1; exit
        } else {
          server_start=0; hasname=0;
        }
      }
    }
    END{ if(!found && name==""){ print 0,0 } }
  ' "$file"
}

inject_debian_global(){
  local file="$SITE_FILE"
  [[ -f "$file" ]] || { warn "No $file; skip Debian injection"; return 0; }
  sudo cp -n "$file" "${file}.bak"

  # ensure include line inside targeted server block
  local start=0 end=0; read start end < <(find_debian_server_block "$file")
  if [[ "${start:-0}" -eq 0 ]]; then
    warn "No server block matching --server-name found; using first server block"
    # fallback to first occurrence of 'server {'
    start=$(awk '/server[[:space:]]*\{/{print NR; exit}' "$file"); end=0
  fi
  if [[ -z "$start" || "$start" -eq 0 ]]; then
    err "Could not locate any server block in $file"
  fi

  # if include exists, skip
  if awk 'BEGIN{s=ENVIRON["start"]; e=ENVIRON["end"]} NR>=s && (e==0 || NR<=e) && /include[[:space:]]+snippets\/anti_ddos\.conf;/{found=1} END{exit found?0:1}' start="$start" end="$end" "$file"; then
    info "GLOBAL snippet already present in target server block"
    return 0
  fi

  # insert include line after the 'server {' line
  awk -v s="$start" -v e="$end" '
    NR==s { print; print "    include snippets/anti_ddos.conf; # anti-ddos: injected (GLOBAL)"; next }
    { print }
  ' "$file" | sudo tee "${file}.new" >/dev/null
  apply_file "${file}.new" "$file"
  reload_svc "nginx -t" "nginx"
}

inject_debian_locations(){
  local file="$SITE_FILE"
  [[ -f "$file" ]] || { warn "No $file; skip Debian injection"; return 0; }
  sudo cp -n "$file" "${file}.bak"

  # Remove global include in that server block if present (prevent double hook)
  sed -i '/include[[:space:]]\+snippets\/anti_ddos\.conf;.*anti-ddos: injected (GLOBAL)/d' "$file" || true

  local start=0 end=0; read start end < <(find_debian_server_block "$file")
  if [[ -z "$start" || "$start" -eq 0 ]]; then err "Could not locate server block (try --server-name or correct --site-file)"; fi

  # For each location, add a block with markers if not exists
  tmp="${file}.new"; cp "$file" "$tmp"
  for loc in "${LOCATIONS[@]}"; do
    loc="${loc#/}" ; loc="/${loc}" # ensure leading slash
    info "Injecting location ${loc}"
    awk -v s="$start" -v e="$end" -v L="$loc" '
      BEGIN{printed=0}
      NR==s {
        print;
        print "    # anti-ddos: begin location " L;
        print "    location " L " {";
        print "        access_by_lua_file /usr/share/nginx/anti_ddos/anti_ddos_challenge.lua; # anti-ddos";
        print "    }";
        print "    # anti-ddos: end location " L;
        next
      }
      { print }
    ' "$tmp" > "${tmp}.2"
    mv "${tmp}.2" "$tmp"
    # update start/end since file lines changed
    read start end < <(find_debian_server_block "$tmp")
  done

  apply_file "$tmp" "$file"
  reload_svc "nginx -t" "nginx"
}

# =============== OpenResty injection =================

inject_openresty_common_http(){
  local conf="$ORESTY_CONF"
  [[ -f "$conf" ]] || { warn "No $conf; skip OpenResty injection"; return 1; }
  sudo cp -n "$conf" "${conf}.bak"
  # Ensure shared dict with requested size exists once (replace or insert)
  if grep -q 'lua_shared_dict[[:space:]]\+jspuzzle_tracker' "$conf"; then
    sudo sed -i "s/lua_shared_dict[[:space:]]\+jspuzzle_tracker[[:space:]]\+[0-9a-zA-Z]\+;/lua_shared_dict jspuzzle_tracker ${SHARED_DICT_SIZE}; # anti-ddos/" "$conf" || true
  else
    awk '
      /http[[:space:]]*\{/ && !added_http { print; print "    lua_shared_dict jspuzzle_tracker SIZE_PLACEHOLDER; # anti-ddos"; added_http=1; next }
      { print }
    ' "$conf" | sed "s/SIZE_PLACEHOLDER/${SHARED_DICT_SIZE}/" | sudo tee "${conf}.new" >/dev/null
    apply_file "${conf}.new" "$conf"
  fi
  return 0
}

find_openresty_server_block(){
  # print start end of server block within http{} matching server_name (first if empty)
  local conf="$ORESTY_CONF"
  awk -v name="$SERVER_NAME" '
    BEGIN{level=0; inhttp=0; server_start=0; found=0; hasname=0}
    /http[[:space:]]*\{/ && !inhttp {inhttp=1; level=1; next}
    {
      n_open=gsub(/\{/,"{"); n_close=gsub(/\}/,"}"); level += (n_open-n_close);
      if ($0 ~ /server[[:space:]]*\{/ && inhttp && server_start==0) { server_start=NR; hasname=0 }
      if (server_start>0 && $0 ~ /server_name[[:space:]]+/) { if (name=="" || $0 ~ name) hasname=1 }
      if (server_start>0 && $0 ~ /\}/ && inhttp) {
        if (hasname || name=="") { print server_start, NR; found=1; exit } else { server_start=0; hasname=0 }
      }
    }
    END{ if(!found && name==""){ print 0,0 } }
  ' "$conf"
}

inject_openresty_global(){
  local conf="$ORESTY_CONF"
  inject_openresty_common_http || return 0
  local start=0 end=0; read start end < <(find_openresty_server_block)
  if [[ -z "$start" || "$start" -eq 0 ]]; then err "Could not find server block in $conf"; fi
  # add access_by_lua_file in target server
  awk -v s="$start" -v e="$end" '
    NR==s { print; print "        access_by_lua_file /usr/share/nginx/anti_ddos/anti_ddos_challenge.lua; # anti-ddos: injected (GLOBAL)"; next }
    { print }
  ' "$conf" | sudo tee "${conf}.new" >/dev/null
  apply_file "${conf}.new" "$conf"
  reload_svc "openresty -t" "openresty"
}

inject_openresty_locations(){
  local conf="$ORESTY_CONF"
  inject_openresty_common_http || return 0
  local start=0 end=0; read start end < <(find_openresty_server_block)
  if [[ -z "$start" || "$start" -eq 0 ]]; then err "Could not find target server block (use --server-name?)"; fi

  tmp="${conf}.new"; cp "$conf" "$tmp"
  for loc in "${LOCATIONS[@]}"; do
    loc="${loc#/}"; loc="/${loc}"
    info "Injecting location ${loc} into OpenResty server block"
    awk -v s="$start" -v e="$end" -v L="$loc" '
      NR==s {
        print; 
        print "        # anti-ddos: begin location " L;
        print "        location " L " {";
        print "            access_by_lua_file /usr/share/nginx/anti_ddos/anti_ddos_challenge.lua; # anti-ddos";
        print "        }";
        print "        # anti-ddos: end location " L;
        next
      }
      { print }
    ' "$tmp" > "${tmp}.2"
    mv "${tmp}.2" "$tmp"
    read start end < <(find_openresty_server_block)
  done

  apply_file "$tmp" "$conf"
  reload_svc "openresty -t" "openresty"
}

# Dispatch
if [[ -n "$NGINX_SVC" ]]; then
  info "Detected Debian/Ubuntu Nginx"
  if [[ "$SCOPE" == "global" ]]; then
    inject_debian_global
  else
    inject_debian_locations
  fi
fi
if [[ -n "$OPENRESTY_SVC" ]]; then
  info "Detected OpenResty"
  if [[ "$SCOPE" == "global" ]]; then
    inject_openresty_global
  else
    inject_openresty_locations
  fi
fi
if [[ -z "$NGINX_SVC" && -z "$OPENRESTY_SVC" ]]; then
  warn "No nginx/openresty unit detected. Attempting Debian-style file injection only."
  if [[ "$SCOPE" == "global" ]]; then inject_debian_global || true; else inject_debian_locations || true; fi
  warn "Reload skipped or may fail; check your environment."
fi

info "Done."
