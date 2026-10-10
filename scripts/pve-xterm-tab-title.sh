#!/usr/bin/env bash
set -euo pipefail

PATCH_PREFIX="/root/pve-xterm-tab-title-patch"
MAIN_FILE="/usr/share/pve-xtermjs/main.js"

# The xterm.js console page reads the guest name into vmname, but its title
# only shows the node name from the template. The added lines set the title
# after the cmdOpts line. The name is decoded because getQueryParameter returns
# it percent-encoded. Patch and state check match these exact lines, so a file
# that looks different is reported instead of patched blindly.
ANCHOR="var cmdOpts = getQueryParameter('cmd-opts');
"
ADDED="// The name arrives percent-encoded in the URL, getQueryParameter does not decode it.
document.title = [vmid && vmid + (vmname ? ' (' + decodeURIComponent(vmname) + ')' : ''), nodename, 'PVE'].filter(Boolean).join(' . ');
"

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
        fr:menu_apply) echo "Appliquer le patch (backup automatique inclus)" ;;
        en:menu_apply) echo "Apply patch (automatic backup included)" ;;

        fr:menu_restore_latest) echo "Restaurer le dernier backup" ;;
        en:menu_restore_latest) echo "Restore latest backup" ;;

        fr:menu_restore_select) echo "Restaurer depuis un backup choisi" ;;
        en:menu_restore_select) echo "Restore from selected backup" ;;

        fr:menu_status) echo "Afficher l'état du patch" ;;
        en:menu_status) echo "Show patch status" ;;

        fr:menu_backups) echo "Lister les backups" ;;
        en:menu_backups) echo "List backups" ;;

        fr:menu_quit) echo "Quitter" ;;
        en:menu_quit) echo "Quit" ;;

        fr:choose_option) echo "Choisissez une option" ;;
        en:choose_option) echo "Choose an option" ;;

        fr:press_enter) echo "Appuyez sur Entrée pour continuer..." ;;
        en:press_enter) echo "Press Enter to continue..." ;;

        fr:cancelled) echo "Opération annulée." ;;
        en:cancelled) echo "Operation cancelled." ;;

        fr:running_as_root) echo "Ce script doit être lancé en root." ;;
        en:running_as_root) echo "This script must be run as root." ;;

        fr:file_not_found) echo "Fichier introuvable" ;;
        en:file_not_found) echo "File not found" ;;

        fr:backup_created) echo "Backup créé" ;;
        en:backup_created) echo "Backup created" ;;

        fr:patch_applied) echo "Patch appliqué avec succès." ;;
        en:patch_applied) echo "Patch applied successfully." ;;

        fr:reopen_console) echo "Aucun redémarrage n'est nécessaire : ouvrez une nouvelle console." ;;
        en:reopen_console) echo "No restart is needed: open a new console." ;;

        fr:cache_hint) echo "Un navigateur peut garder l'ancien fichier en cache plusieurs jours, un simple rafraîchissement ne suffit pas toujours. Vérifiez dans une fenêtre de navigation privée, puis videz les données du site dans chaque navigateur utilisé." ;;
        en:cache_hint) echo "A browser can keep the old file in its cache for days, a plain refresh is not always enough. Check in a private window, then clear the site data in each browser you use." ;;

        fr:backup_used) echo "Backup utilisé" ;;
        en:backup_used) echo "Backup used" ;;

        fr:no_backup_found) echo "Aucun backup trouvé." ;;
        en:no_backup_found) echo "No backup found." ;;

        fr:restore_done) echo "Restauration terminée depuis" ;;
        en:restore_done) echo "Restore completed from" ;;

        fr:invalid_choice) echo "Choix invalide." ;;
        en:invalid_choice) echo "Invalid choice." ;;

        fr:selection_out_of_range) echo "Sélection hors limite." ;;
        en:selection_out_of_range) echo "Selection out of range." ;;

        fr:restore_cancelled) echo "Restauration annulée." ;;
        en:restore_cancelled) echo "Restore cancelled." ;;

        fr:detected_language) echo "Langue détectée" ;;
        en:detected_language) echo "Detected language" ;;

        fr:lang_fr) echo "Français" ;;
        en:lang_fr) echo "French" ;;

        fr:lang_en) echo "Anglais" ;;
        en:lang_en) echo "English" ;;

        fr:status_title) echo "État du patch" ;;
        en:status_title) echo "Patch status" ;;

        fr:detected_version) echo "Version détectée" ;;
        en:detected_version) echo "Detected version" ;;

        fr:status_tab_title) echo "Titre des onglets xterm.js" ;;
        en:status_tab_title) echo "xterm.js tab title" ;;

        fr:state_patched) echo "ID (Nom) . Noeud . PVE (patch actif)" ;;
        en:state_patched) echo "ID (Name) . Node . PVE (patch active)" ;;

        fr:state_stock) echo "nom du noeud seul (valeur par défaut de Proxmox)" ;;
        en:state_stock) echo "node name only (Proxmox default)" ;;

        fr:state_unknown) echo "structure du fichier inattendue" ;;
        en:state_unknown) echo "unexpected file structure" ;;

        fr:available_backups) echo "Backups disponibles" ;;
        en:available_backups) echo "Available backups" ;;

        fr:choose_backup_number) echo "Choisissez le numéro du backup à restaurer" ;;
        en:choose_backup_number) echo "Choose a backup number to restore" ;;

        fr:bye) echo "À bientôt." ;;
        en:bye) echo "Bye." ;;

        fr:already_patched) echo "Le patch est déjà présent. Aucune modification appliquée." ;;
        en:already_patched) echo "The patch is already present. No changes applied." ;;

        fr:patch_incompatible) echo "Le code attendu n'a pas été trouvé. Cette version de pve-xtermjs n'est pas prise en charge par ce patch." ;;
        en:patch_incompatible) echo "The expected code was not found. This pve-xtermjs version is not supported by this patch." ;;

        fr:no_file_modified) echo "Aucun fichier n'a été modifié." ;;
        en:no_file_modified) echo "No file has been modified." ;;

        fr:patch_failed) echo "Le patch a échoué." ;;
        en:patch_failed) echo "The patch failed." ;;

        fr:missing_python) echo "python3 est requis." ;;
        en:missing_python) echo "python3 is required." ;;

        fr:missing_sha256sum) echo "sha256sum est requis." ;;
        en:missing_sha256sum) echo "sha256sum is required." ;;

        fr:warning_title) echo "AVERTISSEMENT" ;;
        en:warning_title) echo "WARNING" ;;

        fr:warning_body_1) echo "Ce script modifie un fichier JavaScript du paquet pve-xtermjs, qui affiche les consoles xterm.js (conteneurs, shell de l'hôte, VM)." ;;
        en:warning_body_1) echo "This script modifies a JavaScript file of the pve-xtermjs package, which draws the xterm.js consoles (containers, host shell, VMs)." ;;

        fr:warning_body_2) echo "Ceci est hors support et sera écrasé par les mises à jour du paquet pve-xtermjs, il faudra alors relancer le script." ;;
        en:warning_body_2) echo "This is unsupported and will be overwritten by pve-xtermjs package updates, in which case you need to run the script again." ;;

        fr:warning_body_3) echo "Les consoles noVNC et SPICE ne sont pas touchées par ce script." ;;
        en:warning_body_3) echo "The noVNC and SPICE consoles are not affected by this script." ;;

        fr:type_yes) echo "Tapez 'yes' pour continuer" ;;
        en:type_yes) echo "Type 'yes' to continue" ;;

        fr:version_mismatch_title) echo "VERSION DIFFÉRENTE" ;;
        en:version_mismatch_title) echo "VERSION MISMATCH" ;;

        fr:version_mismatch_body) echo "Ce backup a été pris sur une autre version de pve-xtermjs. Restaurer ce fichier sur la version actuelle peut casser les consoles." ;;
        en:version_mismatch_body) echo "This backup was taken on a different pve-xtermjs version. Restoring this file on the current version may break the consoles." ;;

        fr:version_in_backup) echo "Dans le backup" ;;
        en:version_in_backup) echo "In the backup" ;;

        fr:version_installed) echo "Installé" ;;
        en:version_installed) echo "Installed" ;;

        fr:banner_subtitle) echo "Console Tab Title" ;;
        en:banner_subtitle) echo "Console Tab Title" ;;

        fr:repo_hint) echo "Titre des onglets xterm.js : ID (Nom) . Noeud . PVE" ;;
        en:repo_hint) echo "xterm.js console tab titles: ID (Name) . Node . PVE" ;;

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
say_err()  { printf "%b✗%b %b\n" "${PMX_RED}" "${RESET}" "$*" >&2; }

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

