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
DEFAULT_CLIENT_RANGE_START="100"
DEFAULT_CLIENT_RANGE_END="254"
DEFAULT_KEEPALIVE="25"
DEFAULT_MTU="1420"

# ── Language ──────────────────────────────────────────────────────────────────
# The script speaks the language of the system, English by default. Same
# mechanism as the other scripts of the repository: the locale decides, and
# English is the fallback for an unknown locale as well as for a missing key.

detect_lang() {
  local raw="${LC_ALL:-${LC_MESSAGES:-${LANG:-en}}}"
  raw="${raw,,}"
  case "$raw" in
    fr* ) APP_LANG="fr" ;;
    * ) APP_LANG="en" ;;
  esac
}

APP_LANG="en"
detect_lang

declare -A I18N

load_i18n() {
  local lang key text
  while IFS='|' read -r lang key text; do
    [[ -z "${lang:-}" || -z "${key:-}" ]] && continue
    I18N["$lang:$key"]="$text"
  done <<'I18N_DATA'
en|app_name|WireGuard server install, setup and management
fr|app_name|Installation, configuration et gestion du serveur WireGuard
en|unit_day|d
fr|unit_day|j
en|err_command_output|Command output:
fr|err_command_output|Sortie de la commande :
en|hint_yes_default|Enter=yes / no
fr|hint_yes_default|Entrée=oui / non
en|hint_no_default|yes / Enter=no
fr|hint_no_default|oui / Entrée=non
en|err_missing_command|Missing command: %s
fr|err_missing_command|Commande manquante : %s
en|err_need_root|Run this script as root.
fr|err_need_root|Exécutez ce script en root.
en|err_port_invalid|Invalid port: %s
fr|err_port_invalid|Port invalide : %s
en|err_port_range|Port out of range: %s
fr|err_port_range|Port hors plage : %s
en|err_wg_cidr_invalid|Invalid WireGuard network: %s
fr|err_wg_cidr_invalid|Réseau WireGuard invalide : %s
en|err_wg_cidr_24_only|This version only accepts a /24 WireGuard network, for example 192.168.2.0/24.
fr|err_wg_cidr_24_only|Cette version accepte uniquement un réseau WireGuard en /24, par exemple 192.168.2.0/24.
en|err_wg_cidr_dot_zero|A /24 WireGuard network must end with .0, for example 192.168.2.0/24.
fr|err_wg_cidr_dot_zero|Le réseau WireGuard doit finir par .0 en /24, par exemple 192.168.2.0/24.
en|err_server_ip_invalid|Invalid WireGuard server IP: %s
fr|err_server_ip_invalid|IP serveur WireGuard invalide : %s
en|err_server_ip_not_in_cidr|The server IP must be inside the %s.0/24 network.
fr|err_server_ip_not_in_cidr|L'IP serveur doit être dans le réseau %s.0/24.
en|err_range_start_invalid|Invalid range start: %s
fr|err_range_start_invalid|Début de plage invalide : %s
en|err_range_end_invalid|Invalid range end: %s
fr|err_range_end_invalid|Fin de plage invalide : %s
en|err_range_start_bounds|Range start out of bounds: %s
fr|err_range_start_bounds|Début de plage hors limites : %s
en|err_range_end_bounds|Range end out of bounds: %s
fr|err_range_end_bounds|Fin de plage hors limites : %s
en|err_range_invalid|The client range is invalid: %s
fr|err_range_invalid|La plage client est invalide : %s
en|tun_available|/dev/net/tun is available on this system.
fr|tun_available|/dev/net/tun est disponible dans ce système.
en|tun_title|LXC preparation needed
fr|tun_title|Préparation LXC requise
en|tun_line1|WireGuard needs the %s device.
fr|tun_line1|WireGuard a besoin du périphérique %s.
en|tun_line2|On an unprivileged Proxmox LXC it has to be passed through from the Proxmox host.
fr|tun_line2|Dans un LXC Proxmox non privilégié, il faut le passer depuis le host Proxmox.
en|tun_line3|This has to be done on the %s, not inside the container.
fr|tun_line3|Cette action doit être faite sur le %s, pas dans le conteneur.
en|tun_host_proxmox|Proxmox host
fr|tun_host_proxmox|host Proxmox
en|tun_commands_intro|Commands to run on the Proxmox host:
fr|tun_commands_intro|Commandes à lancer sur le host Proxmox :
en|tun_replace_ctid|Replace <CTID> with the container id.
fr|tun_replace_ctid|Remplacez <CTID> par l'identifiant du conteneur.
en|tun_rerun|Then run this script again inside the LXC.
fr|tun_rerun|Relancez ensuite ce script dans le LXC.
en|err_no_server_pubkey|Unable to determine the server public key.
fr|err_no_server_pubkey|Impossible de déterminer la clé publique du serveur.
en|label_example|Example:
fr|label_example|Exemple :
en|mode_title|Network mode, the most important setting
fr|mode_title|Choix du mode réseau, le réglage le plus important
en|mode_intro1|The question to ask: once connected through WireGuard, what should the
fr|mode_intro1|La question à se poser : une fois connecté en WireGuard, qu'est-ce que le
en|mode_intro2|client be able to reach? The 3 examples below are concrete.
fr|mode_intro2|client doit pouvoir atteindre ? Les 3 exemples ci-dessous sont concrets.
en|mode_1_title|1) Private network between your own devices
fr|mode_1_title|1) Réseau privé entre vos appareils
en|mode_1_sub|the simplest and the safest
fr|mode_1_sub|le plus simple et le plus sûr
en|mode_1_l1|Only the devices where YOU install WireGuard can see each other.
fr|mode_1_l1|Seuls les appareils où VOUS installez WireGuard se voient entre eux.
en|mode_1_l2|your PC opens an SSH session to a server, or two remote
fr|mode_1_l2|votre PC se connecte en SSH à un serveur, ou deux serveurs
en|mode_1_l3|servers talk privately inside an encrypted tunnel.
fr|mode_1_l3|distants discutent en privé dans un tunnel chiffré.
en|mode_1_l4|Nothing else: no access to the rest of the network, no Internet through the server.
fr|mode_1_l4|Aucun autre accès : ni au reste du réseau, ni à Internet via le serveur.
en|mode_2_title|2) Access to the local network (LAN) behind the server
fr|mode_2_title|2) Accès au réseau local (LAN) situé derrière le serveur
en|mode_2_l1|The client ALSO reaches the other machines of the server network,
fr|mode_2_l1|Le client atteint AUSSI les autres machines du réseau du serveur,
en|mode_2_l2|even those without WireGuard: NAS, printer, cameras, Proxmox interface…
fr|mode_2_l2|même celles sans WireGuard : NAS, imprimante, caméras, interface Proxmox…
en|mode_2_l3|while travelling, you use your home or your office
fr|mode_2_l3|en déplacement, vous utilisez votre maison ou votre bureau
en|mode_2_l4|as if you were there in person.
fr|mode_2_l4|comme si vous y étiez physiquement.
en|mode_2_l5|This is the classic remote access VPN.
fr|mode_2_l5|C'est le VPN « accès à distance » classique.
en|mode_3_title|3) Full tunnel: ALL Internet traffic goes through the server
fr|mode_3_title|3) Full tunnel : TOUT Internet passe par le serveur
en|mode_3_l1|Every bit of client traffic (web, apps…) leaves through the server.
fr|mode_3_l1|La totalité du trafic du client (web, applis…) ressort par le serveur.
en|mode_3_l2|on a public Wi-Fi (hotel, airport) you encrypt all your
fr|mode_3_l2|sur un Wi-Fi public (hôtel, aéroport) vous chiffrez toute
en|mode_3_l3|browsing, or you browse with the public IP address of your home.
fr|mode_3_l3|votre navigation, ou vous surfez avec l'adresse IP publique de chez vous.
en|mode_3_l4|Like a commercial VPN (NordVPN…), but self hosted. It needs bandwidth.
fr|mode_3_l4|Comme un VPN commercial (NordVPN…), mais auto-hébergé. Demande du débit.
en|mode_hint|When in doubt, pick 1: you can run this script again to change it.
fr|mode_hint|Dans le doute, choisissez 1 : vous pourrez relancer ce script pour en changer.
en|prompt_mode|Network mode (1, 2 or 3)
fr|prompt_mode|Mode réseau (1, 2 ou 3)
en|prompt_lan_cidr|LAN network to make reachable
fr|prompt_lan_cidr|Réseau LAN à rendre accessible
en|err_lan_cidr|Invalid LAN network: %s
fr|err_lan_cidr|Réseau LAN invalide : %s
en|lan_title|LAN access
fr|lan_title|Accès au LAN
en|lan_l1|Simple mode: NAT towards the LAN.
fr|lan_l1|Mode simple : NAT vers le LAN.
en|lan_l2|LAN machines will see the connections as coming from the LXC IP.
fr|lan_l2|Les machines du LAN verront les connexions comme venant de l'IP du LXC.
en|lan_l3|Advanced mode: no NAT, but a static route has to be added on your router.
fr|lan_l3|Mode avancé : sans NAT, mais il faut ajouter une route statique sur votre routeur/box.
en|confirm_lan_nat|Use NAT to keep LAN access simple?
fr|confirm_lan_nat|Utiliser le NAT pour simplifier l'accès au LAN ?
en|dns_title|DNS for the LAN mode (optional)
fr|dns_title|DNS pour le mode LAN (optionnel)
en|dns_l1|To reach your machines by name (nas, printer) and not only by their
fr|dns_l1|Pour joindre vos machines par leur nom (ex: nas, imprimante) et pas
en|dns_l2|IP address, the clients need a local DNS server, which very often is
fr|dns_l2|seulement par leur adresse IP, les clients ont besoin d'un DNS local,
en|dns_l3|your own router.
fr|dns_l3|qui est très souvent votre box/routeur.
en|confirm_dns_gw|Use %s (your router) as the client DNS?
fr|confirm_dns_gw|Utiliser %s (votre box) comme DNS des clients ?
en|prompt_client_dns_profile|DNS to put in the client profiles
fr|prompt_client_dns_profile|DNS à mettre dans les profils clients
en|full_title|Full tunnel warning
fr|full_title|Avertissement full tunnel
en|full_l1|This mode sends the client Internet traffic through the WireGuard server.
fr|full_l1|Ce mode fait passer Internet par le serveur WireGuard.
en|full_l2|It depends on the upload speed of the server connection and on port forwarding.
fr|full_l2|Il dépend de l'upload de la connexion du serveur et de la redirection de port.
en|full_l3|It can also change the network behaviour of the clients quite a lot.
fr|full_l3|Il peut également modifier fortement le comportement réseau des clients.
en|confirm_full|Confirm the full Internet tunnel mode?
fr|confirm_full|Confirmer le mode full tunnel Internet ?
en|err_install_cancelled|Installation cancelled.
fr|err_install_cancelled|Installation annulée.
en|err_invalid_choice_value|Invalid choice: %s
fr|err_invalid_choice_value|Choix invalide : %s
en|dns_not_resolving|The domain %s does not resolve yet (DNS not configured, or still propagating).
fr|dns_not_resolving|Le domaine %s ne se résout pas encore (DNS non configuré ou propagation en cours).
en|dns_points_here|The domain %s does point to this server (%s).
fr|dns_points_here|Le domaine %s pointe bien vers ce serveur (%s).
en|dns_points_elsewhere|The domain %s points to %s, while your public IP is %s.
fr|dns_points_elsewhere|Le domaine %s pointe vers %s, alors que votre IP publique est %s.
en|dns_check_record|Check the DNS A record of %s if it is meant to target this server.
fr|dns_check_record|Vérifiez l'enregistrement DNS (A) de %s s'il doit cibler ce serveur.
en|endpoint_title|Address the clients will use (endpoint)
fr|endpoint_title|Adresse que les clients utiliseront (endpoint)
en|endpoint_l1|This is the address your clients will use to reach this server from the Internet.
fr|endpoint_l1|C'est l'adresse par laquelle vos clients joindront ce serveur depuis Internet.
en|endpoint_l2|Give your fixed public IP, or a domain name that points at you.
fr|endpoint_l2|Indiquez votre IP publique fixe, ou un nom de domaine qui pointe vers vous.
en|cgnat_title|Careful: you seem to be behind CGNAT
fr|cgnat_title|Attention : vous semblez derrière un CGNAT
en|cgnat_l1|Your public IP (%s) sits in the 100.64.0.0/10 range.
fr|cgnat_l1|Votre IP publique (%s) est dans la plage 100.64.0.0/10.
en|cgnat_l2|This is an IP shared by your provider: the server will NOT be reachable
fr|cgnat_l2|C'est une IP partagée par votre opérateur : le serveur ne sera PAS joignable
en|cgnat_l3|from the outside, even with port forwarding.
fr|cgnat_l3|depuis l'extérieur, même avec une redirection de port.
en|cgnat_l4|Fix: ask your provider for a real public IP (often free).
fr|cgnat_l4|Solution : demandez une vraie IP publique à votre FAI (souvent gratuit).
en|cgnat_l5|Without it, only devices on the local network will be able to connect.
fr|cgnat_l5|Sans ça, seuls les appareils du réseau local pourront se connecter.
en|prompt_endpoint|Domain or public IP the clients will use
fr|prompt_endpoint|Domaine ou IP publique que les clients utiliseront
en|err_endpoint_required|A domain or public IP is required.
fr|err_endpoint_required|Domaine ou IP publique obligatoire.
en|warn_endpoint_shape|"%s" does not look like a valid IP or domain.
fr|warn_endpoint_shape|« %s » ne ressemble pas à une IP ou un domaine valide.
en|confirm_keep_value|Keep this value anyway?
fr|confirm_keep_value|Garder cette valeur quand même ?
en|err_endpoint_invalid|Invalid endpoint.
fr|err_endpoint_invalid|Endpoint invalide.
en|install_title|WireGuard server install
fr|install_title|Installation serveur WireGuard
en|install_l1|This installs WireGuard directly inside the LXC, without Docker.
fr|install_l1|Ce mode installe WireGuard directement dans le LXC, sans Docker.
en|install_l2|It creates the %s server, turns on IPv4 forwarding and prepares client management.
fr|install_l2|Il crée le serveur %s, active le routage IPv4 et prépare la gestion des clients.
en|install_l3|The script targets Debian and Ubuntu with systemd.
fr|install_l3|Le script est pensé pour Debian/Ubuntu avec systemd.
en|exists_title|Existing configuration found
fr|exists_title|Configuration existante détectée
en|exists_l1|The file %s already exists.
fr|exists_l1|Le fichier %s existe déjà.
en|exists_l2|Reinstalling can break the existing clients if the server keys change.
fr|exists_l2|Une réinstallation peut casser les clients existants si les clés serveur changent.
en|exists_l3|By default the script keeps the existing server keys.
fr|exists_l3|Par défaut, le script conserve les clés serveur existantes.
en|confirm_reconfigure|Continue with a server reconfiguration?
fr|confirm_reconfigure|Continuer avec une reconfiguration du serveur ?
en|err_cancelled|Cancelled.
fr|err_cancelled|Annulé.
en|detect_title|Automatic detection
fr|detect_title|Détection automatique
en|detect_public_ip|Public IP detected  : %s
fr|detect_public_ip|IP publique détectée : %s
en|detect_iface|Network interface   : %s
fr|detect_iface|Interface réseau     : %s
en|detect_lxc_ip|LXC IP              : %s
fr|detect_lxc_ip|IP du LXC            : %s
en|detect_lan|Likely LAN          : %s
fr|detect_lan|LAN probable         : %s
en|value_not_detected_f|not detected
fr|value_not_detected_f|non détectée
en|value_not_detected_m|not detected
fr|value_not_detected_m|non détecté
en|prompt_port|WireGuard UDP port
fr|prompt_port|Port UDP WireGuard
en|port_busy_self|Port %s/UDP is already listening (most likely your current WireGuard, expected on a reconfiguration).
fr|port_busy_self|Le port %s/UDP est déjà en écoute (probablement votre WireGuard actuel, normal en reconfiguration).
en|port_busy_other|Port %s/UDP looks already used by another service on this machine.
fr|port_busy_other|Le port %s/UDP semble déjà utilisé par un autre service sur ce serveur.
en|confirm_port_anyway|Continue with that port anyway?
fr|confirm_port_anyway|Continuer quand même avec ce port ?
en|err_pick_other_port|Pick another port then run it again.
fr|err_pick_other_port|Choisissez un autre port puis relancez.
en|prompt_out_if|Outgoing network interface of the LXC
fr|prompt_out_if|Interface réseau sortante du LXC
en|err_out_if_required|An outgoing interface is required.
fr|err_out_if_required|Interface sortante obligatoire.
en|prompt_wg_cidr|WireGuard network, /24
fr|prompt_wg_cidr|Réseau WireGuard en /24
en|prompt_wg_server_ip|WireGuard IP of the server
fr|prompt_wg_server_ip|IP WireGuard du serveur
en|prompt_range_start|Start of the automatic client IP range
fr|prompt_range_start|Début de plage IP automatique clients
en|prompt_range_end|End of the automatic client IP range
fr|prompt_range_end|Fin de plage IP automatique clients
en|fwd_title|Port forwarding to set up
fr|fwd_title|Redirection de port à prévoir
en|fwd_l1|On your router, create a UDP forwarding rule:
fr|fwd_l1|Sur votre box/routeur, créez une redirection UDP :
en|fwd_ext_port|External port   : %s
fr|fwd_ext_port|Port externe     : %s
en|fwd_dest|Destination     : %s
fr|fwd_dest|Destination      : %s
en|fwd_endpoint|Client endpoint : %s
fr|fwd_endpoint|Endpoint clients : %s
en|placeholder_lxc_ip|LXC_IP
fr|placeholder_lxc_ip|IP_DU_LXC
en|route_title|Static route needed
fr|route_title|Route statique nécessaire
en|route_l1|Since LAN NAT is off, add this on your router:
fr|route_l1|Comme le NAT LAN est désactivé, ajoutez sur votre routeur/box :
en|route_dest|Route destination : %s
fr|route_dest|Route destination : %s
en|route_gw|Gateway           : %s
fr|route_gw|Passerelle        : %s
en|route_l2|Without that route, LAN traffic coming back to WireGuard will most likely not work.
fr|route_l2|Sans cette route, le retour du trafic LAN vers WireGuard ne fonctionnera probablement pas.
en|summary_title|Summary before installing
fr|summary_title|Résumé avant installation
en|sum_endpoint|Public endpoint : %s
fr|sum_endpoint|Endpoint public : %s
en|sum_lxc|LXC detected   : %s
fr|sum_lxc|LXC détecté    : %s
en|sum_wan|WAN interface  : %s
fr|sum_wan|Interface WAN  : %s
en|sum_wg_net|WG network     : %s
fr|sum_wg_net|Réseau WG      : %s
en|sum_wg_srv|WG server      : %s
fr|sum_wg_srv|Serveur WG     : %s
en|sum_mode|Mode           : %s
fr|sum_mode|Mode           : %s
en|sum_allowed|Default client AllowedIPs : %s
fr|sum_allowed|AllowedIPs clients par défaut : %s
en|confirm_install_now|Start the installation now?
fr|confirm_install_now|Lancer l'installation maintenant ?
en|confirm_keep_peers|Keep the clients already present in wg0.conf?
fr|confirm_keep_peers|Conserver les clients déjà présents dans wg0.conf ?
en|step_packages|Installing the Debian packages
fr|step_packages|Installation des paquets Debian
en|err_packages|Package installation failed.
fr|err_packages|Échec installation des paquets.
en|step_keys|Generating or reusing the server keys
fr|step_keys|Génération ou réutilisation des clés serveur
en|err_keys|Server key generation failed.
fr|err_keys|Échec génération des clés serveur.
en|step_pubkey|Creating the server public key if needed
fr|step_pubkey|Création de la clé publique serveur si nécessaire
en|err_pubkey|Server public key creation failed.
fr|err_pubkey|Échec création clé publique serveur.
en|step_sysctl|Setting up IPv4 forwarding
fr|step_sysctl|Configuration du routage IPv4
en|err_sysctl|ip_forward setup failed.
fr|err_sysctl|Échec configuration ip_forward.
en|step_write_conf_keep|Writing %s, keeping the clients
fr|step_write_conf_keep|Écriture de %s avec conservation des clients
en|step_write_conf|Writing %s
fr|step_write_conf|Écriture de %s
en|err_write_conf|Writing wg0.conf failed.
fr|err_write_conf|Échec écriture wg0.conf.
en|step_nft_disable|Disabling the old nftables rules
fr|step_nft_disable|Désactivation des anciennes règles nftables
en|step_nft_lan|Writing the nftables rules for LAN routing without NAT
fr|step_nft_lan|Écriture des règles nftables de routage LAN sans NAT
en|step_nft_nat|Writing the nftables rules with NAT/MASQUERADE
fr|step_nft_nat|Écriture des règles nftables avec NAT/MASQUERADE
en|err_nft_write|Writing the nftables rules failed.
fr|err_nft_write|Échec écriture nftables.
en|step_nft_unit|Installing the nftables service
fr|step_nft_unit|Installation du service nftables
en|err_nft_unit|The nftables service failed.
fr|err_nft_unit|Échec service nftables.
en|step_nft_enable|Enabling the nftables rules
fr|step_nft_enable|Activation des règles nftables
en|err_nft_enable|Enabling the nftables rules failed.
fr|err_nft_enable|Échec activation nftables.
en|step_wg_enable|Enabling the WireGuard service
fr|step_wg_enable|Activation du service WireGuard
en|err_wg_enable|WireGuard failed to start.
fr|err_wg_enable|Échec démarrage WireGuard.
en|done_title|WireGuard server installed
fr|done_title|Serveur WireGuard installé
en|done_iface|Interface       : %s
fr|done_iface|Interface       : %s
en|done_addr|Server address  : %s
fr|done_addr|Adresse serveur : %s
en|done_port|UDP port        : %s
fr|done_port|Port UDP        : %s
en|done_endpoint|Endpoint        : %s
fr|done_endpoint|Endpoint        : %s
en|done_state|State saved in  : %s
fr|done_state|État sauvegardé : %s
en|confirm_first_client|Create a first client now?
fr|confirm_first_client|Créer un premier client maintenant ?
en|err_client_ip_slash32|Invalid IP: only the /32 suffix is accepted for a client.
fr|err_client_ip_slash32|IP invalide : seul le suffixe /32 est accepté pour un client.
en|err_client_ip_invalid|Invalid client IP: %s
fr|err_client_ip_invalid|IP client invalide : %s
en|err_client_ip_not_in_net|The client IP must be inside %s.0/24.
fr|err_client_ip_not_in_net|L'IP client doit être dans %s.0/24.
en|err_client_ip_bounds|Client IP out of bounds: %s
fr|err_client_ip_bounds|IP client hors limites : %s
en|err_client_ip_is_server|Forbidden IP: this is the WireGuard IP of the server.
fr|err_client_ip_is_server|IP interdite : elle correspond à l'IP WireGuard du serveur.
en|err_client_ip_used|IP already used in %s: %s
fr|err_client_ip_used|IP déjà utilisée dans %s : %s
en|client_exists_title|Existing client found
fr|client_exists_title|Client existant détecté
en|client_exists_l1|The client %s already exists, partly or fully.
fr|client_exists_l1|Le client %s existe déjà partiellement ou totalement.
en|client_exists_l2|The script can back it up then regenerate it cleanly.
fr|client_exists_l2|Le script peut le sauvegarder puis le régénérer proprement.
en|client_server_block|Server block found in %s: # %s
fr|client_server_block|Bloc serveur détecté dans %s : # %s
en|confirm_overwrite_client|Overwrite and regenerate this client?
fr|confirm_overwrite_client|Écraser et régénérer ce client ?
en|err_overwrite_refused|Cancelled to avoid overwriting an existing client.
fr|err_overwrite_refused|Annulé pour éviter d'écraser un client existant.
en|confirm_show_conf|Show the .conf file now, ready to copy and paste?
fr|confirm_show_conf|Afficher maintenant le fichier .conf pour copier-coller ?
en|secret_title|Client configuration, SECRET
fr|secret_title|Configuration client, SECRET
en|secret_l1|This block holds a private key.
fr|secret_l1|Ce bloc contient une clé privée.
en|secret_l2|Do not publish it and do not share it with anyone.
fr|secret_l2|Ne le publiez pas et ne le partagez avec personne.
en|secret_client|Client : %s
fr|secret_client|Client : %s
en|secret_file|File   : %s
fr|secret_file|Fichier : %s
en|sep_copy_from|───────────────────────── COPY FROM HERE ──────────────────────────
fr|sep_copy_from|────────────────────── COPIER À PARTIR D'ICI ──────────────────────
en|sep_copy_to|───────────────────────── COPY UP TO HERE ─────────────────────────
fr|sep_copy_to|────────────────────── COPIER JUSQU'ICI ───────────────────────────
en|confirm_show_qr|Show the QR code to scan with the WireGuard mobile app?
fr|confirm_show_qr|Afficher le QR code à scanner avec l'app WireGuard sur mobile ?
en|err_server_not_configured|Server not configured: %s not found.
fr|err_server_not_configured|Serveur non configuré : %s introuvable.
en|warn_no_saved_state|No saved configuration: a few settings will be asked once, then remembered for next time.
fr|warn_no_saved_state|Aucune configuration mémorisée : quelques réglages vont être demandés, puis enregistrés pour les prochaines fois.
en|addclient_title|Add or regenerate a client
fr|addclient_title|Ajout ou régénération d'un client
en|addclient_l1|The client gets its own private key, public key and preshared key.
fr|addclient_l1|Le client recevra une clé privée, une clé publique et une PSK dédiée.
en|addclient_l2|The server only gets the client public key and its WireGuard IP.
fr|addclient_l2|Le serveur recevra uniquement la clé publique du client et son IP WireGuard.
en|addclient_l3|Current endpoint : %s
fr|addclient_l3|Endpoint actuel : %s
en|prompt_client_name|Client name, for example laptop, phone, tablet
fr|prompt_client_name|Nom du client, ex: pc-portable, telephone, tablette
en|err_name_empty|Empty name.
fr|err_name_empty|Nom vide.
en|err_name_invalid|Invalid name. Allowed characters: a-z A-Z 0-9 . _ -
fr|err_name_invalid|Nom invalide. Caractères autorisés : a-z A-Z 0-9 . _ -
en|err_no_free_ip|No free IP left in %s
fr|err_no_free_ip|Aucune IP libre trouvée dans %s
en|prompt_client_ip|WireGuard IP of the client
fr|prompt_client_ip|IP WireGuard du client
en|prompt_allowed|AllowedIPs on the client side
fr|prompt_allowed|AllowedIPs côté client
en|prompt_keepalive|PersistentKeepalive
fr|prompt_keepalive|PersistentKeepalive
en|prompt_client_dns|DNS on the client side
fr|prompt_client_dns|DNS côté client
en|prompt_client_dns_empty|DNS on the client side, empty for none
fr|prompt_client_dns_empty|DNS côté client, vide pour ne rien mettre
en|prompt_mtu|MTU
fr|prompt_mtu|MTU
en|err_keepalive_number|PersistentKeepalive must be a number.
fr|err_keepalive_number|PersistentKeepalive doit être un nombre.
en|err_mtu_number|The MTU must be a number.
fr|err_mtu_number|Le MTU doit être un nombre.
en|err_mtu_range|MTU out of range (1280-1500): %s
fr|err_mtu_range|MTU hors plage (1280-1500) : %s
en|fullprofile_title|Full tunnel in the client profile
fr|fullprofile_title|Full tunnel dans le profil client
en|fullprofile_l1|This profile can push the Internet traffic into WireGuard.
fr|fullprofile_l1|Ce profil peut faire passer Internet dans WireGuard.
en|fullprofile_l2|That is only expected if the server was set up for that mode.
fr|fullprofile_l2|C'est normal uniquement si le serveur a été configuré pour ce mode.
en|confirm_keep_allowed|Keep those AllowedIPs?
fr|confirm_keep_allowed|Conserver ces AllowedIPs ?
en|client_summary_title|Client summary
fr|client_summary_title|Résumé client
en|cs_name|Client name    : %s
fr|cs_name|Nom client     : %s
en|cs_ip|WireGuard IP   : %s
fr|cs_ip|IP WireGuard   : %s
en|cs_endpoint|Endpoint       : %s
fr|cs_endpoint|Endpoint       : %s
en|cs_allowed|AllowedIPs     : %s
fr|cs_allowed|AllowedIPs     : %s
en|cs_dns|DNS            : %s
fr|cs_dns|DNS            : %s
en|cs_mtu|MTU            : %s
fr|cs_mtu|MTU            : %s
en|cs_file|Client file    : %s
fr|cs_file|Fichier client : %s
en|value_none|none
fr|value_none|aucun
en|confirm_create_client|Create or regenerate this client?
fr|confirm_create_client|Créer ou régénérer ce client ?
en|step_backup_client|Backing up the old client files
fr|step_backup_client|Sauvegarde des anciens fichiers client
en|err_backup_client|Backing up the client files failed.
fr|err_backup_client|Échec sauvegarde fichiers client.
en|step_prepare_conf|Preparing the server configuration
fr|step_prepare_conf|Préparation de la configuration serveur
en|err_prepare_conf|Preparing wg0.conf failed.
fr|err_prepare_conf|Échec préparation wg0.conf.
en|step_gen_client_keys|Generating the client keys and preshared key
fr|step_gen_client_keys|Génération des clés client + PSK
en|err_gen_client_keys|Key generation failed.
fr|err_gen_client_keys|Échec génération des clés.
en|step_write_client|Creating the client file
fr|step_write_client|Création du fichier client
en|err_write_client|Creating the client file failed.
fr|err_write_client|Échec création du fichier client.
en|step_append_peer|Adding the peer on the server side
fr|step_append_peer|Ajout du peer côté serveur
en|err_append_peer|Adding the server peer failed.
fr|err_append_peer|Échec ajout peer serveur.
en|step_apply_conf|Applying the WireGuard configuration
fr|step_apply_conf|Application de la configuration WireGuard
en|err_apply_conf|Apply failed, rolled back.
fr|err_apply_conf|Échec application. Rollback effectué.
en|state_saved|Configuration saved in %s: the endpoint and the settings will not be asked again.
fr|state_saved|Configuration mémorisée dans %s : l'endpoint et les réglages ne seront plus redemandés.
en|client_ready_title|Client ready
fr|client_ready_title|Client prêt
en|cr_conf|Client config  : %s
fr|cr_conf|Config client  : %s
en|cr_privkey|Private key    : %s
fr|cr_privkey|Clé privée     : %s
en|cr_pubkey|Public key     : %s
fr|cr_pubkey|Clé publique   : %s
en|cr_psk|Preshared key  : %s
fr|cr_psk|PSK            : %s
en|cr_backup|Server backup  : %s
fr|cr_backup|Backup serveur : %s
en|current_state_of|Current state of %s:
fr|current_state_of|État actuel de %s :
en|noclient_title|No client
fr|noclient_title|Aucun client
en|noclient_l1|No client has been created yet.
fr|noclient_l1|Aucun client n'a encore été créé.
en|noclient_l2|Use "Add or regenerate a client" in the menu.
fr|noclient_l2|Utilisez « Ajouter ou régénérer un client » dans le menu.
en|state_unknown|state unknown (interface stopped)
fr|state_unknown|état inconnu (interface arrêtée)
en|state_connected|● connected
fr|state_connected|● connecté
en|state_seen|○ last seen %s ago
fr|state_seen|○ vu il y a %s
en|state_never|○ never connected
fr|state_never|○ jamais connecté
en|clients_title|WireGuard clients (%s)
fr|clients_title|Clients WireGuard (%s)
en|clients_hint|"connected" = WireGuard exchange within the last 3 minutes.
fr|clients_hint|« connecté » = échange WireGuard dans les 3 dernières minutes.
en|prompt_client_pick|Client number or name
fr|prompt_client_pick|Numéro ou nom du client
en|show_title|Show or re-scan a client
fr|show_title|Afficher / re-scanner un client
en|show_l1|This shows again the configuration and the QR code of an existing client.
fr|show_l1|Cette option réaffiche la configuration et le QR code d'un client déjà créé.
en|show_l2|Handy to set up a new phone without starting over.
fr|show_l2|Pratique pour configurer un nouveau téléphone sans tout recommencer.
en|warn_no_client_show|No client to show.
fr|warn_no_client_show|Aucun client à afficher.
en|err_file_not_found|File not found: %s
fr|err_file_not_found|Fichier introuvable : %s
en|revoke_title|Delete or revoke a client
fr|revoke_title|Supprimer / révoquer un client
en|revoke_l1|The chosen client is removed from the server: it can no longer connect.
fr|revoke_l1|Le client choisi est retiré du serveur : il ne pourra plus se connecter.
en|revoke_l2|Its files are moved to a backup, not destroyed right away.
fr|revoke_l2|Ses fichiers sont déplacés dans une sauvegarde, pas détruits immédiatement.
en|warn_no_client_delete|No client to delete.
fr|warn_no_client_delete|Aucun client à supprimer.
en|confirm_delete_client|Confirm the deletion of "%s"?
fr|confirm_delete_client|Confirmer la suppression de « %s » ?
en|warn_delete_cancelled|Deletion cancelled.
fr|warn_delete_cancelled|Suppression annulée.
en|warn_hot_sync_failed|Live sync failed, the service may need a restart.
fr|warn_hot_sync_failed|Synchronisation à chaud échouée, un redémarrage du service peut être nécessaire.
en|removed_title|Client deleted
fr|removed_title|Client supprimé
en|removed_client|Client removed  : %s
fr|removed_client|Client retiré   : %s
en|removed_conf|Config backup   : %s
fr|removed_conf|Sauvegarde conf : %s
en|removed_files|Client files    : %s
fr|removed_files|Fichiers client : %s
en|value_undefined|not set
fr|value_undefined|non défini
en|value_unknown|unknown
fr|value_unknown|inconnu
en|diag_title|WireGuard server diagnostic
fr|diag_title|Diagnostic du serveur WireGuard
en|diag_l1|This checks the essentials and explains each point in plain words.
fr|diag_l1|Ce diagnostic vérifie l'essentiel et explique chaque point en clair.
en|diag_mode|Configured mode : %s
fr|diag_mode|Mode configuré : %s
en|diag_service_ok|WireGuard service running (wg-quick@%s).
fr|diag_service_ok|Service WireGuard actif (wg-quick@%s).
en|diag_service_ko|WireGuard service stopped. Start it or reinstall the server.
fr|diag_service_ko|Service WireGuard inactif. Démarrez-le ou réinstallez le serveur.
en|diag_port_ok|Port %s/UDP is listening.
fr|diag_port_ok|Port %s/UDP en écoute.
en|diag_port_ko|Port %s/UDP not seen listening (expected if the service is stopped).
fr|diag_port_ko|Port %s/UDP non détecté en écoute (normal si le service est arrêté).
en|diag_fwd_ok|IPv4 forwarding on (needed by the LAN and full tunnel modes).
fr|diag_fwd_ok|Routage IPv4 activé (nécessaire pour les modes LAN et full tunnel).
en|diag_fwd_private|IPv4 forwarding off, which does not matter in private mode.
fr|diag_fwd_private|Routage IPv4 désactivé, sans importance en mode privé.
en|diag_fwd_ko|IPv4 forwarding off while the %s mode needs it.
fr|diag_fwd_ko|Routage IPv4 désactivé alors que le mode %s en a besoin.
en|diag_nft_ok|WireGuard server firewall and NAT rules are in place.
fr|diag_nft_ok|Règles de pare-feu et NAT du serveur WireGuard présentes.
en|diag_nft_ko|WireGuard server nftables rules missing for the %s mode.
fr|diag_nft_ko|Règles nftables du serveur WireGuard absentes pour le mode %s.
en|diag_no_client|No client configured yet.
fr|diag_no_client|Aucun client configuré pour l'instant.
en|diag_clients|%s client(s) configured, %s connected right now.
fr|diag_clients|%s client(s) configuré(s), %s connecté(s) à l'instant.
en|diag_zero_ok|0 connected is expected if nobody is using the VPN right now.
fr|diag_zero_ok|0 connecté est normal si personne n'utilise le VPN en ce moment.
en|remember_title|Do not forget
fr|remember_title|À ne pas oublier
en|remember_endpoint|Client endpoint : %s
fr|remember_endpoint|Endpoint des clients : %s
en|remember_fwd|The %s forwarding must point at %s on the router.
fr|remember_fwd|La redirection %s doit pointer vers %s sur la box.
en|remember_l1|If nothing connects from the outside: check that forwarding rule,
fr|remember_l1|Si rien ne se connecte de l'extérieur : vérifiez cette redirection,
en|remember_l2|and that your provider gives you a real public IP (no CGNAT).
fr|remember_l2|et que votre FAI vous donne une vraie IP publique (pas de CGNAT).
en|confirm_raw_details|Show the raw technical details (wg show, systemctl)?
fr|confirm_raw_details|Afficher les détails techniques bruts (wg show, systemctl) ?
en|backup_title|Configuration backup
fr|backup_title|Sauvegarde de la configuration
en|backup_l1|Creates an archive of %s: server configuration, keys and clients.
fr|backup_l1|Crée une archive de %s : configuration serveur, clés et clients.
en|backup_l2|Keep it somewhere safe: it holds private keys.
fr|backup_l2|Gardez-la en lieu sûr : elle contient des clés privées.
en|err_nothing_to_backup|Nothing to back up: %s not found.
fr|err_nothing_to_backup|Rien à sauvegarder : %s introuvable.
en|prompt_archive_create|Path of the archive to create
fr|prompt_archive_create|Chemin de l'archive à créer
en|err_empty_path|Empty path.
fr|err_empty_path|Chemin vide.
en|step_create_archive|Creating the archive
fr|step_create_archive|Création de l'archive
en|err_backup_failed|Backup failed.
fr|err_backup_failed|Échec de la sauvegarde.
en|backup_done_title|Backup created
fr|backup_done_title|Sauvegarde créée
en|backup_done_file|Archive : %s
fr|backup_done_file|Archive : %s
en|backup_done_content|Content : configuration, server keys and clients.
fr|backup_done_content|Contenu : configuration, clés serveur et clients.
en|backup_done_fetch|Fetch it off the server, for example: %s
fr|backup_done_fetch|À récupérer hors du serveur, par ex. : %s
en|restore_title|Configuration restore
fr|restore_title|Restauration de la configuration
en|restore_l1|Replaces %s with the content of a backup archive.
fr|restore_l1|Remplace %s par le contenu d'une archive de sauvegarde.
en|restore_l2|The current configuration is backed up first, just in case.
fr|restore_l2|La configuration actuelle sera d'abord sauvegardée par sécurité.
en|prompt_archive_restore|Path of the archive to restore (.tar.gz)
fr|prompt_archive_restore|Chemin de l'archive à restaurer (.tar.gz)
en|err_archive_not_found|Archive not found: %s
fr|err_archive_not_found|Archive introuvable : %s
en|err_archive_invalid|Invalid archive: %s/wg0.conf is not inside it.
fr|err_archive_invalid|Archive invalide : %s/wg0.conf introuvable dedans.
en|confirm_restore|Restore this archive and overwrite %s?
fr|confirm_restore|Restaurer cette archive et écraser %s ?
en|current_saved|Current configuration saved: %s
fr|current_saved|Configuration actuelle sauvegardée : %s
en|step_stop_wg|Stopping WireGuard
fr|step_stop_wg|Arrêt de WireGuard
en|err_extract|Extracting the archive failed.
fr|err_extract|Échec de l'extraction de l'archive.
en|warn_old_restored|Previous configuration put back.
fr|warn_old_restored|Ancienne configuration remise en place.
en|err_restore_failed|Restore failed.
fr|err_restore_failed|Restauration échouée.
en|restore_ok|Configuration restored from %s.
fr|restore_ok|Configuration restaurée depuis %s.
en|step_restart_wg|Restarting WireGuard
fr|step_restart_wg|Redémarrage de WireGuard
en|warn_wg_no_restart|WireGuard did not restart, check the restored configuration.
fr|warn_wg_no_restart|WireGuard n'a pas redémarré, vérifiez la configuration restaurée.
en|hint_enable_wg|Run "systemctl enable --now wg-quick@%s" to start the restored server.
fr|hint_enable_wg|Lancez « systemctl enable --now wg-quick@%s » pour démarrer le serveur restauré.
en|restore_done_title|Restore finished
fr|restore_done_title|Restauration terminée
en|restore_src|Source : %s
fr|restore_src|Source : %s
en|restore_dst|Target : %s
fr|restore_dst|Cible  : %s
en|backupmenu_title|Configuration backup and restore
fr|backupmenu_title|Sauvegarde / restauration de la configuration
en|backupmenu_1|1) Back up the configuration into an archive
fr|backupmenu_1|1) Sauvegarder la configuration dans une archive
en|backupmenu_2|2) Restore a configuration from an archive
fr|backupmenu_2|2) Restaurer une configuration depuis une archive
en|backupmenu_3|3) Back to the main menu
fr|backupmenu_3|3) Retour au menu principal
en|prompt_choice|Your choice
fr|prompt_choice|Votre choix
en|warn_invalid_choice|Invalid choice.
fr|warn_invalid_choice|Choix invalide.
en|uninstall_title|Uninstall the WireGuard server
fr|uninstall_title|Désinstaller le serveur WireGuard
en|uninstall_l1|This stops WireGuard and removes its network settings (nftables, forwarding).
fr|uninstall_l1|Cette action arrête WireGuard et retire ses réglages réseau (nftables, routage).
en|uninstall_l2|Keys and configurations are only erased if you ask for it afterwards.
fr|uninstall_l2|Les clés et configurations ne sont effacées que si vous le demandez ensuite.
en|confirm_uninstall|Stop and uninstall the WireGuard server?
fr|confirm_uninstall|Arrêter et désinstaller le serveur WireGuard ?
en|warn_uninstall_cancelled|Uninstall cancelled.
fr|warn_uninstall_cancelled|Désinstallation annulée.
en|ok_service_stopped|WireGuard service stopped.
fr|ok_service_stopped|Service WireGuard arrêté.
en|ok_nft_removed|nftables rules removed.
fr|ok_nft_removed|Règles nftables retirées.
en|ok_fwd_removed|IPv4 forwarding setting of the WireGuard server removed.
fr|ok_fwd_removed|Réglage de routage IPv4 du serveur WireGuard retiré.
en|purge_title|Erase the keys and configurations too?
fr|purge_title|Supprimer aussi les clés et configurations ?
en|purge_l1|This erases %s: server configuration, keys and clients.
fr|purge_l1|Cela efface %s : configuration serveur, clés et clients.
en|purge_l2|There is no way back: your existing clients will never work again.
fr|purge_l2|Action irréversible : vos clients existants ne fonctionneront plus jamais.
en|confirm_purge|Erase %s for good?
fr|confirm_purge|Effacer définitivement %s ?
en|ok_purged|Configurations and keys deleted.
fr|ok_purged|Configurations et clés supprimées.
en|info_kept|Configurations kept in %s.
fr|info_kept|Configurations conservées dans %s.
en|confirm_remove_packages|Remove the wireguard-tools and qrencode packages too?
fr|confirm_remove_packages|Désinstaller aussi les paquets wireguard-tools et qrencode ?
en|ok_packages_removed|Packages removed (nftables and iproute2 kept, the system uses them).
fr|ok_packages_removed|Paquets retirés (nftables et iproute2 conservés, utiles au système).
en|uninstall_done_title|Uninstall finished
fr|uninstall_done_title|Désinstallation terminée
en|uninstall_done_l1|The WireGuard server has been removed from this container.
fr|uninstall_done_l1|Le serveur WireGuard a été désinstallé de ce conteneur.
en|placeholder_endpoint|domain-or-public-ip
fr|placeholder_endpoint|domaine-ou-ip-publique
en|help_fwd_title|Port forwarding help
fr|help_fwd_title|Aide redirection de port
en|help_fwd_l1|To do on the router, not inside the LXC:
fr|help_fwd_l1|À faire sur la box/routeur, pas dans le LXC :
en|help_proto|Protocol : %s
fr|help_proto|Protocole : %s
en|help_ext_port|External port : %s
fr|help_ext_port|Port externe : %s
en|help_dest_ip|Destination IP : %s
fr|help_dest_ip|IP destination : %s
en|help_dest_port|Destination port : %s
fr|help_dest_port|Port destination : %s
en|help_endpoint|Endpoint the clients must use : %s
fr|help_endpoint|Endpoint à utiliser par les clients : %s
en|warn_ip_change|If the LXC IP changes, the port forwarding will have to be fixed.
fr|warn_ip_change|Si l'IP du LXC change, la redirection de port devra être corrigée.
en|warn_fixed_ip|Giving the LXC a fixed IP, in Proxmox or in DHCP, is recommended.
fr|warn_fixed_ip|Il est recommandé de donner une IP fixe au LXC côté Proxmox ou DHCP.
en|theory_title|How it works
fr|theory_title|Comment ça marche
en|theory_l1|WireGuard builds a private IP network between the server and the clients.
fr|theory_l1|WireGuard crée un réseau privé IP entre le serveur et les clients.
en|theory_l2|The server listens on a UDP port, usually 51820.
fr|theory_l2|Le serveur écoute en UDP sur un port, souvent 51820.
en|theory_l3|Each client gets its own WireGuard IP, for example 192.168.2.100.
fr|theory_l3|Chaque client reçoit une IP WireGuard unique, par exemple 192.168.2.100.
en|theory_l4|AllowedIPs decides what goes into the tunnel on the client side.
fr|theory_l4|AllowedIPs décide ce qui passe dans le tunnel côté client.
en|modes_title|The three modes
fr|modes_title|Les trois modes
en|modes_1|1) Private: only the WireGuard devices talk to each other.
fr|modes_1|1) Privé : seuls les appareils WireGuard communiquent entre eux.
en|modes_2|2) LAN: clients can reach the local network behind the server.
fr|modes_2|2) LAN : les clients peuvent accéder au réseau local derrière le serveur.
en|modes_3|3) Full tunnel: client Internet traffic goes through the server.
fr|modes_3|3) Full tunnel : Internet des clients passe par le serveur.
en|menu_1|Install or reconfigure the WireGuard server
fr|menu_1|Installer ou reconfigurer le serveur WireGuard
en|menu_2|Add or regenerate a client
fr|menu_2|Ajouter ou régénérer un client
en|menu_3|List the clients and their state
fr|menu_3|Lister les clients et leur état
en|menu_4|Show or re-scan a client (config + QR)
fr|menu_4|Afficher / re-scanner un client (config + QR)
en|menu_5|Delete a client
fr|menu_5|Supprimer un client
en|menu_6|Diagnostic (check that everything works)
fr|menu_6|Diagnostic (vérifier que tout marche)
en|menu_7|Port forwarding help
fr|menu_7|Aide redirection de port
en|menu_8|Backup and restore of the configuration
fr|menu_8|Sauvegarde / restauration de la configuration
en|menu_9|Uninstall the WireGuard server
fr|menu_9|Désinstaller le serveur WireGuard
en|menu_10|Quit
fr|menu_10|Quitter
en|bye|Goodbye.
fr|bye|Au revoir.
en|confirm_back_menu|Back to the main menu?
fr|confirm_back_menu|Revenir au menu principal ?
I18N_DATA
}

