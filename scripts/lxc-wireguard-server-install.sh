#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

# ──────────────────────────────────────────────────────────────────────────────
# WireGuard Forge — installateur serveur + gestionnaire de clients
# Thème rouge WireGuard
# ──────────────────────────────────────────────────────────────────────────────

WG_IF="wg0"
WG_DIR="/etc/wireguard"
WG_CONF="${WG_DIR}/${WG_IF}.conf"
CLIENT_DIR="${WG_DIR}/clients"
STATE_FILE="${WG_DIR}/wg-forge.env"
NFT_FILE="${WG_DIR}/wg-forge.nft"
NFT_UNIT="/etc/systemd/system/wg-forge-nft.service"

DEFAULT_PORT="51820"
DEFAULT_WG_CIDR="192.168.2.0/24"
DEFAULT_WG_SERVER_IP="192.168.2.1"
DEFAULT_CLIENT_RANGE_START="100"
DEFAULT_CLIENT_RANGE_END="254"
DEFAULT_KEEPALIVE="25"

APP_NAME="WireGuard Forge"

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
  printf "  %b%s%b %b— serveur natif LXC + clients%b\n" "${BOLD}${RED_SOFT}" "$APP_NAME" "${RESET}" "${GRAY}" "${RESET}"
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

validate_port() {
  local port="$1"
  [[ "$port" =~ ^[0-9]+$ ]] || die "Port invalide : $port"
  ((port >= 1 && port <= 65535)) || die "Port hors plage : $port"
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
    printf "WG_IF=%s\n" "$(quote_env "$WG_IF")"
    printf "ENDPOINT_HOST=%s\n" "$(quote_env "$ENDPOINT_HOST")"
    printf "LISTEN_PORT=%s\n" "$(quote_env "$LISTEN_PORT")"
    printf "WG_CIDR=%s\n" "$(quote_env "$WG_CIDR")"
    printf "WG_PREFIX=%s\n" "$(quote_env "$WG_PREFIX")"
    printf "WG_SERVER_IP=%s\n" "$(quote_env "$WG_SERVER_IP")"
    printf "OUT_IF=%s\n" "$(quote_env "$OUT_IF")"
    printf "LXC_IP=%s\n" "$(quote_env "$LXC_IP")"
    printf "INSTALL_MODE=%s\n" "$(quote_env "$INSTALL_MODE")"
    printf "LAN_CIDR=%s\n" "$(quote_env "${LAN_CIDR:-}")"
    printf "LAN_NAT=%s\n" "$(quote_env "${LAN_NAT:-0}")"
    printf "CLIENT_ALLOWED_DEFAULT=%s\n" "$(quote_env "$CLIENT_ALLOWED_DEFAULT")"
    printf "CLIENT_DNS_DEFAULT=%s\n" "$(quote_env "${CLIENT_DNS_DEFAULT:-}")"
    printf "CLIENT_RANGE_START=%s\n" "$(quote_env "$CLIENT_RANGE_START")"
    printf "CLIENT_RANGE_END=%s\n" "$(quote_env "$CLIENT_RANGE_END")"
    printf "DEFAULT_KEEPALIVE=%s\n" "$(quote_env "$DEFAULT_KEEPALIVE")"
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
table inet wg_forge {
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

table ip wg_forge_nat {
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
Description=WireGuard Forge nftables rules
Wants=network-online.target
After=network-online.target
Before=wg-quick@${WG_IF}.service

[Service]
Type=oneshot
ExecStartPre=-/usr/sbin/nft delete table inet wg_forge
ExecStartPre=-/usr/sbin/nft delete table ip wg_forge_nat
ExecStart=/usr/sbin/nft -f ${NFT_FILE}
ExecStop=-/usr/sbin/nft delete table inet wg_forge
ExecStop=-/usr/sbin/nft delete table ip wg_forge_nat
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
}

enable_nft_rules() {
  systemctl daemon-reload
  systemctl enable --now wg-forge-nft.service
}

disable_nft_rules() {
  if systemctl list-unit-files wg-forge-nft.service >/dev/null 2>&1; then
    systemctl disable --now wg-forge-nft.service >/dev/null 2>&1 || true
  fi

  if have nft; then
    nft delete table inet wg_forge >/dev/null 2>&1 || true
    nft delete table ip wg_forge_nat >/dev/null 2>&1 || true
  fi
}

configure_sysctl() {
  cat > /etc/sysctl.d/99-wireguard-forge.conf <<'EOF'
# WireGuard Forge
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
    "   ${GRAY}N'ouvre rien d'autre : ni le reste du réseau, ni Internet via le serveur.${RESET}" \
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
      CLIENT_DNS_DEFAULT=""
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

  echo
  if [[ -n "$detected_public_ip" ]]; then
    ENDPOINT_HOST="$(prompt_default "Domaine ou IP publique que les clients utiliseront" "$detected_public_ip")"
  else
    ENDPOINT_HOST="$(prompt_free "Domaine ou IP publique que les clients utiliseront")"
  fi
  [[ -n "$ENDPOINT_HOST" ]] || die "Domaine ou IP publique obligatoire."

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
    step "Désactivation des anciennes règles nftables WireGuard Forge" disable_nft_rules || true
    rm -f "$NFT_FILE"
  elif [[ "$INSTALL_MODE" == "lan" && "$LAN_NAT" == "0" ]]; then
    step "Écriture des règles nftables de routage LAN sans NAT" write_nft_config "0" || die "Échec écriture nftables."
    step "Installation du service nftables WireGuard Forge" write_nft_unit || die "Échec service nftables."
    step "Activation des règles nftables WireGuard Forge" enable_nft_rules || die "Échec activation nftables."
  else
    step "Écriture des règles nftables avec NAT/MASQUERADE" write_nft_config "1" || die "Échec écriture nftables."
    step "Installation du service nftables WireGuard Forge" write_nft_unit || die "Échec service nftables."
    step "Activation des règles nftables WireGuard Forge" enable_nft_rules || die "Échec activation nftables."
  fi

  step "Activation du service WireGuard" systemctl enable --now "wg-quick@${WG_IF}" || die "Échec démarrage WireGuard."

  save_state
  rm -f "$peers_tmp"

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
  [[ "$octet" == "$server_last" ]] && die "IP interdite : elle correspond à l'IP WireGuard du serveur."
  is_used_octet "$octet" && die "IP déjà utilisée dans ${WG_CONF} : ${ipaddr}/32"
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
  if confirm_default_no "Afficher aussi un QR code pour mobile ?"; then
    echo
    qrencode -t ansiutf8 < "$CONF_FILE"
  fi
}

add_or_regenerate_client() {
  require_root
  need wg
  need wg-quick
  need systemctl

  load_state
  [[ -f "$WG_CONF" ]] || die "Serveur non configuré : ${WG_CONF} introuvable."
  [[ -f "$STATE_FILE" ]] || warn "Fichier d'état ${STATE_FILE} introuvable. Le script va déduire une partie de la configuration."

  mkdir -p "$CLIENT_DIR"
  chmod 700 "$CLIENT_DIR"

  WG_CIDR="${WG_CIDR:-$DEFAULT_WG_CIDR}"
  validate_wireguard_cidr24 "$WG_CIDR"
  WG_PREFIX="${WG_PREFIX:-$(cidr24_prefix "$WG_CIDR")}"
  WG_SERVER_IP="${WG_SERVER_IP:-${WG_PREFIX}.1}"
  ENDPOINT_HOST="${ENDPOINT_HOST:-$(detect_public_ip || true)}"
  if [[ -z "$ENDPOINT_HOST" ]]; then
    ENDPOINT_HOST="$(prompt_free "Domaine ou IP publique que les clients utiliseront")"
    [[ -n "$ENDPOINT_HOST" ]] || die "Domaine ou IP publique obligatoire."
  fi
  LISTEN_PORT="${LISTEN_PORT:-$DEFAULT_PORT}"
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
  NAME="$(prompt_free "Nom du client, ex: PC-SAV, PVE-MIRIAD, phone-victor")"
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

# ── Statut / aide ─────────────────────────────────────────────────────────────

show_status() {
  require_root
  banner

  load_state || true

  panel "$RED" "Statut WireGuard Forge" \
    "Configuration serveur : ${CYAN}${WG_CONF}${RESET}" \
    "État Forge           : ${CYAN}${STATE_FILE}${RESET}" \
    "Dossier clients      : ${CYAN}${CLIENT_DIR}${RESET}"

  echo
  if systemctl list-unit-files "wg-quick@${WG_IF}.service" >/dev/null 2>&1; then
    systemctl status "wg-quick@${WG_IF}" --no-pager || true
  else
    warn "Service wg-quick@${WG_IF} non trouvé."
  fi

  echo
  if have wg; then
    wg show "$WG_IF" || true
  fi

  echo
  ip -br addr show "$WG_IF" 2>/dev/null || true
}

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
    printf "%b3%b) Afficher le statut\n" "${RED_SOFT}" "${RESET}"
    printf "%b4%b) Afficher l'aide redirection de port\n" "${RED_SOFT}" "${RESET}"
    printf "%b5%b) Quitter\n" "${RED_SOFT}" "${RESET}"
    echo

    local choice
    choice="$(prompt_default "Votre choix" "1")"

    case "$choice" in
      1) install_or_reconfigure_server ;;
      2) add_or_regenerate_client ;;
      3) show_status ;;
      4) banner; show_port_forwarding_help ;;
      5) echo; success "Au revoir."; exit 0 ;;
      *) warn "Choix invalide." ;;
    esac

    echo
    if ! confirm_default_yes "Revenir au menu principal ?"; then
      exit 0
    fi
  done
}

main_menu "$@"
