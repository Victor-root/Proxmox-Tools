#!/usr/bin/env bash
set -euo pipefail

BACKUP_PREFIX="/root/pve-fastfetch-motd-backup"
ORIGINAL_DIR="${BACKUP_PREFIX}-original"
PROFILE_FILE="/etc/profile.d/99-fastfetch-motd.sh"
MOTD_FILE="/etc/motd"
UNAME_MOTD_FILE="/etc/update-motd.d/10-uname"
RELEASE_BASE="https://github.com/fastfetch-cli/fastfetch/releases"
MANAGED_MARKER="Managed by Proxmox-Tools pve-fastfetch-motd.sh"

ROOT_HOME="$(getent passwd root 2>/dev/null | cut -d: -f6)"
[[ -n "$ROOT_HOME" ]] || ROOT_HOME="/root"
CONFIG_DIR="${ROOT_HOME}/.config/fastfetch"
CONFIG_FILE="${CONFIG_DIR}/config.jsonc"

FF_TMPDIR=""
cleanup_tmp() {
    [[ -n "$FF_TMPDIR" && -d "$FF_TMPDIR" ]] && rm -rf "$FF_TMPDIR"
    return 0
}
trap cleanup_tmp EXIT

# ------------------------------------------------------------
# Language detection (EN default, FR if system locale starts with fr)
# ------------------------------------------------------------

detect_lang() {
    local raw="${LC_ALL:-${LC_MESSAGES:-${LANG:-en}}}"
    raw="${raw,,}"
    case "$raw" in
        fr* ) APP_LANG="fr" ;;
        en* ) APP_LANG="en" ;;
        * ) APP_LANG="en" ;;
    esac
}

APP_LANG="en"
detect_lang