load_i18n

tr_msg() {
  local key="$1"
  printf '%s\n' "${I18N["$APP_LANG:$key"]:-${I18N["en:$key"]:-$key}}"
}

# Same, for a message carrying values: the text holds %s placeholders.
tr_fmt() {
  local key="$1"
  shift
  # shellcheck disable=SC2059
  printf "${I18N["$APP_LANG:$key"]:-${I18N["en:$key"]:-$key}}" "$@"
}

APP_NAME="$(tr_msg app_name)"

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
  local cols line
  cols="$(term_width)"
  # Bash substitution instead of tr: tr works on bytes and would turn a
  # multi byte box character into garbage.
  printf -v line "%*s" "$cols" ""
  printf "%b%s%b\n" "${RED_DARK}" "${line// /─}" "${RESET}"
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
  printf "  %b%s%b %b· by Victor-root%b\n" "${BOLD}${RED_SOFT}" "$APP_NAME" "${RESET}" "${GRAY}" "${RESET}"
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
    error "$(tr_msg err_command_output)"
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

  printf "%b?%b %b%s%b %b[%s]%b : " \
    "${AMBER}" "${RESET}" \
    "${BOLD}" "$label" "${RESET}" \
    "${DIM}" "$(tr_msg hint_yes_default)" "${RESET}" >&2

  IFS= read -r value
  if [[ -z "$value" ]]; then
    return 0
  fi
  value="${value,,}"
  [[ "$value" == "oui" || "$value" == "o" || "$value" == "yes" || "$value" == "y" ]]
}