require_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        say_err "$(tr_msg running_as_root)"
        exit 1
    fi
}

require_files() {
    [[ -f "$MAIN_FILE" ]] || { say_err "$(tr_msg file_not_found): $MAIN_FILE"; exit 1; }
    command -v python3 >/dev/null 2>&1 || { say_err "$(tr_msg missing_python)"; exit 1; }
    command -v sha256sum >/dev/null 2>&1 || { say_err "$(tr_msg missing_sha256sum)"; exit 1; }
}

show_warning_and_confirm() {
    panel "$PMX_AMBER" "$(tr_msg warning_title)" \
        "$(tr_msg warning_body_1)" \
        "$(tr_msg warning_body_2)" \
        "$(tr_msg warning_body_3)"

    if ! confirm_yes; then
        say_info "$(tr_msg cancelled)"
        return 1
    fi
    return 0
}

# ------------------------------------------------------------
# Patch state
# ------------------------------------------------------------

# Prints stock, patched or unknown. The anchor must occur exactly once, and the
# added lines must be exactly one copy right after it.
get_state() {
    MAIN_FILE="$MAIN_FILE" ANCHOR="$ANCHOR" ADDED="$ADDED" python3 <<'PY'
from pathlib import Path
import os

text = Path(os.environ["MAIN_FILE"]).read_text(encoding="utf-8")
anchor = os.environ["ANCHOR"]
added = os.environ["ADDED"]

patched = text.count(anchor + added)
if text.count(anchor) != 1 or patched > 1:
    print("unknown")
elif patched == 1:
    print("patched")
else:
    print("stock")
PY
}