tr_msg() {
    local key="$1"
    case "$APP_LANG:$key" in
        fr:menu_install) echo "Installer / mettre à jour Fastfetch et l'affichage au login" ;;
        en:menu_install) echo "Install / update Fastfetch and the login display" ;;

        fr:menu_cert) echo "Configurer le module certificat HTTPS (FQDN)" ;;
        en:menu_cert) echo "Configure the HTTPS certificate module (FQDN)" ;;

        fr:menu_custom) echo "Utiliser ma propre configuration (copier-coller)" ;;
        en:menu_custom) echo "Use my own configuration (paste it)" ;;

        fr:menu_preview) echo "Aperçu de l'affichage Fastfetch" ;;
        en:menu_preview) echo "Preview the Fastfetch output" ;;

        fr:menu_status) echo "Afficher l'état" ;;
        en:menu_status) echo "Show status" ;;

        fr:menu_disable_login) echo "Désactiver l'affichage à chaque session shell (garder Fastfetch)" ;;
        en:menu_disable_login) echo "Disable the display on every shell session (keep Fastfetch)" ;;

        fr:menu_remove_all) echo "Tout supprimer (affichage, configuration et Fastfetch)" ;;
        en:menu_remove_all) echo "Remove everything (display, configuration and Fastfetch)" ;;

        fr:menu_quit) echo "Quitter" ;;
        en:menu_quit) echo "Quit" ;;

        fr:choose_option) echo "Choisissez une option" ;;
        en:choose_option) echo "Choose an option" ;;

        fr:press_enter) echo "Appuyez sur Entrée pour continuer..." ;;
        en:press_enter) echo "Press Enter to continue..." ;;

        fr:cancelled) echo "Opération annulée." ;;
        en:cancelled) echo "Operation cancelled." ;;

        fr:invalid_choice) echo "Choix invalide." ;;
        en:invalid_choice) echo "Invalid choice." ;;

        fr:bye) echo "À bientôt." ;;
        en:bye) echo "Bye." ;;

        fr:running_as_root) echo "Ce script doit être lancé en root." ;;
        en:running_as_root) echo "This script must be run as root." ;;

        fr:not_proxmox) echo "Ce script doit être lancé sur un hôte Proxmox VE." ;;
        en:not_proxmox) echo "This script must be run on a Proxmox VE host." ;;

        fr:missing_cmd) echo "Commande requise manquante" ;;
        en:missing_cmd) echo "Missing required command" ;;

        fr:missing_downloader) echo "curl ou wget est requis." ;;
        en:missing_downloader) echo "curl or wget is required." ;;

        fr:detected_language) echo "Langue détectée" ;;
        en:detected_language) echo "Detected language" ;;

        fr:lang_fr) echo "Français" ;;
        en:lang_fr) echo "French" ;;

        fr:lang_en) echo "Anglais" ;;
        en:lang_en) echo "English" ;;

        fr:banner_subtitle) echo "Fastfetch MOTD" ;;
        en:banner_subtitle) echo "Fastfetch MOTD" ;;

        fr:repo_hint) echo "Installe Fastfetch et affiche un résumé de l'hyperviseur à l'ouverture d'un shell root" ;;
        en:repo_hint) echo "Installs Fastfetch and shows a hypervisor summary when a root shell opens" ;;

        fr:hint_default_yes) echo "[Entrée=oui / non]" ;;
        en:hint_default_yes) echo "[Enter=yes / no]" ;;

        fr:type_yes) echo "Tapez 'yes' pour continuer" ;;
        en:type_yes) echo "Type 'yes' to continue" ;;

        fr:warning_title) echo "CE QUE FAIT CE SCRIPT" ;;
        en:warning_title) echo "WHAT THIS SCRIPT DOES" ;;

        fr:warning_body_1) echo "Installe le paquet Fastfetch officiel de la dernière release GitHub." ;;
        en:warning_body_1) echo "Installs the official Fastfetch package from the latest GitHub release." ;;

        fr:warning_body_2) echo "Écrit une configuration Fastfetch dans ${CONFIG_FILE}." ;;
        en:warning_body_2) echo "Writes a Fastfetch configuration in ${CONFIG_FILE}." ;;

        fr:warning_body_3) echo "Ajoute ${PROFILE_FILE} pour l'afficher dans les shells root interactifs." ;;
        en:warning_body_3) echo "Adds ${PROFILE_FILE} to show it in interactive root shells." ;;

        fr:warning_body_4) echo "Désactive l'ancien MOTD Debian (10-uname et /etc/motd), avec sauvegarde et restauration possibles." ;;
        en:warning_body_4) echo "Disables the old Debian MOTD (10-uname and /etc/motd), with backup and restore available." ;;

        fr:confirm_install) echo "Lancer l'installation maintenant ?" ;;
        en:confirm_install) echo "Start the installation now?" ;;

        fr:arch_unsupported) echo "Architecture non prise en charge par les paquets Fastfetch" ;;
        en:arch_unsupported) echo "Architecture not supported by the Fastfetch packages" ;;

        fr:checking_latest) echo "Recherche de la dernière version stable de Fastfetch..." ;;
        en:checking_latest) echo "Looking for the latest stable Fastfetch release..." ;;

        fr:latest_version) echo "Dernière version" ;;
        en:latest_version) echo "Latest version" ;;

        fr:installed_version) echo "Version installée" ;;
        en:installed_version) echo "Installed version" ;;

        fr:latest_unknown) echo "Version distante indéterminée, le paquet sera téléchargé pour comparaison." ;;
        en:latest_unknown) echo "Remote version unknown, the package will be downloaded for comparison." ;;

        fr:already_up_to_date) echo "Fastfetch est déjà à jour, rien à télécharger." ;;
        en:already_up_to_date) echo "Fastfetch is already up to date, nothing to download." ;;

        fr:downloading) echo "Téléchargement du paquet" ;;
        en:downloading) echo "Downloading the package" ;;

        fr:download_failed) echo "Le téléchargement a échoué." ;;
        en:download_failed) echo "The download failed." ;;

        fr:bad_package) echo "Le paquet téléchargé n'est pas un paquet Fastfetch valide." ;;
        en:bad_package) echo "The downloaded file is not a valid Fastfetch package." ;;

        fr:installing) echo "Installation du paquet Fastfetch" ;;
        en:installing) echo "Installing the Fastfetch package" ;;

        fr:command_output) echo "Sortie de la commande :" ;;
        en:command_output) echo "Command output:" ;;

        fr:install_failed) echo "L'installation de Fastfetch a échoué." ;;
        en:install_failed) echo "Fastfetch installation failed." ;;

        fr:install_ok) echo "Fastfetch installé" ;;
        en:install_ok) echo "Fastfetch installed" ;;

        fr:original_saved) echo "État d'origine sauvegardé" ;;
        en:original_saved) echo "Original state saved" ;;

        fr:backup_created) echo "Backup créé" ;;
        en:backup_created) echo "Backup created" ;;

        fr:config_written) echo "Configuration écrite" ;;
        en:config_written) echo "Configuration written" ;;

        fr:config_custom_found) echo "Une configuration Fastfetch existe déjà et n'a pas été créée par ce script. Elle est sauvegardée avant d'être remplacée." ;;
        en:config_custom_found) echo "A Fastfetch configuration already exists and was not created by this script. It is backed up before being replaced." ;;

        fr:bridge_detected) echo "Bridge détecté" ;;
        en:bridge_detected) echo "Detected bridge" ;;

        fr:profile_written) echo "Affichage activé pour les shells root interactifs" ;;
        en:profile_written) echo "Display enabled for interactive root shells" ;;

        fr:motd_disabled) echo "Ancien MOTD Debian désactivé" ;;
        en:motd_disabled) echo "Old Debian MOTD disabled" ;;

        fr:motd_restored) echo "Ancien MOTD Debian restauré" ;;
        en:motd_restored) echo "Old Debian MOTD restored" ;;

        fr:motd_nothing_to_restore) echo "Aucun état d'origine du MOTD à restaurer." ;;
        en:motd_nothing_to_restore) echo "No original MOTD state to restore." ;;

        fr:cert_title) echo "MODULE CERTIFICAT HTTPS (OPTIONNEL)" ;;
        en:cert_title) echo "HTTPS CERTIFICATE MODULE (OPTIONAL)" ;;

        fr:cert_body_1) echo "Ce module affiche la date d'expiration du certificat réellement présenté en HTTPS, par exemple par un reverse proxy." ;;
        en:cert_body_1) echo "This module shows the expiry date of the certificate actually presented over HTTPS, for example by a reverse proxy." ;;

        fr:cert_body_2) echo "Seul le certificat public est lu, aucune clé privée n'est utilisée." ;;
        en:cert_body_2) echo "Only the public certificate is read, no private key is used." ;;

        fr:cert_body_3) echo "Laissez vide pour ne pas ajouter ce module." ;;
        en:cert_body_3) echo "Leave empty to skip this module." ;;

        fr:cert_prompt) echo "FQDN HTTPS à tester (nom[:port], port 443 par défaut)" ;;
        en:cert_prompt) echo "HTTPS FQDN to test (name[:port], port 443 by default)" ;;

        fr:cert_invalid) echo "FQDN invalide." ;;
        en:cert_invalid) echo "Invalid FQDN." ;;

        fr:cert_enabled) echo "Module certificat activé pour" ;;
        en:cert_enabled) echo "Certificate module enabled for" ;;

        fr:cert_disabled) echo "Module certificat désactivé." ;;
        en:cert_disabled) echo "Certificate module disabled." ;;

        fr:paste_title) echo "COLLER VOTRE PROPRE CONFIGURATION" ;;
        en:paste_title) echo "PASTE YOUR OWN CONFIGURATION" ;;

        fr:paste_body_1) echo "Collez ici le contenu complet de votre fichier config.jsonc." ;;
        en:paste_body_1) echo "Paste here the whole content of your config.jsonc file." ;;

        fr:paste_body_2) echo "Pour terminer, tapez EOF seul sur une ligne, ou faites Ctrl+D." ;;
        en:paste_body_2) echo "To finish, type EOF alone on a line, or press Ctrl+D." ;;

        fr:paste_body_3) echo "Rien de collé : rien ne change. La configuration actuelle est sauvegardée avant d'être remplacée." ;;
        en:paste_body_3) echo "Nothing pasted means nothing changes. The current configuration is backed up before being replaced." ;;

        fr:paste_waiting) echo "En attente de votre configuration..." ;;
        en:paste_waiting) echo "Waiting for your configuration..." ;;

        fr:paste_empty) echo "Rien n'a été collé, aucune modification." ;;
        en:paste_empty) echo "Nothing was pasted, no change." ;;

        fr:paste_received) echo "Lignes reçues" ;;
        en:paste_received) echo "Lines received" ;;

        fr:paste_checking) echo "Vérification de la configuration" ;;
        en:paste_checking) echo "Checking the configuration" ;;

        fr:paste_invalid) echo "Fastfetch refuse cette configuration, rien n'a été écrit." ;;
        en:paste_invalid) echo "Fastfetch rejects this configuration, nothing was written." ;;

        fr:paste_installed) echo "Votre configuration est en place" ;;
        en:paste_installed) echo "Your configuration is in place" ;;

        fr:paste_login_hint) echo "L'affichage à l'ouverture d'un shell root n'est pas actif. Utilisez l'option 1 pour l'activer." ;;
        en:paste_login_hint) echo "The display on root shell login is not active. Use option 1 to turn it on." ;;

        fr:preview_question) echo "Afficher un aperçu maintenant ?" ;;
        en:preview_question) echo "Show a preview now?" ;;

        fr:status_title) echo "État" ;;
        en:status_title) echo "Status" ;;

        fr:status_fastfetch) echo "Fastfetch" ;;
        en:status_fastfetch) echo "Fastfetch" ;;

        fr:status_config) echo "Configuration" ;;
        en:status_config) echo "Configuration" ;;

        fr:status_cert) echo "Module certificat" ;;
        en:status_cert) echo "Certificate module" ;;

        fr:status_login) echo "Affichage au login" ;;
        en:status_login) echo "Login display" ;;

        fr:status_motd) echo "Ancien MOTD Debian" ;;
        en:status_motd) echo "Old Debian MOTD" ;;

        fr:status_backups) echo "Sauvegardes" ;;
        en:status_backups) echo "Backups" ;;

        fr:status_installed) echo "installé" ;;
        en:status_installed) echo "installed" ;;

        fr:status_not_installed) echo "non installé" ;;
        en:status_not_installed) echo "not installed" ;;

        fr:status_managed) echo "gérée par ce script" ;;
        en:status_managed) echo "managed by this script" ;;

        fr:status_custom) echo "présente, non gérée par ce script" ;;
        en:status_custom) echo "present, not managed by this script" ;;

        fr:status_absent) echo "absente" ;;
        en:status_absent) echo "absent" ;;

        fr:status_enabled) echo "activé" ;;
        en:status_enabled) echo "enabled" ;;

        fr:status_disabled) echo "désactivé" ;;
        en:status_disabled) echo "disabled" ;;

        fr:status_active) echo "actif" ;;
        en:status_active) echo "active" ;;

        fr:preview_note) echo "Aperçu, le module CPU Usage prend environ 2 secondes." ;;
        en:preview_note) echo "Preview, the CPU Usage module takes about 2 seconds." ;;

        fr:need_install_first) echo "Fastfetch n'est pas installé. Utilisez l'option 1." ;;
        en:need_install_first) echo "Fastfetch is not installed. Use option 1." ;;

        fr:need_config_first) echo "Aucune configuration gérée par ce script. Utilisez l'option 1." ;;
        en:need_config_first) echo "No configuration managed by this script. Use option 1." ;;

        fr:login_removed) echo "Affichage au login supprimé." ;;
        en:login_removed) echo "Login display removed." ;;

        fr:login_already_absent) echo "L'affichage au login n'est pas actif." ;;
        en:login_already_absent) echo "The login display is not active." ;;

        fr:profile_not_managed) echo "Ce fichier n'a pas été créé par ce script, il est laissé en place" ;;
        en:profile_not_managed) echo "This file was not created by this script, it is left untouched" ;;

        fr:remove_all_title) echo "SUPPRESSION COMPLÈTE" ;;
        en:remove_all_title) echo "FULL REMOVAL" ;;

        fr:remove_all_body_1) echo "Supprime l'affichage au login, la configuration Fastfetch de root et désinstalle le paquet fastfetch." ;;
        en:remove_all_body_1) echo "Removes the login display, the root Fastfetch configuration and uninstalls the fastfetch package." ;;

        fr:remove_all_body_2) echo "L'ancien MOTD Debian est restauré s'il a été sauvegardé." ;;
        en:remove_all_body_2) echo "The old Debian MOTD is restored if it was saved." ;;

        fr:removing_package) echo "Désinstallation du paquet Fastfetch" ;;
        en:removing_package) echo "Uninstalling the Fastfetch package" ;;

        fr:remove_package_failed) echo "La désinstallation du paquet a échoué." ;;
        en:remove_package_failed) echo "The package removal failed." ;;

        fr:config_removed) echo "Configuration supprimée" ;;
        en:config_removed) echo "Configuration removed" ;;

        fr:remove_all_done) echo "Suppression terminée." ;;
        en:remove_all_done) echo "Removal completed." ;;

        fr:backups_kept) echo "Les sauvegardes sont conservées dans" ;;
        en:backups_kept) echo "Backups are kept in" ;;

        fr:reconnect_hint) echo "Ouvrez une nouvelle session shell root pour voir le résultat." ;;
        en:reconnect_hint) echo "Open a new root shell session to see the result." ;;

        fr:done_title) echo "Installation terminée" ;;
        en:done_title) echo "Installation completed" ;;

        # Strings written inside the generated Fastfetch configuration
        fr:cfg_section_host) echo " INFOS HYPERVISEUR     " ;;
        en:cfg_section_host) echo " HYPERVISOR INFO       " ;;

        fr:cfg_section_res) echo " RESSOURCES PHYSIQUES  " ;;
        en:cfg_section_res) echo " PHYSICAL RESOURCES    " ;;

        fr:cfg_section_net) echo " RÉSEAU ET ACCÈS       " ;;
        en:cfg_section_net) echo " NETWORK AND ACCESS    " ;;

        fr:cfg_key_os) echo "  🐧  Système       " ;;
        en:cfg_key_os) echo "  🐧  System        " ;;

        fr:cfg_key_pve) echo "  💎  PVE Version   " ;;
        en:cfg_key_pve) echo "  💎  PVE Version   " ;;

        fr:cfg_key_host) echo "  💻  Machine       " ;;
        en:cfg_key_host) echo "  💻  Machine       " ;;

        fr:cfg_key_kernel) echo "  ⚙️  Noyau         " ;;
        en:cfg_key_kernel) echo "  ⚙️  Kernel        " ;;

        fr:cfg_key_uptime) echo "  ⏱️  Activité      " ;;
        en:cfg_key_uptime) echo "  ⏱️  Uptime        " ;;

        fr:cfg_key_cpu) echo "  🧠  CPU           " ;;
        en:cfg_key_cpu) echo "  🧠  CPU           " ;;

        fr:cfg_key_gpu) echo "  🎮  GPU           " ;;
        en:cfg_key_gpu) echo "  🎮  GPU           " ;;

        fr:cfg_key_memory) echo "  💾  RAM           " ;;
        en:cfg_key_memory) echo "  💾  RAM           " ;;

        fr:cfg_key_swap) echo "  🔄  Swap          " ;;
        en:cfg_key_swap) echo "  🔄  Swap          " ;;

        fr:cfg_key_disk) echo "  💽  Stockage      " ;;
        en:cfg_key_disk) echo "  💽  Storage       " ;;

        fr:cfg_key_cpu_usage) echo "  📈  CPU Usage     " ;;
        en:cfg_key_cpu_usage) echo "  📈  CPU Usage     " ;;

        fr:cfg_key_zfs) echo "  🧬  ZFS Health    " ;;
        en:cfg_key_zfs) echo "  🧬  ZFS Health    " ;;

        fr:cfg_key_localip) echo "  🌐  IP Admin      " ;;
        en:cfg_key_localip) echo "  🌐  Admin IP      " ;;

        fr:cfg_key_dns) echo "  🔍  DNS           " ;;
        en:cfg_key_dns) echo "  🔍  DNS           " ;;

        fr:cfg_key_cert) echo "  🔐  Certificat    " ;;
        en:cfg_key_cert) echo "  🔐  Certificate   " ;;

        fr:cfg_key_pubip) echo "  🌍  IP Publique   " ;;
        en:cfg_key_pubip) echo "  🌍  Public IP     " ;;

        fr:cfg_key_f2b) echo "  🛡️  Fail2ban      " ;;
        en:cfg_key_f2b) echo "  🛡️  Fail2ban      " ;;

        fr:cfg_txt_no_zpool) echo "zpool absent" ;;
        en:cfg_txt_no_zpool) echo "zpool missing" ;;

        fr:cfg_txt_no_pool) echo "aucun pool" ;;
        en:cfg_txt_no_pool) echo "no pool" ;;

        fr:cfg_txt_ports) echo "ports physiques" ;;
        en:cfg_txt_ports) echo "physical ports" ;;

        fr:cfg_txt_absent) echo "absent" ;;
        en:cfg_txt_absent) echo "not installed" ;;

        fr:cfg_txt_no_jail) echo "aucun jail" ;;
        en:cfg_txt_no_jail) echo "no jail" ;;

        fr:cfg_txt_unavailable) echo "indisponible" ;;
        en:cfg_txt_unavailable) echo "unavailable" ;;

        fr:cfg_txt_expires) echo "expire le" ;;
        en:cfg_txt_expires) echo "expires on" ;;

        fr:cfg_txt_days) echo "j" ;;
        en:cfg_txt_days) echo "d" ;;

        fr:cfg_date_fmt) echo "+%d/%m/%Y %H:%M" ;;
        en:cfg_date_fmt) echo "+%Y-%m-%d %H:%M" ;;

        * ) echo "$key" ;;
    esac
}