confirm_default_no() {
  local label="$1"
  local value

  printf "%b?%b %b%s%b %b[%s]%b : " \
    "${AMBER}" "${RESET}" \
    "${BOLD}" "$label" "${RESET}" \
    "${DIM}" "$(tr_msg hint_no_default)" "${RESET}" >&2

  IFS= read -r value
  if [[ -z "$value" ]]; then
    return 1
  fi
  value="${value,,}"
  [[ "$value" == "oui" || "$value" == "o" || "$value" == "yes" || "$value" == "y" ]]
}

# ── Helpers généraux ──────────────────────────────────────────────────────────

need() {
  command -v "$1" >/dev/null 2>&1 || die "$(tr_fmt err_missing_command "$1")"
}

have() {
  command -v "$1" >/dev/null 2>&1
}

require_root() {
  [[ "$(id -u)" -eq 0 ]] || die "$(tr_msg err_need_root)"
}

trim_stdin() {
  sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

read_file_trimmed() {
  local file="$1"
  trim_stdin < "$file"
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
    printf "%d%s" "$((s / 86400))" "$(tr_msg unit_day)"
  fi
}

validate_port() {
  local port="$1"
  [[ "$port" =~ ^[0-9]+$ ]] || die "$(tr_fmt err_port_invalid "$port")"
  ((port >= 1 && port <= 65535)) || die "$(tr_fmt err_port_range "$port")"
}

port_in_use() {
  have ss || return 1
  ss -lun 2>/dev/null | grep -qE "[:.]${1}([^0-9]|\$)"
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

  validate_cidr "$cidr" || die "$(tr_fmt err_wg_cidr_invalid "$cidr")"
  ipaddr="${cidr%/*}"
  mask="${cidr#*/}"

  [[ "$mask" == "24" ]] || die "$(tr_msg err_wg_cidr_24_only)"

  IFS=. read -r a b c d <<< "$ipaddr"
  [[ "$d" == "0" ]] || die "$(tr_msg err_wg_cidr_dot_zero)"
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

  validate_ipv4 "$ipaddr" || die "$(tr_fmt err_server_ip_invalid "$ipaddr")"
  [[ "$ipaddr" == "${prefix}."* ]] || die "$(tr_fmt err_server_ip_not_in_cidr "$prefix")"
  last="$(awk -F. '{print $4}' <<< "$ipaddr")"
  ((last >= 1 && last <= 254)) || die "$(tr_fmt err_server_ip_invalid "$ipaddr")"
}

validate_range() {
  local start="$1"
  local end="$2"

  [[ "$start" =~ ^[0-9]+$ ]] || die "$(tr_fmt err_range_start_invalid "$start")"
  [[ "$end" =~ ^[0-9]+$ ]] || die "$(tr_fmt err_range_end_invalid "$end")"
  ((start >= 2 && start <= 254)) || die "$(tr_fmt err_range_start_bounds "$start")"
  ((end >= 2 && end <= 254)) || die "$(tr_fmt err_range_end_bounds "$end")"
  ((start <= end)) || die "$(tr_fmt err_range_invalid "${start}-${end}")"
}

install_packages() {
  need apt-get
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y wireguard-tools iproute2 iputils-ping qrencode curl ca-certificates nftables
}

check_tun_or_explain() {
  if [[ -c /dev/net/tun ]]; then
    success "$(tr_msg tun_available)"
    return 0
  fi

  panel "$AMBER" "$(tr_msg tun_title)" \
    "$(tr_fmt tun_line1 "${BOLD}/dev/net/tun${RESET}")" \
    "$(tr_msg tun_line2)" \
    "$(tr_fmt tun_line3 "${BOLD}$(tr_msg tun_host_proxmox)${RESET}")"

  echo
  printf "%b%s%b\n" "${RED_DARK}" "$(tr_msg tun_commands_intro)" "${RESET}"
  cat <<'EOF'
pct stop <CTID>
pct set <CTID> --dev0 path=/dev/net/tun,mode=0666
pct start <CTID>
EOF
  echo
  warn "$(tr_msg tun_replace_ctid)"
  warn "$(tr_msg tun_rerun)"
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
    printf "DEFAULT_MTU=%s\n" "$(quote_env "${DEFAULT_MTU:-1420}")"
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

  [[ -n "$pub" ]] || die "$(tr_msg err_no_server_pubkey)"
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
Description=WireGuard server nftables rules
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
# WireGuard server
# Enables IPv4 forwarding, needed for the WireGuard clients to reach each
# other and, depending on the chosen mode, the LAN or the Internet.
net.ipv4.ip_forward=1
EOF

  sysctl --system >/dev/null
}

# ── Installation serveur ──────────────────────────────────────────────────────

choose_mode() {
  echo
  panel "$BLUE" "$(tr_msg mode_title)" \
    "$(tr_msg mode_intro1)" \
    "$(tr_msg mode_intro2)" \
    "" \
    "${BOLD}$(tr_msg mode_1_title)${RESET}  ${DIM}$(tr_msg mode_1_sub)${RESET}" \
    "   $(tr_msg mode_1_l1)" \
    "   ${CYAN}$(tr_msg label_example)${RESET} $(tr_msg mode_1_l2)" \
    "   $(tr_msg mode_1_l3)" \
    "   ${GRAY}$(tr_msg mode_1_l4)${RESET}" \
    "" \
    "${BOLD}$(tr_msg mode_2_title)${RESET}" \
    "   $(tr_msg mode_2_l1)" \
    "   $(tr_msg mode_2_l2)" \
    "   ${CYAN}$(tr_msg label_example)${RESET} $(tr_msg mode_2_l3)" \
    "   $(tr_msg mode_2_l4)" \
    "   ${GRAY}$(tr_msg mode_2_l5)${RESET}" \
    "" \
    "${BOLD}$(tr_msg mode_3_title)${RESET}" \
    "   $(tr_msg mode_3_l1)" \
    "   ${CYAN}$(tr_msg label_example)${RESET} $(tr_msg mode_3_l2)" \
    "   $(tr_msg mode_3_l3)" \
    "   ${GRAY}$(tr_msg mode_3_l4)${RESET}" \
    "" \
    "${DIM}$(tr_msg mode_hint)${RESET}"

  local choice
  choice="$(prompt_default "$(tr_msg prompt_mode)" "1")"

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
      LAN_CIDR="$(prompt_default "$(tr_msg prompt_lan_cidr)" "$(detect_lan_cidr "$OUT_IF")")"
      validate_cidr "$LAN_CIDR" || die "$(tr_fmt err_lan_cidr "$LAN_CIDR")"

      panel "$AMBER" "$(tr_msg lan_title)" \
        "$(tr_msg lan_l1)" \
        "$(tr_msg lan_l2)" \
        "$(tr_msg lan_l3)"

      if confirm_default_yes "$(tr_msg confirm_lan_nat)"; then
        LAN_NAT="1"
      else
        LAN_NAT="0"
      fi

      CLIENT_ALLOWED_DEFAULT="${WG_CIDR}, ${LAN_CIDR}"

      local lan_gw
      lan_gw="$(detect_lan_gateway)"
      panel "$BLUE" "$(tr_msg dns_title)" \
        "$(tr_msg dns_l1)" \
        "$(tr_msg dns_l2)" \
        "$(tr_msg dns_l3)"
      if [[ -n "$lan_gw" ]] && confirm_default_yes "$(tr_fmt confirm_dns_gw "$lan_gw")"; then
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
      CLIENT_DNS_DEFAULT="$(prompt_default "$(tr_msg prompt_client_dns_profile)" "1.1.1.1, 9.9.9.9")"

      panel "$AMBER" "$(tr_msg full_title)" \
        "$(tr_msg full_l1)" \
        "$(tr_msg full_l2)" \
        "$(tr_msg full_l3)"

      if ! confirm_default_no "$(tr_msg confirm_full)"; then
        die "$(tr_msg err_install_cancelled)"
      fi
      ;;
    *)
      die "$(tr_fmt err_invalid_choice_value "$choice")"
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
    warn "$(tr_fmt dns_not_resolving "$host")"
  elif [[ "$resolved" == "$public_ip" ]]; then
    success "$(tr_fmt dns_points_here "$host" "$resolved")"
  else
    warn "$(tr_fmt dns_points_elsewhere "$host" "$resolved" "$public_ip")"
    info "$(tr_fmt dns_check_record "$host")"
  fi
}