apply_python_patch() {
    MAIN_FILE="$MAIN_FILE" ANCHOR="$ANCHOR" ADDED="$ADDED" python3 <<'PY'
from pathlib import Path
import os
import sys

main_path = Path(os.environ["MAIN_FILE"])
text = main_path.read_text(encoding="utf-8")
anchor = os.environ["ANCHOR"]

if text.count(anchor) != 1:
    sys.exit(1)

main_path.write_text(text.replace(anchor, anchor + os.environ["ADDED"], 1), encoding="utf-8")
PY
}

# ------------------------------------------------------------
# Backups
# ------------------------------------------------------------

latest_backup_dir() {
    find /root -maxdepth 1 -type d -name 'pve-xterm-tab-title-patch-*' | sort | tail -n1
}

list_backups_raw() {
    find /root -maxdepth 1 -type d -name 'pve-xterm-tab-title-patch-*' | sort
}

create_backup() {
    local ts dir
    ts="$(date +%F-%H%M%S)"
    dir="${PATCH_PREFIX}-${ts}"
    mkdir -p "$dir"

    cp -av "$MAIN_FILE" "$dir/" >/dev/null

    {
        echo "created_at=$(date --iso-8601=seconds)"
        echo "hostname=$(hostname)"
        echo "main_file=$MAIN_FILE"
        echo
        pveversion -v 2>/dev/null || true
    } >"$dir/INFO.txt"

    sha256sum "$dir/$(basename "$MAIN_FILE")" >"$dir/SHA256SUMS.txt"
    echo "$dir"
}

pkg_version_from_backup() {
    local dir="$1" pkg="$2"
    [[ -f "$dir/INFO.txt" ]] || return 0
    sed -n "s/^${pkg}: \([^ ]*\).*/\1/p" "$dir/INFO.txt" | head -n1 || true
}

installed_pkg_version() {
    local pkg="$1"
    pveversion -v 2>/dev/null | sed -n "s/^${pkg}: \([^ ]*\).*/\1/p" | head -n1 || true
}

# ------------------------------------------------------------
# Actions
# ------------------------------------------------------------

show_status() {
    local xt_version state state_label

    xt_version="$(installed_pkg_version pve-xtermjs)"
    state="$(get_state)"

    case "$state" in
        patched) state_label="${PMX_GREEN}$(tr_msg state_patched)${RESET}" ;;
        stock) state_label="${PMX_GREY}$(tr_msg state_stock)${RESET}" ;;
        *) state_label="${PMX_AMBER}$(tr_msg state_unknown)${RESET}" ;;
    esac

    panel "$PMX_ORANGE" "$(tr_msg status_title)" \
        "$(tr_msg detected_version): pve-xtermjs ${BOLD}${xt_version:-?}${RESET}" \
        "$(tr_msg status_tab_title): ${BOLD}${state_label}"
}