APP_NAME="$(tr_msg banner_subtitle)"

# ------------------------------------------------------------
# Colors (Proxmox-inspired), same visual engine as
# pve-console-newtab.sh, orange as the accent color.
# ------------------------------------------------------------

if [[ -t 1 ]]; then
    RESET='\033[0m'
    BOLD='\033[1m'

    PMX_ORANGE='\033[38;5;166m'
    PMX_ORANGE_DARK='\033[38;5;130m'
    PMX_ORANGE_SOFT='\033[38;5;208m'
    PMX_RED='\033[38;5;124m'
    PMX_AMBER='\033[38;5;214m'
    PMX_GREEN='\033[38;5;70m'
    PMX_CYAN='\033[38;5;73m'
    PMX_BLUE='\033[38;5;67m'
    PMX_GREY='\033[38;5;244m'
else
    RESET=''
    BOLD=''

    PMX_ORANGE=''
    PMX_ORANGE_DARK=''
    PMX_ORANGE_SOFT=''
    PMX_RED=''
    PMX_AMBER=''
    PMX_GREEN=''
    PMX_CYAN=''
    PMX_BLUE=''
    PMX_GREY=''
fi

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
    printf "%b%s%b\n" "${PMX_ORANGE_DARK}" "${line// /─}" "${RESET}"
}

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