configure_endpoint() {
  local detected_public_ip="$1"
  local value

  panel "$BLUE" "$(tr_msg endpoint_title)" \
    "$(tr_msg endpoint_l1)" \
    "$(tr_msg endpoint_l2)"

  if [[ -n "$detected_public_ip" ]] && is_cgnat_ip "$detected_public_ip"; then
    panel "$AMBER" "$(tr_msg cgnat_title)" \
      "$(tr_fmt cgnat_l1 "${BOLD}${detected_public_ip}${RESET}")" \
      "$(tr_msg cgnat_l2)" \
      "$(tr_msg cgnat_l3)" \
      "$(tr_msg cgnat_l4)" \
      "$(tr_msg cgnat_l5)"
  fi

  echo
  if [[ -n "$detected_public_ip" ]]; then
    value="$(prompt_default "$(tr_msg prompt_endpoint)" "$detected_public_ip")"
  else
    value="$(prompt_free "$(tr_msg prompt_endpoint)")"
  fi
  [[ -n "$value" ]] || die "$(tr_msg err_endpoint_required)"

  if ! validate_endpoint_host "$value"; then
    warn "$(tr_fmt warn_endpoint_shape "$value")"
    if ! confirm_default_no "$(tr_msg confirm_keep_value)"; then
      die "$(tr_msg err_endpoint_invalid)"
    fi
  fi

  ENDPOINT_HOST="$value"
  verify_endpoint_domain "$ENDPOINT_HOST" "$detected_public_ip"
}

