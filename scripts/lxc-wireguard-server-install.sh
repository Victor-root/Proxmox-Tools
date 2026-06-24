#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

# ──────────────────────────────────────────────────────────────────────────────
# Installation, configuration et gestion d'un serveur WireGuard
# Thème rouge WireGuard
# ──────────────────────────────────────────────────────────────────────────────

WG_IF="wg0"
WG_DIR="/etc/wireguard"
WG_CONF="${WG_DIR}/${WG_IF}.conf"
CLIENT_DIR="${WG_DIR}/clients"
STATE_FILE="${WG_DIR}/wg-server.env"
NFT_FILE="${WG_DIR}/wg-server.nft"
NFT_UNIT="/etc/systemd/system/wg-server-nft.service"

DEFAULT_PORT="51820"
DEFAULT_WG_CIDR="192.168.2.0/24"
DEFAULT_WG_SERVER_IP="192.168.2.1"
DEFAULT_CLIENT_RANGE_START="100"
DEFAULT_CLIENT_RANGE_END="254"
DEFAULT_KEEPALIVE="25"

APP_NAME="Installation, configuration et gestion du serveur WireGuard"

# ── Couleurs ──────────────────────────────────────────────────────────────────

if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  RED=$'\033[38;5;203m'
  RED_DARK=$'\033[38;5;160m'
  RED_SOFT=$'\033[38;5;211m'
  AMBER=$'\033[38;5;214m'
  GREEN=$'\033[38;5;120m'
  CYAN=$'\033[38;5;117m'
  BLUE=$'\033[38;5;111m'
  GRAY=$'\033[38;5;245m'
  DIM=$'\033[2m'
  BOLD=$'\033[1m'
  RESET=$'\033[0m'
else
  RED=""
  RED_DARK=""
  RED_SOFT=""
  AMBER=""
  GREEN=""
  CYAN=""
  BLUE=""
  GRAY=""
  DIM=""
  BOLD=""
  RESET=""
fi

SPINNER_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")

# ── UI ────────────────────────────────────────────────────────────────────────

term_width() {
  local cols
  cols="$(tput cols 2>/dev/null || echo 80)"
  [[ -z "$cols" || "$cols" -lt 50 ]] && cols=80
  [[ "$cols" -gt 92 ]] && cols=92
  echo "$cols"
}

hr() {
  local cols
  cols="$(term_width)"
  printf "%b" "${RED_DARK}"
  printf "%*s\n" "$cols" "" | tr ' ' '─'
  printf "%b" "${RESET}"
}

success() { printf "%b✓%b %b\n" "${GREEN}" "${RESET}" "$*"; }
info()    { printf "%b›%b %b\n" "${RED_SOFT}" "${RESET}" "$*"; }
warn()    { printf "%b⚠%b %b\n" "${AMBER}" "${RESET}" "$*"; }
error()   { printf "%b✗%b %b\n" "${RED}" "${RESET}" "$*" >&2; }
die()     { error "$*"; exit 1; }