apply_patch() {
    local backup_dir state

    state="$(get_state)"
    case "$state" in
        stock) ;;
        patched)
            say_ok "$(tr_msg already_patched)"
            return 0
            ;;
        *)
            say_err "$(tr_msg patch_incompatible)"
            say_info "$(tr_msg no_file_modified)"
            return 1
            ;;
    esac

    show_warning_and_confirm || return 0

    backup_dir="$(create_backup)"
    say_info "$(tr_msg backup_created): ${PMX_CYAN}${backup_dir}${RESET}"

    if ! apply_python_patch || [[ "$(get_state)" != "patched" ]]; then
        say_err "$(tr_msg patch_failed)"
        say_info "$(tr_msg backup_used): ${PMX_CYAN}${backup_dir}${RESET}"
        return 1
    fi

    echo
    say_ok "$(tr_msg patch_applied)"
    say_info "$(tr_msg reopen_console)"
    say_info "$(tr_msg cache_hint)"
    say_info "$(tr_msg backup_used): ${PMX_CYAN}${backup_dir}${RESET}"
}

confirm_backup_versions() {
    local dir="$1"
    local backup_version installed_version

    backup_version="$(pkg_version_from_backup "$dir" pve-xtermjs)"
    installed_version="$(installed_pkg_version pve-xtermjs)"

    [[ -n "$backup_version" && -n "$installed_version" ]] || return 0
    [[ "$backup_version" != "$installed_version" ]] || return 0

    panel "$PMX_AMBER" "$(tr_msg version_mismatch_title)" \
        "$(tr_msg version_mismatch_body)" \
        "pve-xtermjs · $(tr_msg version_in_backup) ${BOLD}${backup_version}${RESET} · $(tr_msg version_installed) ${BOLD}${installed_version}${RESET}"

    if ! confirm_yes; then
        say_info "$(tr_msg restore_cancelled)"
        return 1
    fi
    return 0
}

restore_specific() {
    local dir="$1"
    [[ -d "$dir" ]] || { say_err "$(tr_msg file_not_found): $dir"; return 1; }
    [[ -f "$dir/$(basename "$MAIN_FILE")" ]] || { say_err "$(tr_msg file_not_found): $dir/$(basename "$MAIN_FILE")"; return 1; }

    confirm_backup_versions "$dir" || return 0

    cp -av "$dir/$(basename "$MAIN_FILE")" "$MAIN_FILE"

    say_ok "$(tr_msg restore_done): ${PMX_CYAN}${dir}${RESET}"
}

restore_latest() {
    local dir
    dir="$(latest_backup_dir)"
    if [[ -z "$dir" ]]; then
        say_err "$(tr_msg no_backup_found)"
        return 1
    fi
    restore_specific "$dir"
}

interactive_restore_menu() {
    mapfile -t backups < <(list_backups_raw)

    if [[ "${#backups[@]}" -eq 0 ]]; then
        say_err "$(tr_msg no_backup_found)"
        pause
        return
    fi

    local lines=()
    local i=1
    for b in "${backups[@]}"; do
        lines+=("${PMX_ORANGE_SOFT}${i})${RESET} ${b}")
        ((i++))
    done
    lines+=("${PMX_GREY}q) $(tr_msg cancelled)${RESET}")

    panel "$PMX_ORANGE" "$(tr_msg available_backups)" "${lines[@]}"
    echo

    read -r -p "$(tr_msg choose_backup_number): " choice

    if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
        say_info "$(tr_msg restore_cancelled)"
        pause
        return
    fi

    if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
        say_err "$(tr_msg invalid_choice)"
        pause
        return
    fi

    if (( choice < 1 || choice > ${#backups[@]} )); then
        say_err "$(tr_msg selection_out_of_range)"
        pause
        return
    fi

    restore_specific "${backups[$((choice-1))]}"
    pause
}

show_backups() {
    panel "$PMX_ORANGE" "$(tr_msg available_backups)"
    echo
    list_backups_raw || true
    pause
}

# Menu entries report their own errors on screen; a failed action must bring
# the user back to the menu instead of ending the session through set -e.
menu_action() {
    "$@" || true
}

main_menu() {
    while true; do
        show_banner
        printf " %b1)%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$(tr_msg menu_apply)"
        printf " %b2)%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$(tr_msg menu_restore_latest)"
        printf " %b3)%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$(tr_msg menu_restore_select)"
        printf " %b4)%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$(tr_msg menu_status)"
        printf " %b5)%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$(tr_msg menu_backups)"
        printf " %b6)%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$(tr_msg menu_quit)"
        echo

        read -r -p "$(tr_msg choose_option) [1-6]: " choice
        echo

        case "$choice" in
            1)
                menu_action apply_patch
                pause
                ;;
            2)
                menu_action restore_latest
                pause
                ;;
            3)
                menu_action interactive_restore_menu
                ;;
            4)
                menu_action show_status
                pause
                ;;
            5)
                menu_action show_backups
                ;;
            6)
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

require_root
require_files
main_menu