install_or_reconfigure_server() {
  require_root
  banner

  panel "$RED" "$(tr_msg install_title)" \
    "$(tr_msg install_l1)" \
    "$(tr_fmt install_l2 "${BOLD}${WG_IF}${RESET}")" \
    "$(tr_msg install_l3)"

  check_tun_or_explain

  if [[ -f "$WG_CONF" ]]; then
    panel "$AMBER" "$(tr_msg exists_title)" \
      "$(tr_fmt exists_l1 "${CYAN}${WG_CONF}${RESET}")" \
      "$(tr_msg exists_l2)" \
      "$(tr_msg exists_l3)"

    if ! confirm_default_no "$(tr_msg confirm_reconfigure)"; then
      die "$(tr_msg err_cancelled)"
    fi
  fi

  local detected_public_ip detected_out_if detected_lxc_ip detected_lan
  detected_public_ip="$(detect_public_ip || true)"
  detected_out_if="$(detect_default_interface || true)"
  detected_out_if="${detected_out_if:-eth0}"
  detected_lxc_ip="$(detect_lxc_ip "$detected_out_if")"
  detected_lan="$(detect_lan_cidr "$detected_out_if")"

  panel "$BLUE" "$(tr_msg detect_title)" \
    "$(tr_fmt detect_public_ip "${BOLD}${detected_public_ip:-$(tr_msg value_not_detected_f)}${RESET}")" \
    "$(tr_fmt detect_iface "${BOLD}${detected_out_if}${RESET}")" \
    "$(tr_fmt detect_lxc_ip "${BOLD}${detected_lxc_ip:-$(tr_msg value_not_detected_f)}${RESET}")" \
    "$(tr_fmt detect_lan "${BOLD}${detected_lan}${RESET}")"

  configure_endpoint "$detected_public_ip"

  LISTEN_PORT="$(prompt_default "$(tr_msg prompt_port)" "$DEFAULT_PORT")"
  validate_port "$LISTEN_PORT"

  if port_in_use "$LISTEN_PORT"; then
    if [[ -f "$WG_CONF" ]]; then
      info "$(tr_fmt port_busy_self "$LISTEN_PORT")"
    else
      warn "$(tr_fmt port_busy_other "$LISTEN_PORT")"
      if ! confirm_default_no "$(tr_msg confirm_port_anyway)"; then
        die "$(tr_msg err_pick_other_port)"
      fi
    fi
  fi

  OUT_IF="$(prompt_default "$(tr_msg prompt_out_if)" "$detected_out_if")"
  [[ -n "$OUT_IF" ]] || die "$(tr_msg err_out_if_required)"

  LXC_IP="$(detect_lxc_ip "$OUT_IF")"
  LXC_IP="${LXC_IP:-$detected_lxc_ip}"

  WG_CIDR="$(prompt_default "$(tr_msg prompt_wg_cidr)" "$DEFAULT_WG_CIDR")"
  validate_wireguard_cidr24 "$WG_CIDR"
  WG_PREFIX="$(cidr24_prefix "$WG_CIDR")"

  WG_SERVER_IP="$(prompt_default "$(tr_msg prompt_wg_server_ip)" "${WG_PREFIX}.1")"
  validate_server_ip_in_cidr24 "$WG_SERVER_IP" "$WG_PREFIX"

  CLIENT_RANGE_START="$(prompt_default "$(tr_msg prompt_range_start)" "$DEFAULT_CLIENT_RANGE_START")"
  CLIENT_RANGE_END="$(prompt_default "$(tr_msg prompt_range_end)" "$DEFAULT_CLIENT_RANGE_END")"
  validate_range "$CLIENT_RANGE_START" "$CLIENT_RANGE_END"

  choose_mode

  panel "$AMBER" "$(tr_msg fwd_title)" \
    "$(tr_msg fwd_l1)" \
    "$(tr_fmt fwd_ext_port "${BOLD}${LISTEN_PORT}/UDP${RESET}")" \
    "$(tr_fmt fwd_dest "${BOLD}${LXC_IP:-$(tr_msg placeholder_lxc_ip)}:${LISTEN_PORT}${RESET}")" \
    "$(tr_fmt fwd_endpoint "${BOLD}${ENDPOINT_HOST}:${LISTEN_PORT}${RESET}")"

  if [[ "$INSTALL_MODE" == "lan" && "$LAN_NAT" == "0" ]]; then
    panel "$AMBER" "$(tr_msg route_title)" \
      "$(tr_msg route_l1)" \
      "$(tr_fmt route_dest "${BOLD}${WG_CIDR}${RESET}")" \
      "$(tr_fmt route_gw "${BOLD}${LXC_IP:-$(tr_msg placeholder_lxc_ip)}${RESET}")" \
      "$(tr_msg route_l2)"
  fi

  panel "$RED" "$(tr_msg summary_title)" \
    "$(tr_fmt sum_endpoint "${BOLD}${ENDPOINT_HOST}:${LISTEN_PORT}${RESET}")" \
    "$(tr_fmt sum_lxc "${BOLD}${LXC_IP:-$(tr_msg value_not_detected_m)}${RESET}")" \
    "$(tr_fmt sum_wan "${BOLD}${OUT_IF}${RESET}")" \
    "$(tr_fmt sum_wg_net "${BOLD}${WG_CIDR}${RESET}")" \
    "$(tr_fmt sum_wg_srv "${BOLD}${WG_SERVER_IP}${RESET}")" \
    "$(tr_fmt sum_mode "${BOLD}${INSTALL_MODE}${RESET}")" \
    "$(tr_fmt sum_allowed "${CYAN}${CLIENT_ALLOWED_DEFAULT}${RESET}")"

  echo
  if ! confirm_default_yes "$(tr_msg confirm_install_now)"; then
    die "$(tr_msg err_cancelled)"
  fi

  local ts backup_conf peers_tmp keep_peers
  ts="$(date +%F_%H%M%S)"
  backup_conf="${WG_CONF}.bak.${ts}"
  peers_tmp="$(mktemp)"
  keep_peers="0"

  if [[ -f "$WG_CONF" ]]; then
    cp -a "$WG_CONF" "$backup_conf"
    if confirm_default_yes "$(tr_msg confirm_keep_peers)"; then
      keep_peers="1"
      extract_peer_blocks "$backup_conf" > "$peers_tmp"
    fi
  fi

  step "$(tr_msg step_packages)" install_packages || die "$(tr_msg err_packages)"
  step "$(tr_msg step_keys)" generate_or_reuse_server_keys || die "$(tr_msg err_keys)"
  step "$(tr_msg step_pubkey)" ensure_server_public_key_file || die "$(tr_msg err_pubkey)"
  step "$(tr_msg step_sysctl)" configure_sysctl || die "$(tr_msg err_sysctl)"

  if [[ "$keep_peers" == "1" ]]; then
    step "$(tr_fmt step_write_conf_keep "$WG_CONF")" write_server_config "$peers_tmp" || die "$(tr_msg err_write_conf)"
  else
    step "$(tr_fmt step_write_conf "$WG_CONF")" write_server_config "" || die "$(tr_msg err_write_conf)"
  fi

  if [[ "$INSTALL_MODE" == "private" ]]; then
    step "$(tr_msg step_nft_disable)" disable_nft_rules || true
    rm -f "$NFT_FILE"
  elif [[ "$INSTALL_MODE" == "lan" && "$LAN_NAT" == "0" ]]; then
    step "$(tr_msg step_nft_lan)" write_nft_config "0" || die "$(tr_msg err_nft_write)"
    step "$(tr_msg step_nft_unit)" write_nft_unit || die "$(tr_msg err_nft_unit)"
    step "$(tr_msg step_nft_enable)" enable_nft_rules || die "$(tr_msg err_nft_enable)"
  else
    step "$(tr_msg step_nft_nat)" write_nft_config "1" || die "$(tr_msg err_nft_write)"
    step "$(tr_msg step_nft_unit)" write_nft_unit || die "$(tr_msg err_nft_unit)"
    step "$(tr_msg step_nft_enable)" enable_nft_rules || die "$(tr_msg err_nft_enable)"
  fi

  step "$(tr_msg step_wg_enable)" systemctl enable --now "wg-quick@${WG_IF}" || die "$(tr_msg err_wg_enable)"

  save_state
  rm -f "$peers_tmp"
  prune_conf_backups

  panel "$GREEN" "$(tr_msg done_title)" \
    "$(tr_fmt done_iface "${BOLD}${WG_IF}${RESET}")" \
    "$(tr_fmt done_addr "${BOLD}${WG_SERVER_IP}${RESET}")" \
    "$(tr_fmt done_port "${BOLD}${LISTEN_PORT}${RESET}")" \
    "$(tr_fmt done_endpoint "${BOLD}${ENDPOINT_HOST}:${LISTEN_PORT}${RESET}")" \
    "$(tr_fmt done_state "${CYAN}${STATE_FILE}${RESET}")"

  show_port_forwarding_help

  echo
  if confirm_default_yes "$(tr_msg confirm_first_client)"; then
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
    [[ "$raw" == */32 ]] || die "$(tr_msg err_client_ip_slash32)"
    raw="${raw%/32}"
  fi

  printf "%s" "$raw"
}