say_info() { printf "%b›%b %b\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$*"; }
say_ok()   { printf "%b✓%b %b\n" "${PMX_GREEN}" "${RESET}" "$*"; }
say_warn() { printf "%b⚠%b %b\n" "${PMX_AMBER}" "${RESET}" "$*"; }
say_err()  { printf "%b✗%b %b\n" "${PMX_RED}" "${RESET}" "$*" >&2; }

SPINNER_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")

# Long commands (download, apt) run behind a spinner: their output is only
# shown when they fail, so a normal run stays readable.
step() {
    local label="$1"
    shift

    local log rc=0
    log="$(mktemp)"

    if [[ -t 1 ]]; then
        "$@" >"$log" 2>&1 &
        local pid=$!
        local i=0
        while kill -0 "$pid" 2>/dev/null; do
            printf "\r%b%s%b %b%s…%b" \
                "${PMX_ORANGE_SOFT}" "${SPINNER_FRAMES[i]}" "${RESET}" \
                "${PMX_GREY}" "$label" "${RESET}"
            i=$(((i + 1) % ${#SPINNER_FRAMES[@]}))
            sleep 0.08
        done
        wait "$pid" || rc=$?
        if [[ "$rc" -eq 0 ]]; then
            printf "\r\033[2K%b✓%b %s\n" "${PMX_GREEN}" "${RESET}" "$label"
        else
            printf "\r\033[2K%b✗%b %s\n" "${PMX_RED}" "${RESET}" "$label"
        fi
    else
        printf "%b›%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$label"
        "$@" >"$log" 2>&1 || rc=$?
        if [[ "$rc" -eq 0 ]]; then
            printf "%b✓%b %s\n" "${PMX_GREEN}" "${RESET}" "$label"
        else
            printf "%b✗%b %s\n" "${PMX_RED}" "${RESET}" "$label"
        fi
    fi

    if [[ "$rc" -ne 0 ]]; then
        echo
        say_err "$(tr_msg command_output)"
        sed -e 's/^/  /' "$log" >&2
        rm -f "$log"
        return "$rc"
    fi

    rm -f "$log"
    return 0
}

banner() {
    clear || true
    echo
    printf "%b%s%b\n" "${PMX_ORANGE}" '██████╗ ██████╗  ██████╗ ██╗  ██╗███╗   ███╗ ██████╗ ██╗  ██╗' "${RESET}"
    printf "%b%s%b\n" "${PMX_ORANGE}" '██╔══██╗██╔══██╗██╔═══██╗╚██╗██╔╝████╗ ████║██╔═══██╗╚██╗██╔╝' "${RESET}"
    printf "%b%s%b\n" "${PMX_ORANGE}" '██████╔╝██████╔╝██║   ██║ ╚███╔╝ ██╔████╔██║██║   ██║ ╚███╔╝ ' "${RESET}"
    printf "%b%s%b\n" "${PMX_ORANGE}" '██╔═══╝ ██╔══██╗██║   ██║ ██╔██╗ ██║╚██╔╝██║██║   ██║ ██╔██╗ ' "${RESET}"
    printf "%b%s%b\n" "${PMX_ORANGE}" '██║     ██║  ██║╚██████╔╝██╔╝ ██╗██║ ╚═╝ ██║╚██████╔╝██╔╝ ██╗' "${RESET}"
    printf "%b%s%b\n" "${PMX_ORANGE}" '╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═╝' "${RESET}"
    echo
    printf "  %b%s%b %b· by Victor-root%b\n" "${BOLD}${PMX_ORANGE_SOFT}" "$APP_NAME" "${RESET}" "${PMX_GREY}" "${RESET}"
    hr
}

show_banner() {
    banner

    local lang_label
    if [[ "$APP_LANG" == "fr" ]]; then
        lang_label="$(tr_msg lang_fr)"
    else
        lang_label="$(tr_msg lang_en)"
    fi

    panel "$PMX_BLUE" "$(tr_msg repo_hint)" \
        "Host: ${BOLD}$(hostname)${RESET}" \
        "$(tr_msg detected_language): ${BOLD}${lang_label}${RESET}"
    echo
}

pause() {
    echo
    read -r -p "$(tr_msg press_enter)" _ || true
}

confirm_yes() {
    echo
    printf "%b?%b %b%s%b : " "${PMX_AMBER}" "${RESET}" "${BOLD}" "$(tr_msg type_yes)" "${RESET}"
    read -r answer
    [[ "$answer" == "yes" ]]
}

confirm_default_yes() {
    local label="$1" value
    printf "%b?%b %b%s%b %b%s%b : " \
        "${PMX_AMBER}" "${RESET}" \
        "${BOLD}" "$label" "${RESET}" \
        "${PMX_GREY}" "$(tr_msg hint_default_yes)" "${RESET}"
    IFS= read -r value
    value="${value:-yes}"
    value="${value,,}"
    [[ "$value" == "y" || "$value" == "yes" || "$value" == "o" || "$value" == "oui" ]]
}

prompt_free() {
    local label="$1" value
    printf "%b?%b %b%s%b : " \
        "${PMX_ORANGE_SOFT}" "${RESET}" \
        "${BOLD}" "$label" "${RESET}" >&2
    IFS= read -r value
    printf "%s" "$value"
}

# ------------------------------------------------------------
# Requirements
# ------------------------------------------------------------

require_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        say_err "$(tr_msg running_as_root)"
        exit 1
    fi
}

require_pve() {
    if ! command -v pveversion >/dev/null 2>&1 || [[ ! -d /etc/pve ]]; then
        say_err "$(tr_msg not_proxmox)"
        exit 1
    fi
}

require_tools() {
    local cmd
    for cmd in apt-get dpkg dpkg-deb; do
        command -v "$cmd" >/dev/null 2>&1 || { say_err "$(tr_msg missing_cmd): $cmd"; exit 1; }
    done
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        say_err "$(tr_msg missing_downloader)"
        exit 1
    fi
}

# ------------------------------------------------------------
# Fastfetch package
# ------------------------------------------------------------

# The Fastfetch releases ship one .deb per CPU family, named after the kernel
# architecture and not after the Debian one.
release_asset_arch() {
    local deb_arch
    deb_arch="$(dpkg --print-architecture 2>/dev/null || true)"
    case "$deb_arch" in
        amd64 ) echo "amd64" ;;
        arm64 ) echo "aarch64" ;;
        armhf ) echo "armv7l" ;;
        ppc64el ) echo "ppc64le" ;;
        riscv64 ) echo "riscv64" ;;
        s390x ) echo "s390x" ;;
        * ) return 1 ;;
    esac
}

installed_fastfetch_version() {
    dpkg-query -W -f='${Version}' fastfetch 2>/dev/null || true
}

fastfetch_is_installed() {
    command -v fastfetch >/dev/null 2>&1
}

# The /releases/latest/download/ URL always redirects to the tagged asset of the
# latest stable release, so the tag can be read without querying the GitHub API.
latest_fastfetch_version() {
    local url="$1" location=""

    if command -v curl >/dev/null 2>&1; then
        location="$(curl -fsSI --max-time 20 -o /dev/null -w '%{redirect_url}' "$url" 2>/dev/null || true)"
    else
        location="$(wget -q -S --spider --max-redirect=0 --timeout=20 "$url" 2>&1 \
            | sed -n 's/^[[:space:]]*Location:[[:space:]]*\([^[:space:]]*\).*/\1/p' | head -n1 || true)"
    fi

    [[ "$location" == *"/releases/download/"* ]] || return 0

    location="${location#*/releases/download/}"
    location="${location%%/*}"
    echo "${location#v}"
}