panel() {
  local color="$1"
  local title="$2"
  shift 2

  echo
  printf "%b┌%b %b%b%s%b\n" "$color" "$RESET" "$BOLD" "$color" "$title" "$RESET"
  while (($#)); do
    printf "%b│%b %b\n" "$color" "$RESET" "$1"
    shift
  done
  printf "%b└%b\n" "$color" "$RESET"
}

banner() {
  clear 2>/dev/null || true
  echo
  printf "%b%s%b\n" "${RED}" "██╗    ██╗██╗██████╗ ███████╗ ██████╗ ██╗   ██╗ █████╗ ██████╗ ██████╗" "${RESET}"
  printf "%b%s%b\n" "${RED}" "██║    ██║██║██╔══██╗██╔════╝██╔════╝ ██║   ██║██╔══██╗██╔══██╗██╔══██╗" "${RESET}"
  printf "%b%s%b\n" "${RED}" "██║ █╗ ██║██║██████╔╝█████╗  ██║  ███╗██║   ██║███████║██████╔╝██║  ██║" "${RESET}"
  printf "%b%s%b\n" "${RED}" "██║███╗██║██║██╔══██╗██╔══╝  ██║   ██║██║   ██║██╔══██║██╔══██╗██║  ██║" "${RESET}"
  printf "%b%s%b\n" "${RED}" "╚███╔███╔╝██║██║  ██║███████╗╚██████╔╝╚██████╔╝██║  ██║██║  ██║██████╔╝" "${RESET}"
  printf "%b%s%b\n" "${RED}" " ╚══╝╚══╝ ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝" "${RESET}"
  echo
  printf "  %b%s%b\n" "${BOLD}${RED_SOFT}" "$APP_NAME" "${RESET}"
  hr
}

step() {
  local label="$1"
  shift

  local log
  log="$(mktemp)"
  local rc=0

  if [[ -t 1 ]]; then
    "$@" >"$log" 2>&1 &
    local pid=$!
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
      printf "\r%b%s%b %b%s…%b" \
        "${RED_SOFT}" "${SPINNER_FRAMES[i]}" "${RESET}" \
        "${DIM}" "$label" "${RESET}"
      i=$(((i + 1) % ${#SPINNER_FRAMES[@]}))
      sleep 0.08
    done
    wait "$pid" || rc=$?
    if [[ "$rc" -eq 0 ]]; then
      printf "\r\033[2K%b✓%b %s\n" "${GREEN}" "${RESET}" "$label"
    else
      printf "\r\033[2K%b✗%b %s\n" "${RED}" "${RESET}" "$label"
    fi
  else
    printf "%b▸%b %s\n" "${RED_SOFT}" "${RESET}" "$label"
    "$@" >"$log" 2>&1 || rc=$?
    if [[ "$rc" -eq 0 ]]; then
      printf "%b✓%b %s\n" "${GREEN}" "${RESET}" "$label"
    else
      printf "%b✗%b %s\n" "${RED}" "${RESET}" "$label"
    fi
  fi

  if [[ "$rc" -ne 0 ]]; then
    echo
    error "Sortie de la commande :"
    sed -e 's/^/  /' "$log" >&2
    rm -f "$log"
    return "$rc"
  fi

  rm -f "$log"
  return 0
}

prompt_default() {
  local label="$1"
  local default="$2"
  local value

  printf "%b?%b %b%s%b %b[%s]%b : " \
    "${RED_SOFT}" "${RESET}" \
    "${BOLD}" "$label" "${RESET}" \
    "${DIM}" "$default" "${RESET}" >&2

  IFS= read -r value
  printf "%s" "${value:-$default}"
}

prompt_free() {
  local label="$1"
  local value

  printf "%b?%b %b%s%b : " \
    "${RED_SOFT}" "${RESET}" \
    "${BOLD}" "$label" "${RESET}" >&2

  IFS= read -r value
  printf "%s" "$value"
}

confirm_default_yes() {
  local label="$1"
  local value

  printf "%b?%b %b%s%b %b[Entrée=oui / non]%b : " \
    "${AMBER}" "${RESET}" \
    "${BOLD}" "$label" "${RESET}" \
    "${DIM}" "${RESET}" >&2

  IFS= read -r value
  value="${value:-oui}"
  value="${value,,}"
  [[ "$value" == "oui" || "$value" == "o" || "$value" == "yes" || "$value" == "y" ]]
}

confirm_default_no() {
  local label="$1"
  local value

  printf "%b?%b %b%s%b %b[oui / Entrée=non]%b : " \
    "${AMBER}" "${RESET}" \
    "${BOLD}" "$label" "${RESET}" \
    "${DIM}" "${RESET}" >&2

  IFS= read -r value
  value="${value:-non}"
  value="${value,,}"
  [[ "$value" == "oui" || "$value" == "o" || "$value" == "yes" || "$value" == "y" ]]
}

# ── Helpers généraux ──────────────────────────────────────────────────────────

need() {
  command -v "$1" >/dev/null 2>&1 || die "Commande manquante : $1"
}

have() {
  command -v "$1" >/dev/null 2>&1
}

require_root() {
  [[ "$(id -u)" -eq 0 ]] || die "Exécutez ce script en root."
}

trim_stdin() {
  sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

read_file_trimmed() {
  local file="$1"
  cat "$file" | trim_stdin
}

quote_env() {
  printf "%q" "$1"
}

detect_public_ip() {
  local ip=""

  if have curl; then
    ip="$(curl -4fsS --max-time 5 https://api.ipify.org 2>/dev/null || true)"
    [[ -z "$ip" ]] && ip="$(curl -4fsS --max-time 5 https://ifconfig.me/ip 2>/dev/null || true)"
    [[ -z "$ip" ]] && ip="$(curl -4fsS --max-time 5 https://icanhazip.com 2>/dev/null | trim_stdin || true)"
  elif have wget; then
    ip="$(wget -4qO- --timeout=5 https://api.ipify.org 2>/dev/null || true)"
    [[ -z "$ip" ]] && ip="$(wget -4qO- --timeout=5 https://icanhazip.com 2>/dev/null | trim_stdin || true)"
  fi

  if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf "%s" "$ip"
  fi
}

detect_default_interface() {
  ip route show default 2>/dev/null | awk '{print $5; exit}'
}

detect_lxc_ip() {
  local iface="${1:-}"
  local ipaddr=""

  if [[ -n "$iface" ]]; then
    ipaddr="$(ip -4 -o addr show dev "$iface" scope global 2>/dev/null | awk '{split($4,a,"/"); print a[1]; exit}')"
  fi

  if [[ -z "$ipaddr" ]]; then
    ipaddr="$(hostname -I 2>/dev/null | awk '{print $1}')"
  fi

  printf "%s" "$ipaddr"
}

detect_lan_cidr() {
  local iface="${1:-}"
  local cidr=""

  if [[ -n "$iface" ]]; then
    cidr="$(ip -4 route show dev "$iface" proto kernel scope link 2>/dev/null | awk '{print $1; exit}')"
  fi

  if [[ "$cidr" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
    printf "%s" "$cidr"
  else
    printf "192.168.1.0/24"
  fi
}

detect_lan_gateway() {
  ip route show default 2>/dev/null | awk '{print $3; exit}'
}

is_cgnat_ip() {
  # Plage CGNAT 100.64.0.0/10 : IP partagée par l'opérateur, non joignable de l'extérieur.
  local ipaddr="$1" a b
  IFS=. read -r a b _ _ <<< "$ipaddr"
  [[ "$a" =~ ^[0-9]+$ && "$b" =~ ^[0-9]+$ ]] || return 1
  [[ "$a" == "100" ]] && ((b >= 64 && b <= 127))
}

resolve_host_ipv4() {
  # Résout un nom de domaine en IPv4 via le résolveur système (getent, toujours présent).
  getent ahostsv4 "$1" 2>/dev/null | awk '{print $1; exit}' || true
}

human_since() {
  local s="$1"
  if ((s < 60)); then
    printf "%ds" "$s"
  elif ((s < 3600)); then
    printf "%dmin" "$((s / 60))"
  elif ((s < 86400)); then
    printf "%dh" "$((s / 3600))"
  else
    printf "%dj" "$((s / 86400))"
  fi
}

validate_port() {
  local port="$1"
  [[ "$port" =~ ^[0-9]+$ ]] || die "Port invalide : $port"
  ((port >= 1 && port <= 65535)) || die "Port hors plage : $port"
}

validate_endpoint_host() {
  local host="$1"

  validate_ipv4 "$host" && return 0
  [[ "$host" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$ ]] && return 0
  return 1
}

validate_ipv4() {
  local ipaddr="$1"
  local a b c d

  [[ "$ipaddr" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  IFS=. read -r a b c d <<< "$ipaddr"
  for n in "$a" "$b" "$c" "$d"; do
    [[ "$n" =~ ^[0-9]+$ ]] || return 1
    ((n >= 0 && n <= 255)) || return 1
  done
}

validate_cidr() {
  local cidr="$1"
  local ipaddr mask

  [[ "$cidr" == */* ]] || return 1
  ipaddr="${cidr%/*}"
  mask="${cidr#*/}"

  validate_ipv4 "$ipaddr" || return 1
  [[ "$mask" =~ ^[0-9]+$ ]] || return 1
  ((mask >= 1 && mask <= 32)) || return 1
}

validate_wireguard_cidr24() {
  local cidr="$1"
  local ipaddr mask a b c d

  validate_cidr "$cidr" || die "Réseau WireGuard invalide : $cidr"
  ipaddr="${cidr%/*}"
  mask="${cidr#*/}"

  [[ "$mask" == "24" ]] || die "Cette version accepte uniquement un réseau WireGuard en /24, par exemple 192.168.2.0/24."

  IFS=. read -r a b c d <<< "$ipaddr"
  [[ "$d" == "0" ]] || die "Le réseau WireGuard doit finir par .0 en /24, par exemple 192.168.2.0/24."
}

cidr24_prefix() {
  local cidr="$1"
  local ipaddr="${cidr%/*}"
  awk -F. '{print $1"."$2"."$3}' <<< "$ipaddr"
}

validate_server_ip_in_cidr24() {
  local ipaddr="$1"
  local prefix="$2"
  local last

  validate_ipv4 "$ipaddr" || die "IP serveur WireGuard invalide : $ipaddr"
  [[ "$ipaddr" == "${prefix}."* ]] || die "L'IP serveur doit être dans le réseau ${prefix}.0/24."
  last="$(awk -F. '{print $4}' <<< "$ipaddr")"
  ((last >= 1 && last <= 254)) || die "IP serveur WireGuard invalide : $ipaddr"
}

validate_range() {
  local start="$1"
  local end="$2"

  [[ "$start" =~ ^[0-9]+$ ]] || die "Début de plage invalide : $start"
  [[ "$end" =~ ^[0-9]+$ ]] || die "Fin de plage invalide : $end"
  ((start >= 2 && start <= 254)) || die "Début de plage hors limites : $start"
  ((end >= 2 && end <= 254)) || die "Fin de plage hors limites : $end"
  ((start <= end)) || die "La plage client est invalide : ${start}-${end}"
}

install_packages() {
  need apt-get
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y wireguard-tools iproute2 iputils-ping qrencode curl ca-certificates nftables
}

check_tun_or_explain() {
  if [[ -c /dev/net/tun ]]; then
    success "/dev/net/tun est disponible dans ce système."
    return 0
  fi

  panel "$AMBER" "Préparation LXC requise" \
    "WireGuard a besoin du périphérique ${BOLD}/dev/net/tun${RESET}." \
    "Dans un LXC Proxmox non privilégié, il faut le passer depuis le host Proxmox." \
    "Cette action doit être faite sur le ${BOLD}host Proxmox${RESET}, pas dans le conteneur."

  echo
  printf "%b%s%b\n" "${RED_DARK}" "Commandes à lancer sur le host Proxmox :" "${RESET}"
  cat <<'EOF'
pct stop <CTID>
pct set <CTID> --dev0 path=/dev/net/tun,mode=0666
pct start <CTID>
EOF
  echo
  warn "Remplacez <CTID> par l'identifiant du conteneur."
  warn "Relancez ensuite ce script dans le LXC."
  exit 1
}

save_state() {
  mkdir -p "$WG_DIR"
  chmod 700 "$WG_DIR"

  {
    printf "WG_IF=%s\n" "$(quote_env "${WG_IF:-wg0}")"
    printf "ENDPOINT_HOST=%s\n" "$(quote_env "${ENDPOINT_HOST:-}")"
    printf "LISTEN_PORT=%s\n" "$(quote_env "${LISTEN_PORT:-}")"
    printf "WG_CIDR=%s\n" "$(quote_env "${WG_CIDR:-}")"
    printf "WG_PREFIX=%s\n" "$(quote_env "${WG_PREFIX:-}")"
    printf "WG_SERVER_IP=%s\n" "$(quote_env "${WG_SERVER_IP:-}")"
    printf "OUT_IF=%s\n" "$(quote_env "${OUT_IF:-}")"
    printf "LXC_IP=%s\n" "$(quote_env "${LXC_IP:-}")"
    printf "INSTALL_MODE=%s\n" "$(quote_env "${INSTALL_MODE:-}")"
    printf "LAN_CIDR=%s\n" "$(quote_env "${LAN_CIDR:-}")"
    printf "LAN_NAT=%s\n" "$(quote_env "${LAN_NAT:-0}")"
    printf "CLIENT_ALLOWED_DEFAULT=%s\n" "$(quote_env "${CLIENT_ALLOWED_DEFAULT:-}")"
    printf "CLIENT_DNS_DEFAULT=%s\n" "$(quote_env "${CLIENT_DNS_DEFAULT:-}")"
    printf "CLIENT_RANGE_START=%s\n" "$(quote_env "${CLIENT_RANGE_START:-}")"
    printf "CLIENT_RANGE_END=%s\n" "$(quote_env "${CLIENT_RANGE_END:-}")"
    printf "DEFAULT_KEEPALIVE=%s\n" "$(quote_env "${DEFAULT_KEEPALIVE:-25}")"
  } > "$STATE_FILE"

  chmod 600 "$STATE_FILE"
}

load_state() {
  if [[ -f "$STATE_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$STATE_FILE"
  fi
}

get_server_public_key() {
  local pub=""
  local priv=""

  pub="$(wg show "$WG_IF" public-key 2>/dev/null || true)"

  if [[ -z "$pub" && -f "${WG_DIR}/server_public.key" ]]; then
    pub="$(read_file_trimmed "${WG_DIR}/server_public.key")"
  fi

  if [[ -z "$pub" && -f "${WG_DIR}/server.pub" ]]; then
    pub="$(read_file_trimmed "${WG_DIR}/server.pub")"
  fi

  if [[ -z "$pub" && -f "${WG_DIR}/server_private.key" ]]; then
    pub="$(wg pubkey < "${WG_DIR}/server_private.key")"
  fi

  if [[ -z "$pub" && -f "${WG_DIR}/server.key" ]]; then
    pub="$(wg pubkey < "${WG_DIR}/server.key")"
  fi

  if [[ -z "$pub" ]]; then
    priv="$(
      awk -F= '
        /^[[:space:]]*PrivateKey[[:space:]]*=/ {
          gsub(/^[ \t]+|[ \t]+$/, "", $2);
          print $2;
          exit
        }
      ' "$WG_CONF" 2>/dev/null || true
    )"

    if [[ -n "$priv" ]]; then
      pub="$(printf "%s\n" "$priv" | wg pubkey)"
    fi
  fi

  [[ -n "$pub" ]] || die "Impossible de déterminer la clé publique du serveur."
  printf "%s" "$pub"
}

render_conf_without_named_peer() {
  local input_file="$1"
  local output_file="$2"
  local peer_name="$3"

  awk -v name="$peer_name" '
    function ltrim(s) { sub(/^[ \t\r\n]+/, "", s); return s }
    function rtrim(s) { sub(/[ \t\r\n]+$/, "", s); return s }
    function trim(s)  { return rtrim(ltrim(s)) }

    function is_marker(s, t) {
      t = trim(s)
      if (substr(t, 1, 1) != "#") return 0
      sub(/^#[ \t]*/, "", t)
      return t == name
    }

    function is_section(s, t) {
      t = trim(s)
      return t ~ /^\[[^]]+\]$/
    }

    function is_blank(s, t) {
      t = trim(s)
      return t == ""
    }

    BEGIN { marker = 0; skip = 0 }

    {
      if (skip) {
        if (is_section($0)) {
          skip = 0
          print $0
          next
        }
        if (is_marker($0)) {
          marker = 1
          skip = 0
          next
        }
        if ($0 ~ /^[[:space:]]*#/) {
          skip = 0
          print $0
          next
        }
        next
      }

      if (marker) {
        if (is_blank($0)) next
        if (trim($0) == "[Peer]") {
          marker = 0
          skip = 1
          next
        }
        if (is_marker($0)) {
          marker = 1
          next
        }
        marker = 0
        print $0
        next
      }

      if (is_marker($0)) {
        marker = 1
        next
      }

      print $0
    }
  ' "$input_file" > "$output_file"
}

extract_peer_blocks() {
  local input_file="$1"

  awk '
    BEGIN { inpeer = 0 }
    /^[[:space:]]*\[Peer\][[:space:]]*$/ { inpeer = 1 }
    inpeer { print }
  ' "$input_file"
}

sync_wireguard() {
  local tmp
  tmp="$(mktemp)"

  if ! wg-quick strip "$WG_IF" > "$tmp"; then
    rm -f "$tmp"
    return 1
  fi

  if ! wg syncconf "$WG_IF" "$tmp"; then
    rm -f "$tmp"
    return 1
  fi

  rm -f "$tmp"
  return 0
}

# ── nftables / routage ────────────────────────────────────────────────────────

write_nft_config() {
  local need_nat="$1"

  cat > "$NFT_FILE" <<EOF
table inet wg_server {
  chain forward {
    type filter hook forward priority filter; policy accept;

    ct state established,related accept
    iifname "${WG_IF}" oifname "${WG_IF}" accept
    iifname "${WG_IF}" oifname "${OUT_IF}" accept
    iifname "${OUT_IF}" oifname "${WG_IF}" ct state established,related accept
  }
}
EOF

  if [[ "$need_nat" == "1" ]]; then
    cat >> "$NFT_FILE" <<EOF

table ip wg_server_nat {
  chain postrouting {
    type nat hook postrouting priority srcnat; policy accept;

    ip saddr ${WG_CIDR} oifname "${OUT_IF}" masquerade
  }
}
EOF
  fi

  chmod 600 "$NFT_FILE"
}

write_nft_unit() {
  cat > "$NFT_UNIT" <<EOF
[Unit]
Description=Règles nftables du serveur WireGuard
Wants=network-online.target
After=network-online.target
Before=wg-quick@${WG_IF}.service

[Service]
Type=oneshot
ExecStartPre=-/usr/sbin/nft delete table inet wg_server
ExecStartPre=-/usr/sbin/nft delete table ip wg_server_nat
ExecStart=/usr/sbin/nft -f ${NFT_FILE}
ExecStop=-/usr/sbin/nft delete table inet wg_server
ExecStop=-/usr/sbin/nft delete table ip wg_server_nat
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
}

enable_nft_rules() {
  systemctl daemon-reload
  systemctl enable --now wg-server-nft.service
}

disable_nft_rules() {
  if systemctl list-unit-files wg-server-nft.service >/dev/null 2>&1; then
    systemctl disable --now wg-server-nft.service >/dev/null 2>&1 || true
  fi

  if have nft; then
    nft delete table inet wg_server >/dev/null 2>&1 || true
    nft delete table ip wg_server_nat >/dev/null 2>&1 || true
  fi
}

configure_sysctl() {
  cat > /etc/sysctl.d/99-wireguard-server.conf <<'EOF'
# Serveur WireGuard
# Autorise le routage IPv4. Nécessaire pour permettre aux clients WireGuard
# de communiquer entre eux et, selon le mode choisi, vers le LAN ou Internet.
net.ipv4.ip_forward=1
EOF

  sysctl --system >/dev/null
}

# ── Installation serveur ──────────────────────────────────────────────────────

choose_mode() {
  echo
  panel "$BLUE" "Choix du mode réseau — le réglage le plus important" \
    "La question à se poser : une fois connecté en WireGuard, qu'est-ce que le" \
    "client doit pouvoir atteindre ? Les 3 exemples ci-dessous sont concrets." \
    "" \
    "${BOLD}1) Réseau privé entre vos appareils${RESET}  ${DIM}— le plus simple et le plus sûr${RESET}" \
    "   Seuls les appareils où VOUS installez WireGuard se voient entre eux." \
    "   ${CYAN}Exemple :${RESET} votre PC se connecte en SSH à un serveur, ou deux serveurs" \
    "   distants discutent en privé dans un tunnel chiffré." \
    "   ${GRAY}Aucun autre accès : ni au reste du réseau, ni à Internet via le serveur.${RESET}" \
    "" \
    "${BOLD}2) Accès au réseau local (LAN) situé derrière le serveur${RESET}" \
    "   Le client atteint AUSSI les autres machines du réseau du serveur," \
    "   même celles sans WireGuard : NAS, imprimante, caméras, interface Proxmox…" \
    "   ${CYAN}Exemple :${RESET} en déplacement, vous utilisez votre maison ou votre bureau" \
    "   comme si vous y étiez physiquement." \
    "   ${GRAY}C'est le VPN « accès à distance » classique.${RESET}" \
    "" \
    "${BOLD}3) Full tunnel — TOUT Internet passe par le serveur${RESET}" \
    "   La totalité du trafic du client (web, applis…) ressort par le serveur." \
    "   ${CYAN}Exemple :${RESET} sur un Wi-Fi public (hôtel, aéroport) vous chiffrez toute" \
    "   votre navigation, ou vous surfez avec l'adresse IP publique de chez vous." \
    "   ${GRAY}Comme un VPN commercial (NordVPN…), mais auto-hébergé. Demande du débit.${RESET}" \
    "" \
    "${DIM}Dans le doute, choisissez 1 : vous pourrez relancer ce script pour en changer.${RESET}"

  local choice
  choice="$(prompt_default "Mode réseau (1, 2 ou 3)" "1")"

  case "$choice" in
    1)
      INSTALL_MODE="private"
      CLIENT_ALLOWED_DEFAULT="$WG_CIDR"
      LAN_CIDR=""
      LAN_NAT="0"
      CLIENT_DNS_DEFAULT=""
      ;;
    2)
      INSTALL_MODE="lan"
      LAN_CIDR="$(prompt_default "Réseau LAN à rendre accessible" "$(detect_lan_cidr "$OUT_IF")")"
      validate_cidr "$LAN_CIDR" || die "Réseau LAN invalide : $LAN_CIDR"

      panel "$AMBER" "Accès au LAN" \
        "Mode simple : NAT vers le LAN." \
        "Les machines du LAN verront les connexions comme venant de l'IP du LXC." \
        "Mode avancé : sans NAT, mais il faut ajouter une route statique sur votre routeur/box."

      if confirm_default_yes "Utiliser le NAT pour simplifier l'accès au LAN ?"; then
        LAN_NAT="1"
      else
        LAN_NAT="0"
      fi

      CLIENT_ALLOWED_DEFAULT="${WG_CIDR}, ${LAN_CIDR}"

      local lan_gw
      lan_gw="$(detect_lan_gateway)"
      panel "$BLUE" "DNS pour le mode LAN (optionnel)" \
        "Pour joindre vos machines par leur nom (ex: nas, imprimante) et pas" \
        "seulement par leur adresse IP, les clients ont besoin d'un DNS local," \
        "qui est très souvent votre box/routeur."
      if [[ -n "$lan_gw" ]] && confirm_default_yes "Utiliser ${lan_gw} (votre box) comme DNS des clients ?"; then
        CLIENT_DNS_DEFAULT="$lan_gw"
      else
        CLIENT_DNS_DEFAULT=""
      fi
      ;;
    3)
      INSTALL_MODE="full"
      LAN_CIDR=""
      LAN_NAT="1"
      CLIENT_ALLOWED_DEFAULT="0.0.0.0/0"
      CLIENT_DNS_DEFAULT="$(prompt_default "DNS à mettre dans les profils clients" "1.1.1.1, 9.9.9.9")"

      panel "$AMBER" "Avertissement full tunnel" \
        "Ce mode fait passer Internet par le serveur WireGuard." \
        "Il dépend de l'upload de la connexion du serveur et de la redirection de port." \
        "Il peut également modifier fortement le comportement réseau des clients."

      if ! confirm_default_no "Confirmer le mode full tunnel Internet ?"; then
        die "Installation annulée."
      fi
      ;;
    *)
      die "Choix invalide : $choice"
      ;;
  esac
}

write_server_config() {
  local server_priv
  local peers_file="${1:-}"

  server_priv="$(read_file_trimmed "${WG_DIR}/server_private.key")"

  cat > "$WG_CONF" <<EOF
[Interface]
Address = ${WG_SERVER_IP}/24
ListenPort = ${LISTEN_PORT}
PrivateKey = ${server_priv}
SaveConfig = false
EOF

  if [[ -n "$peers_file" && -s "$peers_file" ]]; then
    echo "" >> "$WG_CONF"
    cat "$peers_file" >> "$WG_CONF"
  fi

  chmod 600 "$WG_CONF"
}

generate_or_reuse_server_keys() {
  mkdir -p "$WG_DIR" "$CLIENT_DIR"
  chmod 700 "$WG_DIR" "$CLIENT_DIR"

  if [[ -f "${WG_DIR}/server_private.key" ]]; then
    return 0
  fi

  wg genkey | tee "${WG_DIR}/server_private.key" | wg pubkey > "${WG_DIR}/server_public.key"
  chmod 600 "${WG_DIR}/server_private.key" "${WG_DIR}/server_public.key"
}

ensure_server_public_key_file() {
  if [[ ! -f "${WG_DIR}/server_public.key" ]]; then
    wg pubkey < "${WG_DIR}/server_private.key" > "${WG_DIR}/server_public.key"
    chmod 600 "${WG_DIR}/server_public.key"
  fi
}

verify_endpoint_domain() {
  local host="$1" public_ip="$2" resolved

  if validate_ipv4 "$host"; then
    return 0
  fi
  [[ -n "$public_ip" ]] || return 0

  resolved="$(resolve_host_ipv4 "$host")"
  if [[ -z "$resolved" ]]; then
    warn "Le domaine ${host} ne se résout pas encore (DNS non configuré ou propagation en cours)."
  elif [[ "$resolved" == "$public_ip" ]]; then
    success "Le domaine ${host} pointe bien vers ce serveur (${resolved})."
  else
    warn "Le domaine ${host} pointe vers ${resolved}, alors que votre IP publique est ${public_ip}."
    info "Vérifiez l'enregistrement DNS (A) de ${host} s'il doit cibler ce serveur."
  fi
}

configure_endpoint() {
  local detected_public_ip="$1"
  local value

  panel "$BLUE" "Adresse que les clients utiliseront (endpoint)" \
    "C'est l'adresse par laquelle vos clients joindront ce serveur depuis Internet." \
    "Indiquez votre IP publique fixe, ou un nom de domaine qui pointe vers vous."

  if [[ -n "$detected_public_ip" ]] && is_cgnat_ip "$detected_public_ip"; then
    panel "$AMBER" "Attention : vous semblez derrière un CGNAT" \
      "Votre IP publique (${BOLD}${detected_public_ip}${RESET}) est dans la plage 100.64.0.0/10." \
      "C'est une IP partagée par votre opérateur : le serveur ne sera PAS joignable" \
      "depuis l'extérieur, même avec une redirection de port." \
      "Solution : demandez une vraie IP publique à votre FAI (souvent gratuit)." \
      "Sans ça, seuls les appareils du réseau local pourront se connecter."
  fi

  echo
  if [[ -n "$detected_public_ip" ]]; then
    value="$(prompt_default "Domaine ou IP publique que les clients utiliseront" "$detected_public_ip")"
  else
    value="$(prompt_free "Domaine ou IP publique que les clients utiliseront")"
  fi
  [[ -n "$value" ]] || die "Domaine ou IP publique obligatoire."

  if ! validate_endpoint_host "$value"; then
    warn "« ${value} » ne ressemble pas à une IP ou un domaine valide."
    if ! confirm_default_no "Garder cette valeur quand même ?"; then
      die "Endpoint invalide."
    fi
  fi

  ENDPOINT_HOST="$value"
  verify_endpoint_domain "$ENDPOINT_HOST" "$detected_public_ip"
}

install_or_reconfigure_server() {
  require_root
  banner

  panel "$RED" "Installation serveur WireGuard" \
    "Ce mode installe WireGuard directement dans le LXC, sans Docker." \
    "Il crée le serveur ${BOLD}${WG_IF}${RESET}, active le routage IPv4 et prépare la gestion des clients." \
    "Le script est pensé pour Debian/Ubuntu avec systemd."

  check_tun_or_explain

  if [[ -f "$WG_CONF" ]]; then
    panel "$AMBER" "Configuration existante détectée" \
      "Le fichier ${CYAN}${WG_CONF}${RESET} existe déjà." \
      "Une réinstallation peut casser les clients existants si les clés serveur changent." \
      "Par défaut, le script conserve les clés serveur existantes."

    if ! confirm_default_no "Continuer avec une reconfiguration du serveur ?"; then
      die "Annulé."
    fi
  fi

  local detected_public_ip detected_out_if detected_lxc_ip detected_lan
  detected_public_ip="$(detect_public_ip || true)"
  detected_out_if="$(detect_default_interface || true)"
  detected_out_if="${detected_out_if:-eth0}"
  detected_lxc_ip="$(detect_lxc_ip "$detected_out_if")"
  detected_lan="$(detect_lan_cidr "$detected_out_if")"

  panel "$BLUE" "Détection automatique" \
    "IP publique détectée : ${BOLD}${detected_public_ip:-non détectée}${RESET}" \
    "Interface réseau     : ${BOLD}${detected_out_if}${RESET}" \
    "IP du LXC            : ${BOLD}${detected_lxc_ip:-non détectée}${RESET}" \
    "LAN probable         : ${BOLD}${detected_lan}${RESET}"

  configure_endpoint "$detected_public_ip"

  LISTEN_PORT="$(prompt_default "Port UDP WireGuard" "$DEFAULT_PORT")"
  validate_port "$LISTEN_PORT"

  OUT_IF="$(prompt_default "Interface réseau sortante du LXC" "$detected_out_if")"
  [[ -n "$OUT_IF" ]] || die "Interface sortante obligatoire."

  LXC_IP="$(detect_lxc_ip "$OUT_IF")"
  LXC_IP="${LXC_IP:-$detected_lxc_ip}"

  WG_CIDR="$(prompt_default "Réseau WireGuard en /24" "$DEFAULT_WG_CIDR")"
  validate_wireguard_cidr24 "$WG_CIDR"
  WG_PREFIX="$(cidr24_prefix "$WG_CIDR")"

  WG_SERVER_IP="$(prompt_default "IP WireGuard du serveur" "${WG_PREFIX}.1")"
  validate_server_ip_in_cidr24 "$WG_SERVER_IP" "$WG_PREFIX"

  CLIENT_RANGE_START="$(prompt_default "Début de plage IP automatique clients" "$DEFAULT_CLIENT_RANGE_START")"
  CLIENT_RANGE_END="$(prompt_default "Fin de plage IP automatique clients" "$DEFAULT_CLIENT_RANGE_END")"
  validate_range "$CLIENT_RANGE_START" "$CLIENT_RANGE_END"

  choose_mode

  panel "$AMBER" "Redirection de port à prévoir" \
    "Sur votre box/routeur, créez une redirection UDP :" \
    "Port externe : ${BOLD}${LISTEN_PORT}/UDP${RESET}" \
    "Destination  : ${BOLD}${LXC_IP:-IP_DU_LXC}:${LISTEN_PORT}${RESET}" \
    "Endpoint clients : ${BOLD}${ENDPOINT_HOST}:${LISTEN_PORT}${RESET}"

  if [[ "$INSTALL_MODE" == "lan" && "$LAN_NAT" == "0" ]]; then
    panel "$AMBER" "Route statique nécessaire" \
      "Comme le NAT LAN est désactivé, ajoutez sur votre routeur/box :" \
      "Route destination : ${BOLD}${WG_CIDR}${RESET}" \
      "Passerelle        : ${BOLD}${LXC_IP:-IP_DU_LXC}${RESET}" \
      "Sans cette route, le retour du trafic LAN vers WireGuard ne fonctionnera probablement pas."
  fi

  panel "$RED" "Résumé avant installation" \
    "Endpoint public : ${BOLD}${ENDPOINT_HOST}:${LISTEN_PORT}${RESET}" \
    "LXC détecté    : ${BOLD}${LXC_IP:-non détecté}${RESET}" \
    "Interface WAN  : ${BOLD}${OUT_IF}${RESET}" \
    "Réseau WG      : ${BOLD}${WG_CIDR}${RESET}" \
    "Serveur WG     : ${BOLD}${WG_SERVER_IP}${RESET}" \
    "Mode           : ${BOLD}${INSTALL_MODE}${RESET}" \
    "AllowedIPs clients par défaut : ${CYAN}${CLIENT_ALLOWED_DEFAULT}${RESET}"

  echo
  if ! confirm_default_yes "Lancer l'installation maintenant ?"; then
    die "Annulé."
  fi

  local ts backup_conf peers_tmp keep_peers
  ts="$(date +%F_%H%M%S)"
  backup_conf="${WG_CONF}.bak.${ts}"
  peers_tmp="$(mktemp)"
  keep_peers="0"

  if [[ -f "$WG_CONF" ]]; then
    cp -a "$WG_CONF" "$backup_conf"
    if confirm_default_yes "Conserver les clients déjà présents dans wg0.conf ?"; then
      keep_peers="1"
      extract_peer_blocks "$backup_conf" > "$peers_tmp"
    fi
  fi

  step "Installation des paquets Debian" install_packages || die "Échec installation des paquets."
  step "Génération ou réutilisation des clés serveur" generate_or_reuse_server_keys || die "Échec génération des clés serveur."
  step "Création de la clé publique serveur si nécessaire" ensure_server_public_key_file || die "Échec création clé publique serveur."
  step "Configuration du routage IPv4" configure_sysctl || die "Échec configuration ip_forward."

  if [[ "$keep_peers" == "1" ]]; then
    step "Écriture de ${WG_CONF} avec conservation des clients" write_server_config "$peers_tmp" || die "Échec écriture wg0.conf."
  else
    step "Écriture de ${WG_CONF}" write_server_config "" || die "Échec écriture wg0.conf."
  fi

  if [[ "$INSTALL_MODE" == "private" ]]; then
    step "Désactivation des anciennes règles nftables" disable_nft_rules || true
    rm -f "$NFT_FILE"
  elif [[ "$INSTALL_MODE" == "lan" && "$LAN_NAT" == "0" ]]; then
    step "Écriture des règles nftables de routage LAN sans NAT" write_nft_config "0" || die "Échec écriture nftables."
    step "Installation du service nftables" write_nft_unit || die "Échec service nftables."
    step "Activation des règles nftables" enable_nft_rules || die "Échec activation nftables."
  else
    step "Écriture des règles nftables avec NAT/MASQUERADE" write_nft_config "1" || die "Échec écriture nftables."
    step "Installation du service nftables" write_nft_unit || die "Échec service nftables."
    step "Activation des règles nftables" enable_nft_rules || die "Échec activation nftables."
  fi

  step "Activation du service WireGuard" systemctl enable --now "wg-quick@${WG_IF}" || die "Échec démarrage WireGuard."

  save_state
  rm -f "$peers_tmp"
  prune_conf_backups

  panel "$GREEN" "Serveur WireGuard installé" \
    "Interface       : ${BOLD}${WG_IF}${RESET}" \
    "Adresse serveur : ${BOLD}${WG_SERVER_IP}${RESET}" \
    "Port UDP        : ${BOLD}${LISTEN_PORT}${RESET}" \
    "Endpoint        : ${BOLD}${ENDPOINT_HOST}:${LISTEN_PORT}${RESET}" \
    "État sauvegardé : ${CYAN}${STATE_FILE}${RESET}"

  show_port_forwarding_help

  echo
  if confirm_default_yes "Créer un premier client maintenant ?"; then
    add_or_regenerate_client
  fi
}

# ── Gestion clients ───────────────────────────────────────────────────────────

get_used_octets_from_file() {
  local file="$1"

  awk -F= '
    /^[[:space:]]*AllowedIPs[[:space:]]*=/ {
      print $2
    }
  ' "$file" 2>/dev/null \
    | grep -Eo "${WG_PREFIX//./\\.}\.[0-9]{1,3}/32" \
    | awk -F'[./]' '{print $4}' \
    | sort -n \
    | uniq || true
}

is_used_octet() {
  local octet="$1"
  [[ -n "${USED_OCTETS:-}" ]] || return 1
  grep -qx "$octet" <<< "$USED_OCTETS"
}

find_free_octet() {
  local o server_last
  server_last="$(awk -F. '{print $4}' <<< "$WG_SERVER_IP")"

  for ((o=CLIENT_RANGE_START; o<=CLIENT_RANGE_END; o++)); do
    [[ "$o" == "$server_last" ]] && continue
    if ! is_used_octet "$o"; then
      printf "%s" "$o"
      return 0
    fi
  done

  return 1
}

normalize_ip_host() {
  local raw="$1"
  raw="$(printf "%s" "$raw" | trim_stdin)"

  if [[ "$raw" == */* ]]; then
    [[ "$raw" == */32 ]] || die "IP invalide : seul le suffixe /32 est accepté pour un client."
    raw="${raw%/32}"
  fi

  printf "%s" "$raw"
}

validate_client_ip() {
  local ipaddr="$1"
  local octet server_last

  validate_ipv4 "$ipaddr" || die "IP client invalide : $ipaddr"
  [[ "$ipaddr" == "${WG_PREFIX}."* ]] || die "L'IP client doit être dans ${WG_PREFIX}.0/24."

  octet="$(awk -F. '{print $4}' <<< "$ipaddr")"
  server_last="$(awk -F. '{print $4}' <<< "$WG_SERVER_IP")"

  ((octet >= 2 && octet <= 254)) || die "IP client hors limites : $ipaddr"

  if [[ "$octet" == "$server_last" ]]; then
    die "IP interdite : elle correspond à l'IP WireGuard du serveur."
  fi

  if is_used_octet "$octet"; then
    die "IP déjà utilisée dans ${WG_CONF} : ${ipaddr}/32"
  fi

  return 0
}

client_has_files() {
  [[ -e "$KEY_FILE" || -e "$PUB_FILE" || -e "$PSK_FILE" || -e "$CONF_FILE" ]]
}

client_has_server_block() {
  grep -qE "^[[:space:]]*#[[:space:]]*${NAME}[[:space:]]*$" "$WG_CONF" 2>/dev/null
}

detect_existing_client() {
  if client_has_files || client_has_server_block; then
    return 0
  fi
  return 1
}

prepare_client_overwrite() {
  OVERWRITE_CLIENT="0"

  if ! detect_existing_client; then
    return 0
  fi

  panel "$AMBER" "Client existant détecté" \
    "Le client ${BOLD}${NAME}${RESET} existe déjà partiellement ou totalement." \
    "Le script peut le sauvegarder puis le régénérer proprement."

  [[ -e "$KEY_FILE" ]] && warn "$KEY_FILE"
  [[ -e "$PUB_FILE" ]] && warn "$PUB_FILE"
  [[ -e "$PSK_FILE" ]] && warn "$PSK_FILE"
  [[ -e "$CONF_FILE" ]] && warn "$CONF_FILE"
  client_has_server_block && warn "Bloc serveur détecté dans ${WG_CONF} : # ${NAME}"

  echo
  if confirm_default_yes "Écraser/régénérer ce client ?"; then
    OVERWRITE_CLIENT="1"
  else
    die "Annulé pour éviter d'écraser un client existant."
  fi
}

backup_existing_client_files() {
  [[ "$OVERWRITE_CLIENT" == "1" ]] || return 0
  mkdir -p "$CLIENT_BACKUP_DIR"

  [[ -e "$KEY_FILE" ]] && cp -a "$KEY_FILE" "$CLIENT_BACKUP_DIR/"
  [[ -e "$PUB_FILE" ]] && cp -a "$PUB_FILE" "$CLIENT_BACKUP_DIR/"
  [[ -e "$PSK_FILE" ]] && cp -a "$PSK_FILE" "$CLIENT_BACKUP_DIR/"
  [[ -e "$CONF_FILE" ]] && cp -a "$CONF_FILE" "$CLIENT_BACKUP_DIR/"

  rm -f "$KEY_FILE" "$PUB_FILE" "$PSK_FILE" "$CONF_FILE"
}

prepare_server_config_for_client() {
  cp -a "$WG_CONF" "$BACKUP_FILE"

  if [[ "$OVERWRITE_CLIENT" == "1" ]]; then
    local tmp
    tmp="$(mktemp)"
    render_conf_without_named_peer "$WG_CONF" "$tmp" "$NAME"
    mv "$tmp" "$WG_CONF"
  fi
}

generate_client_files() {
  wg genkey | tee "$KEY_FILE" | wg pubkey > "$PUB_FILE"
  wg genpsk > "$PSK_FILE"
  chmod 600 "$KEY_FILE" "$PUB_FILE" "$PSK_FILE"
}

write_client_config() {
  local client_priv client_psk

  client_priv="$(read_file_trimmed "$KEY_FILE")"
  client_psk="$(read_file_trimmed "$PSK_FILE")"

  {
    echo "[Interface]"
    echo "PrivateKey = ${client_priv}"
    echo "Address = ${CLIENT_IP}"
    if [[ -n "${CLIENT_DNS:-}" ]]; then
      echo "DNS = ${CLIENT_DNS}"
    fi
    echo ""
    echo "[Peer]"
    echo "PublicKey = ${SERVER_PUB}"
    echo "PresharedKey = ${client_psk}"
    echo "Endpoint = ${ENDPOINT_HOST}:${LISTEN_PORT}"
    echo "AllowedIPs = ${CLIENT_ALLOWED}"
    echo "PersistentKeepalive = ${CLIENT_KEEPALIVE}"
  } > "$CONF_FILE"

  chmod 600 "$CONF_FILE"
}

append_server_peer() {
  local client_pub client_psk

  client_pub="$(read_file_trimmed "$PUB_FILE")"
  client_psk="$(read_file_trimmed "$PSK_FILE")"

  {
    echo ""
    echo "# ${NAME}"
    echo "[Peer]"
    echo "PublicKey = ${client_pub}"
    echo "PresharedKey = ${client_psk}"
    echo "AllowedIPs = ${CLIENT_IP}"
  } >> "$WG_CONF"
}

restore_client_on_failure() {
  [[ "$OVERWRITE_CLIENT" == "1" ]] || return 0
  [[ -d "$CLIENT_BACKUP_DIR" ]] || return 0

  rm -f "$KEY_FILE" "$PUB_FILE" "$PSK_FILE" "$CONF_FILE"
  [[ -e "${CLIENT_BACKUP_DIR}/$(basename "$KEY_FILE")" ]] && cp -a "${CLIENT_BACKUP_DIR}/$(basename "$KEY_FILE")" "$KEY_FILE"
  [[ -e "${CLIENT_BACKUP_DIR}/$(basename "$PUB_FILE")" ]] && cp -a "${CLIENT_BACKUP_DIR}/$(basename "$PUB_FILE")" "$PUB_FILE"
  [[ -e "${CLIENT_BACKUP_DIR}/$(basename "$PSK_FILE")" ]] && cp -a "${CLIENT_BACKUP_DIR}/$(basename "$PSK_FILE")" "$PSK_FILE"
  [[ -e "${CLIENT_BACKUP_DIR}/$(basename "$CONF_FILE")" ]] && cp -a "${CLIENT_BACKUP_DIR}/$(basename "$CONF_FILE")" "$CONF_FILE"
}

apply_client_or_rollback() {
  local rc=0

  if systemctl is-active --quiet "wg-quick@${WG_IF}"; then
    sync_wireguard || rc=$?
  else
    systemctl enable --now "wg-quick@${WG_IF}" || rc=$?
  fi

  if [[ "$rc" -ne 0 ]]; then
    cp -a "$BACKUP_FILE" "$WG_CONF" || true
    rm -f "$KEY_FILE" "$PUB_FILE" "$PSK_FILE" "$CONF_FILE" || true
    restore_client_on_failure || true

    if systemctl is-active --quiet "wg-quick@${WG_IF}"; then
      sync_wireguard || systemctl restart "wg-quick@${WG_IF}" || true
    else
      systemctl restart "wg-quick@${WG_IF}" || true
    fi

    return "$rc"
  fi

  return 0
}

show_client_config_if_requested() {
  echo
  if confirm_default_yes "Afficher maintenant le fichier .conf pour copier-coller ?"; then
    echo
    panel "$AMBER" "Configuration client — SECRET" \
      "Ce bloc contient une clé privée." \
      "Ne le publiez pas et ne le partagez pas avec une autre personne." \
      "Client : ${BOLD}${NAME}${RESET}" \
      "Fichier : ${CYAN}${CONF_FILE}${RESET}"
    echo
    printf "%b%s%b\n" "${RED_DARK}" "────────────────────── COPIER À PARTIR D'ICI ──────────────────────" "${RESET}"
    cat "$CONF_FILE"
    printf "%b%s%b\n" "${RED_DARK}" "────────────────────── COPIER JUSQU'ICI ───────────────────────────" "${RESET}"
  fi
}

show_qr_if_requested() {
  if ! have qrencode; then
    return 0
  fi

  echo
  if confirm_default_yes "Afficher le QR code à scanner avec l'app WireGuard sur mobile ?"; then
    echo
    qrencode -t ansiutf8 < "$CONF_FILE"
  fi
}

read_conf_listen_port() {
  awk -F= '/^[[:space:]]*ListenPort[[:space:]]*=/ {gsub(/[ \t\r]/,"",$2); print $2; exit}' "$WG_CONF" 2>/dev/null || true
}

read_conf_server_ip() {
  awk -F= '/^[[:space:]]*Address[[:space:]]*=/ {gsub(/[ \t\r]/,"",$2); split($2,a,","); sub(/\/.*/,"",a[1]); print a[1]; exit}' "$WG_CONF" 2>/dev/null || true
}

add_or_regenerate_client() {
  require_root
  need wg
  need wg-quick
  need systemctl

  local state_existed=1
  [[ -f "$STATE_FILE" ]] || state_existed=0

  load_state
  [[ -f "$WG_CONF" ]] || die "Serveur non configuré : ${WG_CONF} introuvable."
  if ((state_existed == 0)); then
    warn "Aucune configuration mémorisée : quelques réglages vont être demandés, puis enregistrés pour les prochaines fois."
  fi

  mkdir -p "$CLIENT_DIR"
  chmod 700 "$CLIENT_DIR"

  # Réseau WireGuard : on privilégie l'état, sinon on lit le wg0.conf existant.
  if [[ -z "${WG_CIDR:-}" ]]; then
    local conf_server_ip
    conf_server_ip="$(read_conf_server_ip)"
    if validate_ipv4 "$conf_server_ip"; then
      WG_SERVER_IP="${WG_SERVER_IP:-$conf_server_ip}"
      WG_PREFIX="$(cidr24_prefix "${conf_server_ip}/24")"
      WG_CIDR="${WG_PREFIX}.0/24"
    fi
  fi
  WG_CIDR="${WG_CIDR:-$DEFAULT_WG_CIDR}"
  validate_wireguard_cidr24 "$WG_CIDR"
  WG_PREFIX="${WG_PREFIX:-$(cidr24_prefix "$WG_CIDR")}"
  WG_SERVER_IP="${WG_SERVER_IP:-${WG_PREFIX}.1}"

  # Port d'écoute : état, sinon wg0.conf, sinon défaut.
  if [[ -z "${LISTEN_PORT:-}" ]]; then
    LISTEN_PORT="$(read_conf_listen_port)"
  fi
  LISTEN_PORT="${LISTEN_PORT:-$DEFAULT_PORT}"

  # Endpoint : information CÔTÉ CLIENT, absente du wg0.conf du serveur.
  # Si on ne la connaît pas (pas d'état), on la demande, l'IP publique servant de défaut.
  if [[ -z "${ENDPOINT_HOST:-}" ]]; then
    local detected_ip
    detected_ip="$(detect_public_ip || true)"
    echo
    if [[ -n "$detected_ip" ]]; then
      ENDPOINT_HOST="$(prompt_default "Domaine ou IP publique que les clients utiliseront" "$detected_ip")"
    else
      ENDPOINT_HOST="$(prompt_free "Domaine ou IP publique que les clients utiliseront")"
    fi
    [[ -n "$ENDPOINT_HOST" ]] || die "Domaine ou IP publique obligatoire."
    verify_endpoint_domain "$ENDPOINT_HOST" "$detected_ip"
  fi

  CLIENT_ALLOWED_DEFAULT="${CLIENT_ALLOWED_DEFAULT:-$WG_CIDR}"
  CLIENT_RANGE_START="${CLIENT_RANGE_START:-$DEFAULT_CLIENT_RANGE_START}"
  CLIENT_RANGE_END="${CLIENT_RANGE_END:-$DEFAULT_CLIENT_RANGE_END}"
  DEFAULT_KEEPALIVE="${DEFAULT_KEEPALIVE:-25}"

  SERVER_PUB="$(get_server_public_key)"

  banner
  panel "$RED" "Ajout ou régénération d'un client" \
    "Le client recevra une clé privée, une clé publique et une PSK dédiée." \
    "Le serveur recevra uniquement la clé publique du client et son IP WireGuard." \
    "Endpoint actuel : ${BOLD}${ENDPOINT_HOST}:${LISTEN_PORT}${RESET}"

  echo
  NAME="$(prompt_free "Nom du client, ex: pc-portable, telephone, tablette")"
  NAME="${NAME:-}"

  [[ -n "$NAME" ]] || die "Nom vide."
  if ! grep -Eq '^[a-zA-Z0-9._-]+$' <<< "$NAME"; then
    die "Nom invalide. Caractères autorisés : a-z A-Z 0-9 . _ -"
  fi

  KEY_FILE="${CLIENT_DIR}/${NAME}.key"
  PUB_FILE="${CLIENT_DIR}/${NAME}.pub"
  PSK_FILE="${CLIENT_DIR}/${NAME}.psk"
  CONF_FILE="${CLIENT_DIR}/${NAME}.conf"

  prepare_client_overwrite

  local scan_conf
  scan_conf="$WG_CONF"
  if [[ "$OVERWRITE_CLIENT" == "1" ]]; then
    scan_conf="$(mktemp)"
    render_conf_without_named_peer "$WG_CONF" "$scan_conf" "$NAME"
  fi

  USED_OCTETS="$(get_used_octets_from_file "$scan_conf")"

  if [[ "$OVERWRITE_CLIENT" == "1" ]]; then
    rm -f "$scan_conf"
  fi

  local free_octet auto_ip raw_ip
  free_octet="$(find_free_octet)" || die "Aucune IP libre trouvée dans ${WG_PREFIX}.${CLIENT_RANGE_START}-${CLIENT_RANGE_END}"
  auto_ip="${WG_PREFIX}.${free_octet}"

  echo
  raw_ip="$(prompt_default "IP WireGuard du client" "$auto_ip")"
  raw_ip="$(normalize_ip_host "$raw_ip")"
  validate_client_ip "$raw_ip"
  CLIENT_IP="${raw_ip}/32"

  echo
  CLIENT_ALLOWED="$(prompt_default "AllowedIPs côté client" "$CLIENT_ALLOWED_DEFAULT")"
  CLIENT_KEEPALIVE="$(prompt_default "PersistentKeepalive" "$DEFAULT_KEEPALIVE")"

  if [[ -n "${CLIENT_DNS_DEFAULT:-}" ]]; then
    CLIENT_DNS="$(prompt_default "DNS côté client" "$CLIENT_DNS_DEFAULT")"
  else
    CLIENT_DNS="$(prompt_default "DNS côté client, vide pour ne rien mettre" "")"
  fi

  [[ "$CLIENT_KEEPALIVE" =~ ^[0-9]+$ ]] || die "PersistentKeepalive doit être un nombre."

  if [[ "$CLIENT_ALLOWED" == *"0.0.0.0/0"* || "$CLIENT_ALLOWED" == *"::/0"* ]]; then
    panel "$AMBER" "Full tunnel dans le profil client" \
      "Ce profil peut faire passer Internet dans WireGuard." \
      "C'est normal uniquement si le serveur a été configuré pour ce mode."
    if ! confirm_default_yes "Conserver ces AllowedIPs ?"; then
      die "Annulé."
    fi
  fi

  local ts
  ts="$(date +%F_%H%M%S)"
  BACKUP_FILE="${WG_CONF}.bak.${ts}"
  CLIENT_BACKUP_DIR="${CLIENT_DIR}/.backup-${NAME}-${ts}"

  panel "$RED" "Résumé client" \
    "Nom client     : ${BOLD}${NAME}${RESET}" \
    "IP WireGuard   : ${BOLD}${CLIENT_IP}${RESET}" \
    "Endpoint       : ${BOLD}${ENDPOINT_HOST}:${LISTEN_PORT}${RESET}" \
    "AllowedIPs     : ${CYAN}${CLIENT_ALLOWED}${RESET}" \
    "DNS            : ${CYAN}${CLIENT_DNS:-aucun}${RESET}" \
    "Fichier client : ${CYAN}${CONF_FILE}${RESET}"

  echo
  if ! confirm_default_yes "Créer ou régénérer ce client ?"; then
    die "Annulé."
  fi

  step "Sauvegarde des anciens fichiers client" backup_existing_client_files || die "Échec sauvegarde fichiers client."
  step "Préparation de la configuration serveur" prepare_server_config_for_client || die "Échec préparation wg0.conf."
  step "Génération des clés client + PSK" generate_client_files || die "Échec génération des clés."
  step "Création du fichier client" write_client_config || die "Échec création du fichier client."
  step "Ajout du peer côté serveur" append_server_peer || die "Échec ajout peer serveur."
  step "Application de la configuration WireGuard" apply_client_or_rollback || die "Échec application. Rollback effectué."

  prune_conf_backups

  if ((state_existed == 0)); then
    if save_state; then
      success "Configuration mémorisée dans ${STATE_FILE} : l'endpoint et les réglages ne seront plus redemandés."
    fi
  fi

  panel "$GREEN" "Client prêt" \
    "Nom client     : ${BOLD}${NAME}${RESET}" \
    "IP WireGuard   : ${BOLD}${CLIENT_IP}${RESET}" \
    "Config client  : ${CYAN}${CONF_FILE}${RESET}" \
    "Clé privée     : ${CYAN}${KEY_FILE}${RESET}" \
    "Clé publique   : ${CYAN}${PUB_FILE}${RESET}" \
    "PSK            : ${CYAN}${PSK_FILE}${RESET}" \
    "Backup serveur : ${CYAN}${BACKUP_FILE}${RESET}"

  show_client_config_if_requested
  show_qr_if_requested

  echo
  info "État actuel de ${WG_IF} :"
  echo
  wg show "$WG_IF"
}

# ── Liste / gestion / diagnostic ──────────────────────────────────────────────

get_client_names() {
  [[ -d "$CLIENT_DIR" ]] || return 0
  (
    shopt -s nullglob
    for f in "$CLIENT_DIR"/*.conf; do
      printf "%s\n" "$(basename "${f%.conf}")"
    done
  ) | sort
}

client_ip_from_conf() {
  local conf="${CLIENT_DIR}/${1}.conf"
  [[ -f "$conf" ]] || return 0
  awk -F= '/^[[:space:]]*Address[[:space:]]*=/ {gsub(/[ \t]/,"",$2); sub(/\/.*/,"",$2); print $2; exit}' "$conf"
}

prune_conf_backups() {
  local keep=8
  (
    shopt -s nullglob
    set -- "${WG_CONF}".bak.*
    if (($# > keep)); then
      printf "%s\n" "$@" | sort | head -n "-${keep}" | while IFS= read -r f; do
        rm -f "$f"
      done
    fi
  )
}

choose_existing_client() {
  local names=() n sel i=1
  mapfile -t names < <(get_client_names)
  if ((${#names[@]} == 0)); then
    return 1
  fi

  printf "\n" >&2
  for n in "${names[@]}"; do
    printf "  %b%d%b) %s\n" "$RED_SOFT" "$i" "$RESET" "$n" >&2
    i=$((i + 1))
  done
  printf "\n" >&2

  sel="$(prompt_free "Numéro ou nom du client")"
  [[ -n "$sel" ]] || return 1

  if [[ "$sel" =~ ^[0-9]+$ ]] && ((sel >= 1 && sel <= ${#names[@]})); then
    printf "%s" "${names[$((sel - 1))]}"
    return 0
  fi

  for n in "${names[@]}"; do
    if [[ "$n" == "$sel" ]]; then
      printf "%s" "$n"
      return 0
    fi
  done

  return 1
}

list_clients() {
  require_root
  banner
  load_state || true

  WG_CIDR="${WG_CIDR:-$DEFAULT_WG_CIDR}"
  WG_PREFIX="${WG_PREFIX:-$(cidr24_prefix "$WG_CIDR")}"

  local names=()
  mapfile -t names < <(get_client_names)

  if ((${#names[@]} == 0)); then
    panel "$AMBER" "Aucun client" \
      "Aucun client n'a encore été créé." \
      "Utilisez « Ajouter ou régénérer un client » dans le menu."
    return 0
  fi

  declare -A HS
  local has_iface=0 pub hs
  if have wg && wg show "$WG_IF" >/dev/null 2>&1; then
    has_iface=1
    while IFS=$'\t' read -r pub _psk _ep _aip hs _rx _tx _ka; do
      if [[ -n "$pub" ]]; then
        HS["$pub"]="$hs"
      fi
    done < <(wg show "$WG_IF" dump 2>/dev/null | tail -n +2)
  fi

  local now rows=() name ip state
  now="$(date +%s)"
  for name in "${names[@]}"; do
    pub=""
    if [[ -f "${CLIENT_DIR}/${name}.pub" ]]; then
      pub="$(read_file_trimmed "${CLIENT_DIR}/${name}.pub")"
    fi
    ip="$(client_ip_from_conf "$name")"

    if ((has_iface == 0)); then
      state="${GRAY}état inconnu (interface arrêtée)${RESET}"
    else
      hs="${HS[$pub]:-0}"
      if [[ "$hs" =~ ^[0-9]+$ ]] && ((hs > 0)) && ((now - hs < 180)); then
        state="${GREEN}● connecté${RESET}"
      elif [[ "$hs" =~ ^[0-9]+$ ]] && ((hs > 0)); then
        state="${GRAY}○ vu il y a $(human_since "$((now - hs))")${RESET}"
      else
        state="${GRAY}○ jamais connecté${RESET}"
      fi
    fi

    rows+=("$(printf "%b%-20s%b %-16s %s" "$BOLD" "$name" "$RESET" "${ip:-?}" "$state")")
  done

  panel "$RED" "Clients WireGuard (${#names[@]})" "${rows[@]}"
  info "« connecté » = échange WireGuard dans les 3 dernières minutes."
}

show_existing_client() {
  require_root
  load_state || true
  banner

  panel "$RED" "Afficher / re-scanner un client" \
    "Cette option réaffiche la configuration et le QR code d'un client déjà créé." \
    "Pratique pour configurer un nouveau téléphone sans tout recommencer."

  local name conf
  if ! name="$(choose_existing_client)"; then
    warn "Aucun client à afficher."
    return 0
  fi

  conf="${CLIENT_DIR}/${name}.conf"
  [[ -f "$conf" ]] || die "Fichier introuvable : $conf"

  echo
  panel "$AMBER" "Configuration client — SECRET" \
    "Ce bloc contient une clé privée." \
    "Ne le publiez pas et ne le partagez avec personne." \
    "Client : ${BOLD}${name}${RESET}" \
    "Fichier : ${CYAN}${conf}${RESET}"
  echo
  printf "%b%s%b\n" "${RED_DARK}" "────────────────────── COPIER À PARTIR D'ICI ──────────────────────" "${RESET}"
  cat "$conf"
  printf "%b%s%b\n" "${RED_DARK}" "────────────────────── COPIER JUSQU'ICI ───────────────────────────" "${RESET}"

  if have qrencode; then
    echo
    if confirm_default_yes "Afficher le QR code à scanner avec l'app WireGuard sur mobile ?"; then
      echo
      qrencode -t ansiutf8 < "$conf"
    fi
  fi
}

revoke_client() {
  require_root
  need wg
  load_state || true
  banner

  panel "$RED" "Supprimer / révoquer un client" \
    "Le client choisi est retiré du serveur : il ne pourra plus se connecter." \
    "Ses fichiers sont déplacés dans une sauvegarde, pas détruits immédiatement."

  [[ -f "$WG_CONF" ]] || die "Serveur non configuré : ${WG_CONF} introuvable."

  local name
  if ! name="$(choose_existing_client)"; then
    warn "Aucun client à supprimer."
    return 0
  fi

  echo
  if ! confirm_default_no "Confirmer la suppression de « ${name} » ?"; then
    warn "Suppression annulée."
    return 0
  fi

  local ts backup_dir conf_backup tmp ext
  ts="$(date +%F_%H%M%S)"
  backup_dir="${CLIENT_DIR}/.removed-${name}-${ts}"
  conf_backup="${WG_CONF}.bak.${ts}"

  cp -a "$WG_CONF" "$conf_backup"

  tmp="$(mktemp)"
  render_conf_without_named_peer "$WG_CONF" "$tmp" "$name"
  mv "$tmp" "$WG_CONF"
  chmod 600 "$WG_CONF"

  mkdir -p "$backup_dir"
  for ext in key pub psk conf; do
    if [[ -e "${CLIENT_DIR}/${name}.${ext}" ]]; then
      mv "${CLIENT_DIR}/${name}.${ext}" "$backup_dir/"
    fi
  done

  if systemctl is-active --quiet "wg-quick@${WG_IF}"; then
    sync_wireguard || warn "Synchronisation à chaud échouée ; un redémarrage du service peut être nécessaire."
  fi

  prune_conf_backups

  panel "$GREEN" "Client supprimé" \
    "Client retiré   : ${BOLD}${name}${RESET}" \
    "Sauvegarde conf : ${CYAN}${conf_backup}${RESET}" \
    "Fichiers client : ${CYAN}${backup_dir}${RESET}"
}

run_diagnostic() {
  require_root
  banner
  load_state || true

  WG_CIDR="${WG_CIDR:-$DEFAULT_WG_CIDR}"
  LISTEN_PORT="${LISTEN_PORT:-$DEFAULT_PORT}"
  OUT_IF="${OUT_IF:-$(detect_default_interface || true)}"
  LXC_IP="${LXC_IP:-$(detect_lxc_ip "$OUT_IF")}"
  ENDPOINT_HOST="${ENDPOINT_HOST:-non défini}"
  INSTALL_MODE="${INSTALL_MODE:-inconnu}"

  panel "$RED" "Diagnostic du serveur WireGuard" \
    "Ce diagnostic vérifie l'essentiel et explique chaque point en clair." \
    "Mode configuré : ${BOLD}${INSTALL_MODE}${RESET}"

  echo

  if systemctl is-active --quiet "wg-quick@${WG_IF}"; then
    success "Service WireGuard actif (wg-quick@${WG_IF})."
  else
    error "Service WireGuard inactif. Démarrez-le ou réinstallez le serveur."
  fi

  if have ss && ss -lun 2>/dev/null | grep -qE "[:.]${LISTEN_PORT}([^0-9]|\$)"; then
    success "Port ${LISTEN_PORT}/UDP en écoute."
  else
    warn "Port ${LISTEN_PORT}/UDP non détecté en écoute (normal si le service est arrêté)."
  fi

  local ipf
  ipf="$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo 0)"
  if [[ "$ipf" == "1" ]]; then
    success "Routage IPv4 activé (nécessaire pour les modes LAN et full tunnel)."
  elif [[ "$INSTALL_MODE" == "private" ]]; then
    info "Routage IPv4 désactivé — sans importance en mode privé."
  else
    warn "Routage IPv4 désactivé alors que le mode ${INSTALL_MODE} en a besoin."
  fi

  if [[ "$INSTALL_MODE" != "private" && "$INSTALL_MODE" != "inconnu" ]]; then
    if have nft && nft list table inet wg_server >/dev/null 2>&1; then
      success "Règles de pare-feu/NAT du serveur WireGuard présentes."
    else
      warn "Règles nftables du serveur WireGuard absentes pour le mode ${INSTALL_MODE}."
    fi
  fi

  local names=() now total connected pub hs n
  mapfile -t names < <(get_client_names)
  total="${#names[@]}"
  connected=0
  now="$(date +%s)"

  if ((total > 0)) && have wg && wg show "$WG_IF" >/dev/null 2>&1; then
    declare -A HS
    while IFS=$'\t' read -r pub _psk _ep _aip hs _rx _tx _ka; do
      if [[ -n "$pub" ]]; then
        HS["$pub"]="$hs"
      fi
    done < <(wg show "$WG_IF" dump 2>/dev/null | tail -n +2)

    for n in "${names[@]}"; do
      if [[ -f "${CLIENT_DIR}/${n}.pub" ]]; then
        pub="$(read_file_trimmed "${CLIENT_DIR}/${n}.pub")"
        hs="${HS[$pub]:-0}"
        if [[ "$hs" =~ ^[0-9]+$ ]] && ((hs > 0)) && ((now - hs < 180)); then
          connected=$((connected + 1))
        fi
      fi
    done
  fi

  if ((total == 0)); then
    info "Aucun client configuré pour l'instant."
  else
    success "${total} client(s) configuré(s), ${connected} connecté(s) à l'instant."
    if ((connected == 0)); then
      info "0 connecté est normal si personne n'utilise le VPN en ce moment."
    fi
  fi

  echo
  panel "$AMBER" "À ne pas oublier" \
    "Endpoint des clients : ${BOLD}${ENDPOINT_HOST}:${LISTEN_PORT}${RESET}" \
    "La redirection ${BOLD}${LISTEN_PORT}/UDP${RESET} doit pointer vers ${BOLD}${LXC_IP:-IP_DU_LXC}${RESET} sur la box." \
    "Si rien ne se connecte de l'extérieur : vérifiez cette redirection," \
    "et que votre FAI vous donne une vraie IP publique (pas de CGNAT)."

  echo
  if confirm_default_no "Afficher les détails techniques bruts (wg show, systemctl) ?"; then
    echo
    if have wg; then
      wg show "$WG_IF" || true
    fi
    echo
    systemctl status "wg-quick@${WG_IF}" --no-pager 2>/dev/null || true
  fi
}

uninstall_server() {
  require_root
  banner

  panel "$AMBER" "Désinstaller le serveur WireGuard" \
    "Cette action arrête WireGuard et retire ses réglages réseau (nftables, routage)." \
    "Les clés et configurations ne sont effacées que si vous le demandez ensuite."

  echo
  if ! confirm_default_no "Arrêter et désinstaller le serveur WireGuard ?"; then
    warn "Désinstallation annulée."
    return 0
  fi

  systemctl disable --now "wg-quick@${WG_IF}" >/dev/null 2>&1 || true
  success "Service WireGuard arrêté."

  disable_nft_rules
  rm -f "$NFT_FILE" "$NFT_UNIT"
  success "Règles nftables retirées."

  rm -f /etc/sysctl.d/99-wireguard-server.conf
  sysctl --system >/dev/null 2>&1 || true
  systemctl daemon-reload || true
  success "Réglage de routage IPv4 du serveur WireGuard retiré."

  echo
  panel "$AMBER" "Supprimer aussi les clés et configurations ?" \
    "Cela efface ${CYAN}${WG_DIR}${RESET} : configuration serveur, clés et clients." \
    "Action irréversible : vos clients existants ne fonctionneront plus jamais."

  if confirm_default_no "Effacer définitivement ${WG_DIR} ?"; then
    rm -rf "$WG_DIR"
    success "Configurations et clés supprimées."
  else
    info "Configurations conservées dans ${WG_DIR}."
  fi

  echo
  if have apt-get && confirm_default_no "Désinstaller aussi les paquets wireguard-tools et qrencode ?"; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get remove -y wireguard-tools qrencode >/dev/null 2>&1 || true
    success "Paquets retirés (nftables et iproute2 conservés, utiles au système)."
  fi

  panel "$GREEN" "Désinstallation terminée" \
    "Le serveur WireGuard a été désinstallé de ce conteneur."
}

# ── Aide ──────────────────────────────────────────────────────────────────────

show_port_forwarding_help() {
  load_state || true

  local out_if lxc_ip port endpoint
  out_if="${OUT_IF:-$(detect_default_interface || true)}"
  lxc_ip="${LXC_IP:-$(detect_lxc_ip "$out_if")}"
  port="${LISTEN_PORT:-$DEFAULT_PORT}"
  endpoint="${ENDPOINT_HOST:-domaine-ou-ip-publique}"

  panel "$AMBER" "Aide redirection de port" \
    "À faire sur la box/routeur, pas dans le LXC :" \
    "Protocole : ${BOLD}UDP${RESET}" \
    "Port externe : ${BOLD}${port}${RESET}" \
    "IP destination : ${BOLD}${lxc_ip:-IP_DU_LXC}${RESET}" \
    "Port destination : ${BOLD}${port}${RESET}" \
    "Endpoint à utiliser par les clients : ${BOLD}${endpoint}:${port}${RESET}"

  warn "Si l'IP du LXC change, la redirection de port devra être corrigée."
  warn "Il est recommandé de donner une IP fixe au LXC côté Proxmox ou DHCP."
}

show_theory_summary() {
  panel "$BLUE" "Explication rapide pour débutants" \
    "WireGuard crée un réseau privé IP entre le serveur et les clients." \
    "Le serveur écoute en UDP sur un port, souvent 51820." \
    "Chaque client reçoit une IP WireGuard unique, par exemple 192.168.2.100." \
    "AllowedIPs décide ce qui passe dans le tunnel côté client."

  panel "$BLUE" "Les trois modes" \
    "1) Privé : seuls les appareils WireGuard communiquent entre eux." \
    "2) LAN : les clients peuvent accéder au réseau local derrière le serveur." \
    "3) Full tunnel : Internet des clients passe par le serveur."
}

main_menu() {
  require_root

  while true; do
    banner
    show_theory_summary

    echo
    printf "%b1%b) Installer ou reconfigurer le serveur WireGuard\n" "${RED_SOFT}" "${RESET}"
    printf "%b2%b) Ajouter ou régénérer un client\n" "${RED_SOFT}" "${RESET}"
    printf "%b3%b) Lister les clients et leur état\n" "${RED_SOFT}" "${RESET}"
    printf "%b4%b) Afficher / re-scanner un client (config + QR)\n" "${RED_SOFT}" "${RESET}"
    printf "%b5%b) Supprimer un client\n" "${RED_SOFT}" "${RESET}"
    printf "%b6%b) Diagnostic (vérifier que tout marche)\n" "${RED_SOFT}" "${RESET}"
    printf "%b7%b) Aide redirection de port\n" "${RED_SOFT}" "${RESET}"
    printf "%b8%b) Désinstaller le serveur WireGuard\n" "${RED_SOFT}" "${RESET}"
    printf "%b9%b) Quitter\n" "${RED_SOFT}" "${RESET}"
    echo

    local choice
    choice="$(prompt_default "Votre choix" "1")"

    case "$choice" in
      1) install_or_reconfigure_server ;;
      2) add_or_regenerate_client ;;
      3) list_clients ;;
      4) show_existing_client ;;
      5) revoke_client ;;
      6) run_diagnostic ;;
      7) banner; show_port_forwarding_help ;;
      8) uninstall_server ;;
      9) echo; success "Au revoir."; exit 0 ;;
      *) warn "Choix invalide." ;;
    esac

    echo
    if ! confirm_default_yes "Revenir au menu principal ?"; then
      exit 0
    fi
  done
}

main_menu "$@"