validate_client_ip() {
  local ipaddr="$1"
  local octet server_last

  validate_ipv4 "$ipaddr" || die "$(tr_fmt err_client_ip_invalid "$ipaddr")"
  [[ "$ipaddr" == "${WG_PREFIX}."* ]] || die "$(tr_fmt err_client_ip_not_in_net "$WG_PREFIX")"

  octet="$(awk -F. '{print $4}' <<< "$ipaddr")"
  server_last="$(awk -F. '{print $4}' <<< "$WG_SERVER_IP")"

  ((octet >= 2 && octet <= 254)) || die "$(tr_fmt err_client_ip_bounds "$ipaddr")"

  if [[ "$octet" == "$server_last" ]]; then
    die "$(tr_msg err_client_ip_is_server)"
  fi

  if is_used_octet "$octet"; then
    die "$(tr_fmt err_client_ip_used "$WG_CONF" "${ipaddr}/32")"
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

  panel "$AMBER" "$(tr_msg client_exists_title)" \
    "$(tr_fmt client_exists_l1 "${BOLD}${NAME}${RESET}")" \
    "$(tr_msg client_exists_l2)"

  [[ -e "$KEY_FILE" ]] && warn "$KEY_FILE"
  [[ -e "$PUB_FILE" ]] && warn "$PUB_FILE"
  [[ -e "$PSK_FILE" ]] && warn "$PSK_FILE"
  [[ -e "$CONF_FILE" ]] && warn "$CONF_FILE"
  client_has_server_block && warn "$(tr_fmt client_server_block "$WG_CONF" "$NAME")"

  echo
  if confirm_default_yes "$(tr_msg confirm_overwrite_client)"; then
    OVERWRITE_CLIENT="1"
  else
    die "$(tr_msg err_overwrite_refused)"
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
    if [[ -n "${CLIENT_MTU:-}" ]]; then
      echo "MTU = ${CLIENT_MTU}"
    fi
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
  if confirm_default_yes "$(tr_msg confirm_show_conf)"; then
    echo
    panel "$AMBER" "$(tr_msg secret_title)" \
      "$(tr_msg secret_l1)" \
      "$(tr_msg secret_l2)" \
      "$(tr_fmt secret_client "${BOLD}${NAME}${RESET}")" \
      "$(tr_fmt secret_file "${CYAN}${CONF_FILE}${RESET}")"
    echo
    printf "%b%s%b\n" "${RED_DARK}" "$(tr_msg sep_copy_from)" "${RESET}"
    cat "$CONF_FILE"
    printf "%b%s%b\n" "${RED_DARK}" "$(tr_msg sep_copy_to)" "${RESET}"
  fi
}