download_file() {
    local url="$1" dest="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --retry 3 --max-time 300 -o "$dest" "$url"
    else
        wget -q --tries=3 --timeout=300 -O "$dest" "$url"
    fi
}

apt_install_local_deb() {
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$1"
}

apt_purge_fastfetch() {
    DEBIAN_FRONTEND=noninteractive apt-get purge -y fastfetch
}

install_fastfetch() {
    local asset_arch url latest installed deb deb_version

    if ! asset_arch="$(release_asset_arch)"; then
        say_err "$(tr_msg arch_unsupported): $(dpkg --print-architecture 2>/dev/null || uname -m)"
        return 1
    fi

    url="${RELEASE_BASE}/latest/download/fastfetch-linux-${asset_arch}.deb"
    installed="$(installed_fastfetch_version)"

    say_info "$(tr_msg checking_latest)"
    latest="$(latest_fastfetch_version "$url")"

    if [[ -n "$latest" ]]; then
        say_info "$(tr_msg latest_version): ${BOLD}${latest}${RESET}"
    else
        say_warn "$(tr_msg latest_unknown)"
    fi

    if [[ -n "$installed" ]]; then
        say_info "$(tr_msg installed_version): ${BOLD}${installed}${RESET}"
        if [[ -n "$latest" ]] && dpkg --compare-versions "$installed" ge "$latest"; then
            say_ok "$(tr_msg already_up_to_date)"
            return 0
        fi
    fi

    FF_TMPDIR="$(mktemp -d)"
    # apt drops its privileges to the _apt user to fetch the package, and warns
    # when it cannot read the file it is given.
    chmod 0755 "$FF_TMPDIR"
    deb="${FF_TMPDIR}/fastfetch-linux-${asset_arch}.deb"

    if ! step "$(tr_msg downloading) (fastfetch-linux-${asset_arch}.deb)" download_file "$url" "$deb"; then
        say_err "$(tr_msg download_failed)"
        return 1
    fi

    if [[ "$(dpkg-deb -f "$deb" Package 2>/dev/null || true)" != "fastfetch" ]]; then
        say_err "$(tr_msg bad_package)"
        return 1
    fi

    deb_version="$(dpkg-deb -f "$deb" Version 2>/dev/null || true)"
    if [[ -n "$installed" && -n "$deb_version" ]] && dpkg --compare-versions "$installed" ge "$deb_version"; then
        cleanup_tmp
        FF_TMPDIR=""
        say_ok "$(tr_msg already_up_to_date)"
        return 0
    fi

    if ! step "$(tr_msg installing)" apt_install_local_deb "$deb"; then
        say_err "$(tr_msg install_failed)"
        return 1
    fi

    cleanup_tmp
    FF_TMPDIR=""

    if ! fastfetch_is_installed; then
        say_err "$(tr_msg install_failed)"
        return 1
    fi

    say_ok "$(tr_msg install_ok): ${BOLD}$(installed_fastfetch_version)${RESET}"
}

# ------------------------------------------------------------
# Backups and original state
# ------------------------------------------------------------

# Saved once, on the very first run, so the pre-Fastfetch MOTD can always be
# put back even after several runs of this script.
save_original_state() {
    [[ -d "$ORIGINAL_DIR" ]] && return 0

    local uname_state="absent"
    if [[ -f "$UNAME_MOTD_FILE" ]]; then
        if [[ -x "$UNAME_MOTD_FILE" ]]; then
            uname_state="executable"
        else
            uname_state="not_executable"
        fi
    fi

    mkdir -p "$ORIGINAL_DIR"
    [[ -f "$MOTD_FILE" ]] && cp -a "$MOTD_FILE" "${ORIGINAL_DIR}/motd"
    [[ -f "$PROFILE_FILE" ]] && cp -a "$PROFILE_FILE" "${ORIGINAL_DIR}/$(basename "$PROFILE_FILE")"
    [[ -f "$CONFIG_FILE" ]] && cp -a "$CONFIG_FILE" "${ORIGINAL_DIR}/config.jsonc"

    {
        echo "created_at=$(date --iso-8601=seconds)"
        echo "hostname=$(hostname)"
        echo "motd_file=$([[ -f "$MOTD_FILE" ]] && echo present || echo absent)"
        echo "motd_uname=${uname_state}"
    } >"${ORIGINAL_DIR}/INFO.txt"

    say_info "$(tr_msg original_saved): ${PMX_CYAN}${ORIGINAL_DIR}${RESET}"
}

backup_current_config() {
    [[ -f "$CONFIG_FILE" ]] || return 0

    local dir
    dir="${BACKUP_PREFIX}-$(date +%F-%H%M%S)"
    mkdir -p "$dir"
    cp -a "$CONFIG_FILE" "${dir}/config.jsonc"

    {
        echo "created_at=$(date --iso-8601=seconds)"
        echo "hostname=$(hostname)"
        echo "config_file=$CONFIG_FILE"
    } >"${dir}/INFO.txt"

    say_info "$(tr_msg backup_created): ${PMX_CYAN}${dir}${RESET}"
}

original_info_value() {
    local key="$1"
    [[ -f "${ORIGINAL_DIR}/INFO.txt" ]] || return 0
    sed -n "s/^${key}=\(.*\)$/\1/p" "${ORIGINAL_DIR}/INFO.txt" | head -n1
}

# ------------------------------------------------------------
# Fastfetch configuration
# ------------------------------------------------------------

config_is_managed() {
    [[ -f "$CONFIG_FILE" ]] && grep -qF "$MANAGED_MARKER" "$CONFIG_FILE"
}

configured_cert_target() {
    local host port
    [[ -f "$CONFIG_FILE" ]] || return 0
    host="$(sed -n "s/.*HOST='\([^']*\)'.*/\1/p" "$CONFIG_FILE" | head -n1)"
    [[ -n "$host" ]] || return 0
    port="$(sed -n "s/.*PORT='\([^']*\)'.*/\1/p" "$CONFIG_FILE" | head -n1)"
    echo "${host}:${port:-443}"
}

# The bridge carrying the default route is the one worth watching; vmbr0 is only
# the fallback so a freshly installed node still shows something sensible.
detect_bridge() {
    local iface candidate
    iface="$(ip route show default 2>/dev/null | awk '{print $5; exit}' || true)"
    if [[ -n "$iface" && -d "/sys/class/net/${iface}/bridge" ]]; then
        echo "$iface"
        return 0
    fi
    for candidate in /sys/class/net/vmbr*; do
        [[ -d "$candidate" ]] || continue
        echo "${candidate##*/}"
        return 0
    done
    echo "vmbr0"
}

# host or host:port, no credentials and no personal data kept anywhere else.
validate_cert_target() {
    local target="$1" host="${1%%:*}" port=""

    [[ "$target" == *:* ]] && port="${target##*:}"
    [[ "$host" =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+$ ]] || return 1
    if [[ "$target" == *:* ]]; then
        [[ "$port" =~ ^[0-9]{1,5}$ ]] || return 1
        (( port >= 1 && port <= 65535 )) || return 1
    fi
    return 0
}

cert_module_block() {
    cat <<'EOF_CERT'
    {
      "type": "command",
      "key": "__KEY_CERT__",
      "shell": "bash",
      "text": "HOST='__CERT_HOST__'; PORT='__CERT_PORT__'; command -v openssl >/dev/null 2>&1 || { echo '__TXT_UNAVAILABLE__'; exit; }; exp=$(echo | timeout 4 openssl s_client -connect \"$HOST:$PORT\" -servername \"$HOST\" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2-); [ -z \"$exp\" ] && { echo '__TXT_UNAVAILABLE__'; exit; }; end=$(date -d \"$exp\" +%s 2>/dev/null); now=$(date +%s); d=$(date -d \"$exp\" '__DATE_FMT__' 2>/dev/null || echo \"$exp\"); if [ -n \"$end\" ]; then days=$(( (end-now) / 86400 )); echo \"__TXT_EXPIRES__ $d (${days}__TXT_DAYS__)\"; else echo \"__TXT_EXPIRES__ $d\"; fi"
    },
EOF_CERT
}

config_template() {
    cat <<'EOF_CONFIG'
// __MARKER__
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",

  "logo": {
    "source": "proxmox",
    "color": {
      "1": "38;5;208",
      "2": "38;5;214"
    },
    "padding": {
      "top": 2,
      "left": 2
    }
  },

  "display": {
    "separator": " ➜ ",
    "color": {
      "keys": "38;5;208",
      "output": "white"
    }
  },

  "modules": [
    "title",

    {
      "type": "custom",
      "format": "\u001b[48;5;208m\u001b[30m__SECTION_HOST__\u001b[0m"
    },

    {
      "type": "os",
      "key": "__KEY_OS__"
    },
    {
      "type": "command",
      "key": "__KEY_PVE__",
      "shell": "bash",
      "text": "pveversion | cut -d'/' -f2"
    },
    {
      "type": "host",
      "key": "__KEY_HOST__"
    },
    {
      "type": "kernel",
      "key": "__KEY_KERNEL__"
    },
    {
      "type": "uptime",
      "key": "__KEY_UPTIME__"
    },

    "break",

    {
      "type": "custom",
      "format": "\u001b[48;5;208m\u001b[30m__SECTION_RES__\u001b[0m"
    },

    {
      "type": "cpu",
      "key": "__KEY_CPU__",
      "temp": true
    },
    {
      "type": "gpu",
      "key": "__KEY_GPU__"
    },
    {
      "type": "memory",
      "key": "__KEY_MEMORY__"
    },
    {
      "type": "swap",
      "key": "__KEY_SWAP__"
    },
    {
      "type": "disk",
      "key": "__KEY_DISK__",
      "folders": "/"
    },
    {
      "type": "command",
      "key": "__KEY_CPU_USAGE__",
      "shell": "bash",
      "text": "read cpu u n s i w ir si st _ < /proc/stat; idle1=$((i+w)); total1=$((u+n+s+i+w+ir+si+st)); sleep 1.5; read cpu u n s i w ir si st _ < /proc/stat; idle2=$((i+w)); total2=$((u+n+s+i+w+ir+si+st)); dt=$((total2-total1)); di=$((idle2-idle1)); awk -v dt=\"$dt\" -v di=\"$di\" 'BEGIN{if(dt>0) printf \"%.1f%%\", (dt-di)*100/dt; else print \"N/A\"}'"
    },
    {
      "type": "command",
      "key": "__KEY_ZFS__",
      "shell": "bash",
      "text": "command -v zpool >/dev/null 2>&1 || { echo '__TXT_NO_ZPOOL__'; exit; }; out=$(zpool list -H -o name,health 2>/dev/null | awk '{printf \"%s=%s \",$1,$2}'); echo \"${out:-__TXT_NO_POOL__}\""
    },

    "break",

    {
      "type": "custom",
      "format": "\u001b[48;5;208m\u001b[30m__SECTION_NET__\u001b[0m"
    },

    {
      "type": "localip",
      "key": "__KEY_LOCALIP__",
      "showIpv6": false
    },
    {
      "type": "dns",
      "key": "__KEY_DNS__"
    },
    {
      "type": "command",
      "key": "__KEY_BRIDGE__",
      "shell": "bash",
      "text": "state=$(cat /sys/class/net/__BRIDGE__/operstate 2>/dev/null || echo '__TXT_ABSENT__'); stp=$(cat /sys/class/net/__BRIDGE__/bridge/stp_state 2>/dev/null || echo '?'); case \"$stp\" in 1) stp=on ;; 0) stp=off ;; *) stp=? ;; esac; n=0; for x in /sys/class/net/__BRIDGE__/brif/*; do [ -e \"$x\" ] || continue; p=${x##*/}; [ -e \"/sys/class/net/$p/device\" ] && n=$((n+1)); done; echo \"${state^^} | STP=$stp | __TXT_PORTS__=$n\""
    },
__CERT_MODULE__
    {
      "type": "command",
      "key": "__KEY_PUBIP__",
      "shell": "bash",
      "text": "command -v curl >/dev/null 2>&1 && curl -fsS --max-time 2 https://ipinfo.io/ip 2>/dev/null || echo N/A"
    },
    {
      "type": "command",
      "key": "__KEY_F2B__",
      "shell": "bash",
      "text": "command -v fail2ban-client >/dev/null 2>&1 || { echo '__TXT_ABSENT__'; exit; }; J=$(fail2ban-client status 2>/dev/null | sed -n 's/.*Jail list:[[:space:]]*//p' | tr ',' ' '); [ -z \"$J\" ] && { echo '__TXT_NO_JAIL__'; exit; }; out=\"\"; for j in $J; do CUR=$(fail2ban-client status \"$j\" 2>/dev/null | awk '/Currently banned:/ {print $NF; exit}'); TOT=$(fail2ban-client status \"$j\" 2>/dev/null | awk '/Total banned:/ {print $NF; exit}'); CUR=${CUR:-0}; TOT=${TOT:-0}; if [ \"$TOT\" -gt 0 ] 2>/dev/null; then out=\"$out$j=$CUR($TOT) \"; else out=\"$out$j=$CUR \"; fi; done; echo \"${out:-__TXT_NO_JAIL__}\""
    }
  ]
}
EOF_CONFIG
}