show_qr_if_requested() {
  if ! have qrencode; then
    return 0
  fi

  echo
  if confirm_default_yes "$(tr_msg confirm_show_qr)"; then
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
  [[ -f "$WG_CONF" ]] || die "$(tr_fmt err_server_not_configured "$WG_CONF")"
  if ((state_existed == 0)); then
    warn "$(tr_msg warn_no_saved_state)"
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
      ENDPOINT_HOST="$(prompt_default "$(tr_msg prompt_endpoint)" "$detected_ip")"
    else
      ENDPOINT_HOST="$(prompt_free "$(tr_msg prompt_endpoint)")"
    fi
    [[ -n "$ENDPOINT_HOST" ]] || die "$(tr_msg err_endpoint_required)"
    verify_endpoint_domain "$ENDPOINT_HOST" "$detected_ip"
  fi

  CLIENT_ALLOWED_DEFAULT="${CLIENT_ALLOWED_DEFAULT:-$WG_CIDR}"
  CLIENT_RANGE_START="${CLIENT_RANGE_START:-$DEFAULT_CLIENT_RANGE_START}"
  CLIENT_RANGE_END="${CLIENT_RANGE_END:-$DEFAULT_CLIENT_RANGE_END}"
  DEFAULT_KEEPALIVE="${DEFAULT_KEEPALIVE:-25}"
  DEFAULT_MTU="${DEFAULT_MTU:-1420}"

  SERVER_PUB="$(get_server_public_key)"

  banner
  panel "$RED" "$(tr_msg addclient_title)" \
    "$(tr_msg addclient_l1)" \
    "$(tr_msg addclient_l2)" \
    "$(tr_fmt addclient_l3 "${BOLD}${ENDPOINT_HOST}:${LISTEN_PORT}${RESET}")"

  echo
  NAME="$(prompt_free "$(tr_msg prompt_client_name)")"
  NAME="${NAME:-}"

  [[ -n "$NAME" ]] || die "$(tr_msg err_name_empty)"
  if ! grep -Eq '^[a-zA-Z0-9._-]+$' <<< "$NAME"; then
    die "$(tr_msg err_name_invalid)"
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
  free_octet="$(find_free_octet)" || die "$(tr_fmt err_no_free_ip "${WG_PREFIX}.${CLIENT_RANGE_START}-${CLIENT_RANGE_END}")"
  auto_ip="${WG_PREFIX}.${free_octet}"

  echo
  raw_ip="$(prompt_default "$(tr_msg prompt_client_ip)" "$auto_ip")"
  raw_ip="$(normalize_ip_host "$raw_ip")"
  validate_client_ip "$raw_ip"
  CLIENT_IP="${raw_ip}/32"

  echo
  CLIENT_ALLOWED="$(prompt_default "$(tr_msg prompt_allowed)" "$CLIENT_ALLOWED_DEFAULT")"
  CLIENT_KEEPALIVE="$(prompt_default "$(tr_msg prompt_keepalive)" "$DEFAULT_KEEPALIVE")"

  if [[ -n "${CLIENT_DNS_DEFAULT:-}" ]]; then
    CLIENT_DNS="$(prompt_default "$(tr_msg prompt_client_dns)" "$CLIENT_DNS_DEFAULT")"
  else
    CLIENT_DNS="$(prompt_default "$(tr_msg prompt_client_dns_empty)" "")"
  fi

  CLIENT_MTU="$(prompt_default "$(tr_msg prompt_mtu)" "$DEFAULT_MTU")"

  [[ "$CLIENT_KEEPALIVE" =~ ^[0-9]+$ ]] || die "$(tr_msg err_keepalive_number)"
  [[ "$CLIENT_MTU" =~ ^[0-9]+$ ]] || die "$(tr_msg err_mtu_number)"
  ((CLIENT_MTU >= 1280 && CLIENT_MTU <= 1500)) || die "$(tr_fmt err_mtu_range "$CLIENT_MTU")"

  if [[ "$CLIENT_ALLOWED" == *"0.0.0.0/0"* || "$CLIENT_ALLOWED" == *"::/0"* ]]; then
    panel "$AMBER" "$(tr_msg fullprofile_title)" \
      "$(tr_msg fullprofile_l1)" \
      "$(tr_msg fullprofile_l2)"
    if ! confirm_default_yes "$(tr_msg confirm_keep_allowed)"; then
      die "$(tr_msg err_cancelled)"
    fi
  fi

  local ts
  ts="$(date +%F_%H%M%S)"
  BACKUP_FILE="${WG_CONF}.bak.${ts}"
  CLIENT_BACKUP_DIR="${CLIENT_DIR}/.backup-${NAME}-${ts}"

  panel "$RED" "$(tr_msg client_summary_title)" \
    "$(tr_fmt cs_name "${BOLD}${NAME}${RESET}")" \
    "$(tr_fmt cs_ip "${BOLD}${CLIENT_IP}${RESET}")" \
    "$(tr_fmt cs_endpoint "${BOLD}${ENDPOINT_HOST}:${LISTEN_PORT}${RESET}")" \
    "$(tr_fmt cs_allowed "${CYAN}${CLIENT_ALLOWED}${RESET}")" \
    "$(tr_fmt cs_dns "${CYAN}${CLIENT_DNS:-$(tr_msg value_none)}${RESET}")" \
    "$(tr_fmt cs_mtu "${CYAN}${CLIENT_MTU}${RESET}")" \
    "$(tr_fmt cs_file "${CYAN}${CONF_FILE}${RESET}")"

  echo
  if ! confirm_default_yes "$(tr_msg confirm_create_client)"; then
    die "$(tr_msg err_cancelled)"
  fi

  step "$(tr_msg step_backup_client)" backup_existing_client_files || die "$(tr_msg err_backup_client)"
  step "$(tr_msg step_prepare_conf)" prepare_server_config_for_client || die "$(tr_msg err_prepare_conf)"
  step "$(tr_msg step_gen_client_keys)" generate_client_files || die "$(tr_msg err_gen_client_keys)"
  step "$(tr_msg step_write_client)" write_client_config || die "$(tr_msg err_write_client)"
  step "$(tr_msg step_append_peer)" append_server_peer || die "$(tr_msg err_append_peer)"
  step "$(tr_msg step_apply_conf)" apply_client_or_rollback || die "$(tr_msg err_apply_conf)"

  prune_conf_backups

  if ((state_existed == 0)); then
    if save_state; then
      success "$(tr_fmt state_saved "$STATE_FILE")"
    fi
  fi

  panel "$GREEN" "$(tr_msg client_ready_title)" \
    "$(tr_fmt cs_name "${BOLD}${NAME}${RESET}")" \
    "$(tr_fmt cs_ip "${BOLD}${CLIENT_IP}${RESET}")" \
    "$(tr_fmt cr_conf "${CYAN}${CONF_FILE}${RESET}")" \
    "$(tr_fmt cr_privkey "${CYAN}${KEY_FILE}${RESET}")" \
    "$(tr_fmt cr_pubkey "${CYAN}${PUB_FILE}${RESET}")" \
    "$(tr_fmt cr_psk "${CYAN}${PSK_FILE}${RESET}")" \
    "$(tr_fmt cr_backup "${CYAN}${BACKUP_FILE}${RESET}")"

  show_client_config_if_requested
  show_qr_if_requested

  echo
  info "$(tr_fmt current_state_of "$WG_IF")"
  echo
  wg show "$WG_IF"
}

# ── Liste / gestion / diagnostic ──────────────────────────────────────────────