# Placeholders keep the JSON template free of shell expansion, so the embedded
# shell snippets stay exactly as Fastfetch will run them.
render_config() {
    local cert_host="$1" cert_port="$2"
    local content cert_block="" bridge placeholder
    local newline=$'\n'

    bridge="$(detect_bridge)"

    if [[ -n "$cert_host" ]]; then
        cert_block="$(cert_module_block)${newline}"
    fi

    declare -A values=(
        ["__MARKER__"]="$MANAGED_MARKER"
        ["__SECTION_HOST__"]="$(tr_msg cfg_section_host)"
        ["__SECTION_RES__"]="$(tr_msg cfg_section_res)"
        ["__SECTION_NET__"]="$(tr_msg cfg_section_net)"
        ["__KEY_OS__"]="$(tr_msg cfg_key_os)"
        ["__KEY_PVE__"]="$(tr_msg cfg_key_pve)"
        ["__KEY_HOST__"]="$(tr_msg cfg_key_host)"
        ["__KEY_KERNEL__"]="$(tr_msg cfg_key_kernel)"
        ["__KEY_UPTIME__"]="$(tr_msg cfg_key_uptime)"
        ["__KEY_CPU__"]="$(tr_msg cfg_key_cpu)"
        ["__KEY_GPU__"]="$(tr_msg cfg_key_gpu)"
        ["__KEY_MEMORY__"]="$(tr_msg cfg_key_memory)"
        ["__KEY_SWAP__"]="$(tr_msg cfg_key_swap)"
        ["__KEY_DISK__"]="$(tr_msg cfg_key_disk)"
        ["__KEY_CPU_USAGE__"]="$(tr_msg cfg_key_cpu_usage)"
        ["__KEY_ZFS__"]="$(tr_msg cfg_key_zfs)"
        ["__KEY_LOCALIP__"]="$(tr_msg cfg_key_localip)"
        ["__KEY_DNS__"]="$(tr_msg cfg_key_dns)"
        ["__KEY_CERT__"]="$(tr_msg cfg_key_cert)"
        ["__KEY_PUBIP__"]="$(tr_msg cfg_key_pubip)"
        ["__KEY_F2B__"]="$(tr_msg cfg_key_f2b)"
        ["__KEY_BRIDGE__"]="$(printf '  🌉  %-14s' "$bridge")"
        ["__BRIDGE__"]="$bridge"
        ["__TXT_NO_ZPOOL__"]="$(tr_msg cfg_txt_no_zpool)"
        ["__TXT_NO_POOL__"]="$(tr_msg cfg_txt_no_pool)"
        ["__TXT_PORTS__"]="$(tr_msg cfg_txt_ports)"
        ["__TXT_ABSENT__"]="$(tr_msg cfg_txt_absent)"
        ["__TXT_NO_JAIL__"]="$(tr_msg cfg_txt_no_jail)"
        ["__TXT_UNAVAILABLE__"]="$(tr_msg cfg_txt_unavailable)"
        ["__TXT_EXPIRES__"]="$(tr_msg cfg_txt_expires)"
        ["__TXT_DAYS__"]="$(tr_msg cfg_txt_days)"
        ["__DATE_FMT__"]="$(tr_msg cfg_date_fmt)"
        ["__CERT_HOST__"]="$cert_host"
        ["__CERT_PORT__"]="$cert_port"
    )

    content="$(config_template)"
    # Without a FQDN the placeholder line disappears entirely, which keeps the
    # surrounding JSON valid.
    # Replacements stay quoted: an unquoted & would be expanded to the matched
    # text by bash 5.2 and would corrupt the embedded shell snippets.
    content="${content/__CERT_MODULE__${newline}/"$cert_block"}"

    for placeholder in "${!values[@]}"; do
        content="${content//"$placeholder"/"${values[$placeholder]}"}"
    done

    printf '%s\n' "$content"
}

write_config() {
    local cert_host="$1" cert_port="$2"

    if [[ -f "$CONFIG_FILE" ]] && ! config_is_managed; then
        say_warn "$(tr_msg config_custom_found)"
    fi
    backup_current_config

    mkdir -p "$CONFIG_DIR"
    render_config "$cert_host" "$cert_port" >"$CONFIG_FILE"
    chmod 0644 "$CONFIG_FILE"

    say_ok "$(tr_msg config_written): ${PMX_CYAN}${CONFIG_FILE}${RESET}"
    say_info "$(tr_msg bridge_detected): ${BOLD}$(detect_bridge)${RESET}"
    if [[ -n "$cert_host" ]]; then
        say_info "$(tr_msg cert_enabled): ${BOLD}${cert_host}:${cert_port}${RESET}"
    fi
}

# ------------------------------------------------------------
# Login display and Debian MOTD
# ------------------------------------------------------------

profile_is_managed() {
    [[ -f "$PROFILE_FILE" ]] && grep -qF "$MANAGED_MARKER" "$PROFILE_FILE"
}

write_profile_hook() {
    cat >"$PROFILE_FILE" <<EOF_PROFILE
# ${MANAGED_MARKER}

# Nothing is printed in a non interactive session.
# This matters on Proxmox: SSH scripts, file transfers, automation.
case \$- in
    *i*) ;;
    *) return ;;
esac

# Root only.
[ "\$(id -u)" -eq 0 ] || return

# Show Fastfetch when it is installed.
command -v fastfetch >/dev/null 2>&1 && fastfetch
EOF_PROFILE

    chmod 0755 "$PROFILE_FILE"
    say_ok "$(tr_msg profile_written): ${PMX_CYAN}${PROFILE_FILE}${RESET}"
}

disable_debian_motd() {
    local changed=0

    if [[ -f "$UNAME_MOTD_FILE" && -x "$UNAME_MOTD_FILE" ]]; then
        chmod -x "$UNAME_MOTD_FILE"
        changed=1
    fi

    if [[ -f "$MOTD_FILE" && -s "$MOTD_FILE" ]]; then
        truncate -s 0 "$MOTD_FILE"
        changed=1
    fi

    [[ "$changed" -eq 1 ]] && say_ok "$(tr_msg motd_disabled)"
    return 0
}

restore_debian_motd() {
    if [[ ! -d "$ORIGINAL_DIR" ]]; then
        say_info "$(tr_msg motd_nothing_to_restore)"
        return 0
    fi

    [[ -f "${ORIGINAL_DIR}/motd" ]] && cp -a "${ORIGINAL_DIR}/motd" "$MOTD_FILE"

    if [[ "$(original_info_value motd_uname)" == "executable" && -f "$UNAME_MOTD_FILE" ]]; then
        chmod +x "$UNAME_MOTD_FILE"
    fi

    say_ok "$(tr_msg motd_restored)"
}

# ------------------------------------------------------------
# Actions
# ------------------------------------------------------------

ask_cert_target() {
    local answer host port

    panel "$PMX_BLUE" "$(tr_msg cert_title)" \
        "$(tr_msg cert_body_1)" \
        "$(tr_msg cert_body_2)" \
        "$(tr_msg cert_body_3)"
    echo

    while true; do
        answer="$(prompt_free "$(tr_msg cert_prompt)")"
        answer="${answer//[[:space:]]/}"

        if [[ -z "$answer" ]]; then
            CERT_HOST=""
            CERT_PORT=""
            return 0
        fi

        if validate_cert_target "$answer"; then
            break
        fi

        say_err "$(tr_msg cert_invalid)"
    done

    host="${answer%%:*}"
    port="443"
    [[ "$answer" == *:* ]] && port="${answer##*:}"

    CERT_HOST="$host"
    CERT_PORT="$port"
}

install_all() {
    CERT_HOST=""
    CERT_PORT=""

    panel "$PMX_AMBER" "$(tr_msg warning_title)" \
        "$(tr_msg warning_body_1)" \
        "$(tr_msg warning_body_2)" \
        "$(tr_msg warning_body_3)" \
        "$(tr_msg warning_body_4)"
    echo

    if ! confirm_default_yes "$(tr_msg confirm_install)"; then
        say_info "$(tr_msg cancelled)"
        return 0
    fi

    ask_cert_target

    echo
    install_fastfetch || return 1

    save_original_state
    write_config "$CERT_HOST" "$CERT_PORT"
    write_profile_hook
    disable_debian_motd

    panel "$PMX_GREEN" "$(tr_msg done_title)" \
        "$(tr_msg reconnect_hint)"
}

configure_cert() {
    local current

    if ! config_is_managed; then
        say_err "$(tr_msg need_config_first)"
        return 1
    fi

    current="$(configured_cert_target)"
    if [[ -n "$current" ]]; then
        say_info "$(tr_msg status_cert): ${BOLD}${current}${RESET}"
    else
        say_info "$(tr_msg cert_disabled)"
    fi

    CERT_HOST=""
    CERT_PORT=""
    ask_cert_target

    write_config "$CERT_HOST" "$CERT_PORT"
    [[ -z "$CERT_HOST" ]] && say_info "$(tr_msg cert_disabled)"
    return 0
}

# Fastfetch itself is the judge: a configuration it refuses to parse never
# reaches the file the login shells read.
config_is_accepted() {
    local candidate="$1" errors
    errors="$(fastfetch --config "$candidate" 2>&1 >/dev/null || true)"
    [[ -z "$errors" ]] && return 0
    printf '%s\n' "$errors" | sed -e 's/^/  /' >&2
    return 1
}

paste_custom_config() {
    local workdir candidate line lines=0

    if ! fastfetch_is_installed; then
        say_err "$(tr_msg need_install_first)"
        return 1
    fi

    panel "$PMX_BLUE" "$(tr_msg paste_title)" \
        "$(tr_msg paste_body_1)" \
        "$(tr_msg paste_body_2)" \
        "$(tr_msg paste_body_3)"
    echo
    say_info "$(tr_msg paste_waiting)"
    echo

    # Fastfetch only reads a config whose name carries a known extension.
    workdir="$(mktemp -d)"
    candidate="${workdir}/config.jsonc"

    while IFS= read -r line; do
        [[ "$line" == "EOF" ]] && break
        printf '%s\n' "$line" >>"$candidate"
        lines=$((lines + 1))
    done

    if [[ ! -s "$candidate" ]]; then
        rm -rf "$workdir"
        echo
        say_info "$(tr_msg paste_empty)"
        return 0
    fi

    echo
    say_info "$(tr_msg paste_received): ${BOLD}${lines}${RESET}"

    if ! step "$(tr_msg paste_checking)" config_is_accepted "$candidate"; then
        rm -rf "$workdir"
        say_err "$(tr_msg paste_invalid)"
        return 1
    fi

    backup_current_config

    mkdir -p "$CONFIG_DIR"
    cp -a "$candidate" "$CONFIG_FILE"
    rm -rf "$workdir"
    chmod 0644 "$CONFIG_FILE"

    say_ok "$(tr_msg paste_installed): ${PMX_CYAN}${CONFIG_FILE}${RESET}"
    profile_is_managed || say_warn "$(tr_msg paste_login_hint)"

    if confirm_default_yes "$(tr_msg preview_question)"; then
        echo
        fastfetch --config "$CONFIG_FILE"
    fi
}

preview_fastfetch() {
    if ! fastfetch_is_installed; then
        say_err "$(tr_msg need_install_first)"
        return 1
    fi
    if [[ ! -f "$CONFIG_FILE" ]]; then
        say_err "$(tr_msg need_config_first)"
        return 1
    fi

    say_info "$(tr_msg preview_note)"
    echo
    fastfetch --config "$CONFIG_FILE"
}

show_status() {
    local ff_state config_state cert_state login_state motd_state cert_target
    local installed backups

    installed="$(installed_fastfetch_version)"
    if fastfetch_is_installed; then
        ff_state="${PMX_GREEN}$(tr_msg status_installed)${RESET} ${BOLD}${installed:-?}${RESET}"
    else
        ff_state="${PMX_GREY}$(tr_msg status_not_installed)${RESET}"
    fi

    if config_is_managed; then
        config_state="${PMX_GREEN}$(tr_msg status_managed)${RESET}"
    elif [[ -f "$CONFIG_FILE" ]]; then
        config_state="${PMX_AMBER}$(tr_msg status_custom)${RESET}"
    else
        config_state="${PMX_GREY}$(tr_msg status_absent)${RESET}"
    fi

    cert_target="$(configured_cert_target)"
    if [[ -n "$cert_target" ]]; then
        cert_state="${PMX_GREEN}$(tr_msg status_active)${RESET} ${BOLD}${cert_target}${RESET}"
    else
        cert_state="${PMX_GREY}$(tr_msg status_disabled)${RESET}"
    fi

    if profile_is_managed; then
        login_state="${PMX_GREEN}$(tr_msg status_enabled)${RESET}"
    else
        login_state="${PMX_GREY}$(tr_msg status_disabled)${RESET}"
    fi

    if [[ -x "$UNAME_MOTD_FILE" || -s "$MOTD_FILE" ]]; then
        motd_state="${PMX_AMBER}$(tr_msg status_active)${RESET}"
    else
        motd_state="${PMX_GREEN}$(tr_msg status_disabled)${RESET}"
    fi

    backups="$(find "$(dirname "$BACKUP_PREFIX")" -maxdepth 1 -type d -name "$(basename "$BACKUP_PREFIX")-*" 2>/dev/null | wc -l)"

    panel "$PMX_ORANGE" "$(tr_msg status_title)" \
        "$(tr_msg status_fastfetch): ${ff_state}" \
        "$(tr_msg status_config): ${config_state}" \
        "$(tr_msg status_cert): ${cert_state}" \
        "$(tr_msg status_login): ${login_state}" \
        "$(tr_msg status_motd): ${motd_state}" \
        "$(tr_msg status_backups): ${BOLD}${backups}${RESET} ${PMX_CYAN}${BACKUP_PREFIX}-*${RESET}"
}

disable_login_display() {
    if [[ ! -f "$PROFILE_FILE" ]]; then
        say_info "$(tr_msg login_already_absent)"
    elif ! profile_is_managed; then
        say_warn "$(tr_msg profile_not_managed): ${PMX_CYAN}${PROFILE_FILE}${RESET}"
        return 0
    else
        rm -f "$PROFILE_FILE"
        say_ok "$(tr_msg login_removed)"
    fi

    restore_debian_motd
    say_info "$(tr_msg reconnect_hint)"
}

remove_everything() {
    panel "$PMX_AMBER" "$(tr_msg remove_all_title)" \
        "$(tr_msg remove_all_body_1)" \
        "$(tr_msg remove_all_body_2)"

    if ! confirm_yes; then
        say_info "$(tr_msg cancelled)"
        return 0
    fi
    echo

    disable_login_display

    if [[ -f "$CONFIG_FILE" ]]; then
        backup_current_config
        rm -f "$CONFIG_FILE"
        rmdir "$CONFIG_DIR" 2>/dev/null || true
        say_ok "$(tr_msg config_removed): ${PMX_CYAN}${CONFIG_FILE}${RESET}"
    fi

    if [[ -n "$(installed_fastfetch_version)" ]]; then
        if ! step "$(tr_msg removing_package)" apt_purge_fastfetch; then
            say_err "$(tr_msg remove_package_failed)"
            return 1
        fi
    fi

    say_ok "$(tr_msg remove_all_done)"
    [[ -d "$ORIGINAL_DIR" ]] && say_info "$(tr_msg backups_kept): ${PMX_CYAN}${ORIGINAL_DIR}${RESET}"
    return 0
}

# Menu entries report their own errors on screen; a failed action must bring
# the user back to the menu instead of ending the session through set -e.
menu_action() {
    "$@" || true
}

main_menu() {
    while true; do
        show_banner
        printf " %b1)%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$(tr_msg menu_install)"
        printf " %b2)%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$(tr_msg menu_cert)"
        printf " %b3)%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$(tr_msg menu_custom)"
        printf " %b4)%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$(tr_msg menu_preview)"
        printf " %b5)%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$(tr_msg menu_status)"
        printf " %b6)%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$(tr_msg menu_disable_login)"
        printf " %b7)%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$(tr_msg menu_remove_all)"
        printf " %b8)%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$(tr_msg menu_quit)"
        echo

        read -r -p "$(tr_msg choose_option) [1-8]: " choice
        echo

        case "$choice" in
            1)
                menu_action install_all
                pause
                ;;
            2)
                menu_action configure_cert
                pause
                ;;
            3)
                menu_action paste_custom_config
                pause
                ;;
            4)
                menu_action preview_fastfetch
                pause
                ;;
            5)
                menu_action show_status
                pause
                ;;
            6)
                menu_action disable_login_display
                pause
                ;;
            7)
                menu_action remove_everything
                pause
                ;;
            8)
                say_info "$(tr_msg bye)"
                exit 0
                ;;
            *)
                say_err "$(tr_msg invalid_choice)"
                pause
                ;;
        esac
    done
}

CERT_HOST=""
CERT_PORT=""

require_root
require_pve
require_tools
main_menu