read_conf_peer_names_in_order() {
  [[ -f "$WG_CONF" ]] || return 0
  awk '
    function trim(s) { sub(/^[[:space:]]*#[[:space:]]*/, "", s); sub(/[[:space:]]+$/, "", s); return s }
    /^[[:space:]]*#[[:space:]]*[^[:space:]]/ { print trim($0) }
  ' "$WG_CONF" 2>/dev/null || true
}

get_client_names() {
  [[ -d "$CLIENT_DIR" ]] || return 0

  # Ensemble des clients connus (ceux qui ont un fichier .conf).
  local f name known_list=" "
  local -a known=()
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    known+=("$name")
    known_list+="${name} "
  done < <(
    shopt -s nullglob
    for f in "$CLIENT_DIR"/*.conf; do
      basename "${f%.conf}"
    done
  )

  ((${#known[@]} > 0)) || return 0

  # 1) Dans l'ordre d'apparition des marqueurs « # nom » du wg0.conf.
  local emitted=" "
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    [[ "$known_list" == *" ${name} "* ]] || continue
    [[ "$emitted" == *" ${name} "* ]] && continue
    emitted+="${name} "
    printf "%s\n" "$name"
  done < <(read_conf_peer_names_in_order)

  # 2) Clients connus mais absents du wg0.conf : à la fin, triés.
  local -a rest=()
  for name in "${known[@]}"; do
    [[ "$emitted" == *" ${name} "* ]] || rest+=("$name")
  done
  ((${#rest[@]} == 0)) || printf "%s\n" "${rest[@]}" | sort
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

  sel="$(prompt_free "$(tr_msg prompt_client_pick)")"
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
    panel "$AMBER" "$(tr_msg noclient_title)" \
      "$(tr_msg noclient_l1)" \
      "$(tr_msg noclient_l2)"
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
      state="${GRAY}$(tr_msg state_unknown)${RESET}"
    else
      hs="${HS[$pub]:-0}"
      if [[ "$hs" =~ ^[0-9]+$ ]] && ((hs > 0)) && ((now - hs < 180)); then
        state="${GREEN}$(tr_msg state_connected)${RESET}"
      elif [[ "$hs" =~ ^[0-9]+$ ]] && ((hs > 0)); then
        state="${GRAY}$(tr_fmt state_seen "$(human_since "$((now - hs))")")${RESET}"
      else
        state="${GRAY}$(tr_msg state_never)${RESET}"
      fi
    fi

    rows+=("$(printf "%b%-20s%b %-16s %s" "$BOLD" "$name" "$RESET" "${ip:-?}" "$state")")
  done

  panel "$RED" "$(tr_fmt clients_title "${#names[@]}")" "${rows[@]}"
  info "$(tr_msg clients_hint)"
}

show_existing_client() {
  require_root
  load_state || true
  banner

  panel "$RED" "$(tr_msg show_title)" \
    "$(tr_msg show_l1)" \
    "$(tr_msg show_l2)"

  local name conf
  if ! name="$(choose_existing_client)"; then
    warn "$(tr_msg warn_no_client_show)"
    return 0
  fi

  conf="${CLIENT_DIR}/${name}.conf"
  [[ -f "$conf" ]] || die "$(tr_fmt err_file_not_found "$conf")"

  echo
  panel "$AMBER" "$(tr_msg secret_title)" \
    "$(tr_msg secret_l1)" \
    "$(tr_msg secret_l2)" \
    "$(tr_fmt secret_client "${BOLD}${name}${RESET}")" \
    "$(tr_fmt secret_file "${CYAN}${conf}${RESET}")"
  echo
  printf "%b%s%b\n" "${RED_DARK}" "$(tr_msg sep_copy_from)" "${RESET}"
  cat "$conf"
  printf "%b%s%b\n" "${RED_DARK}" "$(tr_msg sep_copy_to)" "${RESET}"

  if have qrencode; then
    echo
    if confirm_default_yes "$(tr_msg confirm_show_qr)"; then
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

  panel "$RED" "$(tr_msg revoke_title)" \
    "$(tr_msg revoke_l1)" \
    "$(tr_msg revoke_l2)"

  [[ -f "$WG_CONF" ]] || die "$(tr_fmt err_server_not_configured "$WG_CONF")"

  local name
  if ! name="$(choose_existing_client)"; then
    warn "$(tr_msg warn_no_client_delete)"
    return 0
  fi

  echo
  if ! confirm_default_no "$(tr_fmt confirm_delete_client "$name")"; then
    warn "$(tr_msg warn_delete_cancelled)"
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
    sync_wireguard || warn "$(tr_msg warn_hot_sync_failed)"
  fi

  prune_conf_backups

  panel "$GREEN" "$(tr_msg removed_title)" \
    "$(tr_fmt removed_client "${BOLD}${name}${RESET}")" \
    "$(tr_fmt removed_conf "${CYAN}${conf_backup}${RESET}")" \
    "$(tr_fmt removed_files "${CYAN}${backup_dir}${RESET}")"
}

run_diagnostic() {
  require_root
  banner
  load_state || true

  WG_CIDR="${WG_CIDR:-$DEFAULT_WG_CIDR}"
  LISTEN_PORT="${LISTEN_PORT:-$DEFAULT_PORT}"
  OUT_IF="${OUT_IF:-$(detect_default_interface || true)}"
  LXC_IP="${LXC_IP:-$(detect_lxc_ip "$OUT_IF")}"
  ENDPOINT_HOST="${ENDPOINT_HOST:-$(tr_msg value_undefined)}"
  INSTALL_MODE="${INSTALL_MODE:-$(tr_msg value_unknown)}"

  panel "$RED" "$(tr_msg diag_title)" \
    "$(tr_msg diag_l1)" \
    "$(tr_fmt diag_mode "${BOLD}${INSTALL_MODE}${RESET}")"

  echo

  if systemctl is-active --quiet "wg-quick@${WG_IF}"; then
    success "$(tr_fmt diag_service_ok "$WG_IF")"
  else
    error "$(tr_msg diag_service_ko)"
  fi

  if have ss && ss -lun 2>/dev/null | grep -qE "[:.]${LISTEN_PORT}([^0-9]|\$)"; then
    success "$(tr_fmt diag_port_ok "$LISTEN_PORT")"
  else
    warn "$(tr_fmt diag_port_ko "$LISTEN_PORT")"
  fi

  local ipf
  ipf="$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo 0)"
  if [[ "$ipf" == "1" ]]; then
    success "$(tr_msg diag_fwd_ok)"
  elif [[ "$INSTALL_MODE" == "private" ]]; then
    info "$(tr_msg diag_fwd_private)"
  else
    warn "$(tr_fmt diag_fwd_ko "$INSTALL_MODE")"
  fi

  if [[ "$INSTALL_MODE" != "private" && "$INSTALL_MODE" != "inconnu" ]]; then
    if have nft && nft list table inet wg_server >/dev/null 2>&1; then
      success "$(tr_msg diag_nft_ok)"
    else
      warn "$(tr_fmt diag_nft_ko "$INSTALL_MODE")"
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
    info "$(tr_msg diag_no_client)"
  else
    success "$(tr_fmt diag_clients "$total" "$connected")"
    if ((connected == 0)); then
      info "$(tr_msg diag_zero_ok)"
    fi
  fi

  echo
  panel "$AMBER" "$(tr_msg remember_title)" \
    "$(tr_fmt remember_endpoint "${BOLD}${ENDPOINT_HOST}:${LISTEN_PORT}${RESET}")" \
    "$(tr_fmt remember_fwd "${BOLD}${LISTEN_PORT}/UDP${RESET}" "${BOLD}${LXC_IP:-$(tr_msg placeholder_lxc_ip)}${RESET}")" \
    "$(tr_msg remember_l1)" \
    "$(tr_msg remember_l2)"

  echo
  if confirm_default_no "$(tr_msg confirm_raw_details)"; then
    echo
    if have wg; then
      wg show "$WG_IF" || true
    fi
    echo
    systemctl status "wg-quick@${WG_IF}" --no-pager 2>/dev/null || true
  fi
}

backup_config() {
  require_root
  banner

  panel "$RED" "$(tr_msg backup_title)" \
    "$(tr_fmt backup_l1 "${CYAN}${WG_DIR}${RESET}")" \
    "$(tr_msg backup_l2)"

  [[ -d "$WG_DIR" ]] || die "$(tr_fmt err_nothing_to_backup "$WG_DIR")"

  local ts dest parent base
  ts="$(date +%F_%H%M%S)"
  echo
  dest="$(prompt_default "$(tr_msg prompt_archive_create)" "/root/wireguard-backup-${ts}.tar.gz")"
  [[ -n "$dest" ]] || die "$(tr_msg err_empty_path)"

  parent="$(dirname "$WG_DIR")"
  base="$(basename "$WG_DIR")"

  step "$(tr_msg step_create_archive)" tar -czf "$dest" -C "$parent" "$base" || die "$(tr_msg err_backup_failed)"
  chmod 600 "$dest" 2>/dev/null || true

  panel "$GREEN" "$(tr_msg backup_done_title)" \
    "$(tr_fmt backup_done_file "${CYAN}${dest}${RESET}")" \
    "$(tr_msg backup_done_content)" \
    "$(tr_fmt backup_done_fetch "${DIM}scp root@$(tr_msg placeholder_lxc_ip):${dest} .${RESET}")"
}

restore_config() {
  require_root
  banner

  panel "$AMBER" "$(tr_msg restore_title)" \
    "$(tr_fmt restore_l1 "${CYAN}${WG_DIR}${RESET}")" \
    "$(tr_msg restore_l2)"

  local src base parent
  echo
  src="$(prompt_free "$(tr_msg prompt_archive_restore)")"
  [[ -n "$src" ]] || die "$(tr_msg err_empty_path)"
  [[ -f "$src" ]] || die "$(tr_fmt err_archive_not_found "$src")"

  base="$(basename "$WG_DIR")"
  parent="$(dirname "$WG_DIR")"

  if ! tar -tzf "$src" 2>/dev/null | grep -qE "(^|/)${base}/wg0\.conf\$"; then
    die "$(tr_fmt err_archive_invalid "$base")"
  fi

  echo
  if ! confirm_default_no "$(tr_fmt confirm_restore "$WG_DIR")"; then
    die "$(tr_msg err_cancelled)"
  fi

  local ts safety=""
  ts="$(date +%F_%H%M%S)"
  if [[ -d "$WG_DIR" ]]; then
    safety="$(dirname "$src")/wireguard-avant-restauration-${ts}.tar.gz"
    if ! tar -czf "$safety" -C "$parent" "$base" 2>/dev/null; then
      safety=""
    fi
    if [[ -n "$safety" ]]; then
      info "$(tr_fmt current_saved "${CYAN}${safety}${RESET}")"
    fi
  fi

  local was_active=0
  if systemctl is-active --quiet "wg-quick@${WG_IF}"; then
    was_active=1
    step "$(tr_msg step_stop_wg)" systemctl stop "wg-quick@${WG_IF}" || true
  fi

  rm -rf "$WG_DIR"
  if ! tar -xzf "$src" -C "$parent" 2>/dev/null; then
    error "$(tr_msg err_extract)"
    if [[ -n "$safety" && -f "$safety" ]]; then
      rm -rf "$WG_DIR"
      tar -xzf "$safety" -C "$parent" 2>/dev/null || true
      warn "$(tr_msg warn_old_restored)"
    fi
    die "$(tr_msg err_restore_failed)"
  fi
  chmod 700 "$WG_DIR" 2>/dev/null || true

  success "$(tr_fmt restore_ok "$src")"

  if [[ -f "$NFT_FILE" && -f "$NFT_UNIT" ]]; then
    systemctl restart wg-server-nft.service >/dev/null 2>&1 || true
  fi

  if ((was_active == 1)); then
    step "$(tr_msg step_restart_wg)" systemctl start "wg-quick@${WG_IF}" || warn "$(tr_msg warn_wg_no_restart)"
  else
    info "$(tr_fmt hint_enable_wg "$WG_IF")"
  fi

  panel "$GREEN" "$(tr_msg restore_done_title)" \
    "$(tr_fmt restore_src "${CYAN}${src}${RESET}")" \
    "$(tr_fmt restore_dst "${CYAN}${WG_DIR}${RESET}")"
}

manage_backup() {
  require_root
  banner

  panel "$RED" "$(tr_msg backupmenu_title)" \
    "$(tr_msg backupmenu_1)" \
    "$(tr_msg backupmenu_2)" \
    "$(tr_msg backupmenu_3)"

  local choice
  choice="$(prompt_default "$(tr_msg prompt_choice)" "1")"

  case "$choice" in
    1) backup_config ;;
    2) restore_config ;;
    3) return 0 ;;
    *) warn "$(tr_msg warn_invalid_choice)" ;;
  esac
}

uninstall_server() {
  require_root
  banner

  panel "$AMBER" "$(tr_msg uninstall_title)" \
    "$(tr_msg uninstall_l1)" \
    "$(tr_msg uninstall_l2)"

  echo
  if ! confirm_default_no "$(tr_msg confirm_uninstall)"; then
    warn "$(tr_msg warn_uninstall_cancelled)"
    return 0
  fi

  systemctl disable --now "wg-quick@${WG_IF}" >/dev/null 2>&1 || true
  success "$(tr_msg ok_service_stopped)"

  disable_nft_rules
  rm -f "$NFT_FILE" "$NFT_UNIT"
  success "$(tr_msg ok_nft_removed)"

  rm -f /etc/sysctl.d/99-wireguard-server.conf
  sysctl --system >/dev/null 2>&1 || true
  systemctl daemon-reload || true
  success "$(tr_msg ok_fwd_removed)"

  echo
  panel "$AMBER" "$(tr_msg purge_title)" \
    "$(tr_fmt purge_l1 "${CYAN}${WG_DIR}${RESET}")" \
    "$(tr_msg purge_l2)"

  if confirm_default_no "$(tr_fmt confirm_purge "$WG_DIR")"; then
    rm -rf "$WG_DIR"
    success "$(tr_msg ok_purged)"
  else
    info "$(tr_fmt info_kept "$WG_DIR")"
  fi

  echo
  if have apt-get && confirm_default_no "$(tr_msg confirm_remove_packages)"; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get remove -y wireguard-tools qrencode >/dev/null 2>&1 || true
    success "$(tr_msg ok_packages_removed)"
  fi

  panel "$GREEN" "$(tr_msg uninstall_done_title)" \
    "$(tr_msg uninstall_done_l1)"
}

# ── Aide ──────────────────────────────────────────────────────────────────────

show_port_forwarding_help() {
  load_state || true

  local out_if lxc_ip port endpoint
  out_if="${OUT_IF:-$(detect_default_interface || true)}"
  lxc_ip="${LXC_IP:-$(detect_lxc_ip "$out_if")}"
  port="${LISTEN_PORT:-$DEFAULT_PORT}"
  endpoint="${ENDPOINT_HOST:-$(tr_msg placeholder_endpoint)}"

  panel "$AMBER" "$(tr_msg help_fwd_title)" \
    "$(tr_msg help_fwd_l1)" \
    "$(tr_fmt help_proto "${BOLD}UDP${RESET}")" \
    "$(tr_fmt help_ext_port "${BOLD}${port}${RESET}")" \
    "$(tr_fmt help_dest_ip "${BOLD}${lxc_ip:-$(tr_msg placeholder_lxc_ip)}${RESET}")" \
    "$(tr_fmt help_dest_port "${BOLD}${port}${RESET}")" \
    "$(tr_fmt help_endpoint "${BOLD}${endpoint}:${port}${RESET}")"

  warn "$(tr_msg warn_ip_change)"
  warn "$(tr_msg warn_fixed_ip)"
}

show_theory_summary() {
  panel "$BLUE" "$(tr_msg theory_title)" \
    "$(tr_msg theory_l1)" \
    "$(tr_msg theory_l2)" \
    "$(tr_msg theory_l3)" \
    "$(tr_msg theory_l4)"

  panel "$BLUE" "$(tr_msg modes_title)" \
    "$(tr_msg modes_1)" \
    "$(tr_msg modes_2)" \
    "$(tr_msg modes_3)"
}

main_menu() {
  require_root

  while true; do
    banner
    show_theory_summary

    echo
    printf "%b1%b) %s\n" "${RED_SOFT}" "${RESET}" "$(tr_msg menu_1)"
    printf "%b2%b) %s\n" "${RED_SOFT}" "${RESET}" "$(tr_msg menu_2)"
    printf "%b3%b) %s\n" "${RED_SOFT}" "${RESET}" "$(tr_msg menu_3)"
    printf "%b4%b) %s\n" "${RED_SOFT}" "${RESET}" "$(tr_msg menu_4)"
    printf "%b5%b) %s\n" "${RED_SOFT}" "${RESET}" "$(tr_msg menu_5)"
    printf "%b6%b) %s\n" "${RED_SOFT}" "${RESET}" "$(tr_msg menu_6)"
    printf "%b7%b) %s\n" "${RED_SOFT}" "${RESET}" "$(tr_msg menu_7)"
    printf "%b8%b) %s\n" "${RED_SOFT}" "${RESET}" "$(tr_msg menu_8)"
    printf "%b9%b) %s\n" "${RED_SOFT}" "${RESET}" "$(tr_msg menu_9)"
    printf "%b10%b) %s\n" "${RED_SOFT}" "${RESET}" "$(tr_msg menu_10)"
    echo

    local choice
    choice="$(prompt_default "$(tr_msg prompt_choice)" "1")"

    case "$choice" in
      1) install_or_reconfigure_server ;;
      2) add_or_regenerate_client ;;
      3) list_clients ;;
      4) show_existing_client ;;
      5) revoke_client ;;
      6) run_diagnostic ;;
      7) banner; show_port_forwarding_help ;;
      8) manage_backup ;;
      9) uninstall_server ;;
      10) echo; success "$(tr_msg bye)"; exit 0 ;;
      *) warn "$(tr_msg warn_invalid_choice)" ;;
    esac

    echo
    if ! confirm_default_yes "$(tr_msg confirm_back_menu)"; then
      exit 0
    fi
  done
}

main_menu "$@"
