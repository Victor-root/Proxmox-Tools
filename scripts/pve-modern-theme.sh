#!/usr/bin/env bash
set -euo pipefail

PATCH_PREFIX="/root/pve-modern-theme-patch"
THEME_DIR="/usr/share/javascript/proxmox-widget-toolkit/themes"
PX_FILE="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"
PVE_FILE="/usr/share/pve-manager/js/pvemanagerlib.js"
HELPER_DIR="/usr/local/lib/pve-modern-theme"
APT_HOOK_FILE="/etc/apt/apt.conf.d/99-pve-modern-theme"

# pveproxy loads /pwt/themes/theme-<name>.css for any name the PVEThemeCookie
# holds (kebab case, 10 letters per segment at most), and serves the files of
# that directory and proxmoxlib.js from disk on every request: dropping theme
# files in and patching the JavaScript needs no service restart. dpkg leaves
# files it does not own in place, so the themes survive package updates; only
# the JavaScript patches are lost, which the optional APT hook re-applies.

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
        fr:menu_apply) echo "Installer ou mettre à jour les thèmes (backup automatique inclus)" ;;
        en:menu_apply) echo "Install or update the themes (automatic backup included)" ;;

        fr:menu_restore_latest) echo "Restaurer le dernier backup" ;;
        en:menu_restore_latest) echo "Restore latest backup" ;;

        fr:menu_restore_select) echo "Restaurer depuis un backup choisi" ;;
        en:menu_restore_select) echo "Restore from selected backup" ;;

        fr:menu_status) echo "Afficher l'état" ;;
        en:menu_status) echo "Show status" ;;

        fr:menu_backups) echo "Lister les backups" ;;
        en:menu_backups) echo "List backups" ;;

        fr:menu_summary) echo "Option : panneau de statut des VM et conteneurs à la taille de son contenu (activer ou désactiver)" ;;
        en:menu_summary) echo "Option: guest status panel sized to its content (enable or disable)" ;;

        fr:menu_storage) echo "Option : tailles des stockages en Tio comme Windows (activer ou désactiver)" ;;
        en:menu_storage) echo "Option: storage sizes in TiB like Windows (enable or disable)" ;;

        fr:menu_hook_enable) echo "Réappliquer automatiquement après une mise à jour" ;;
        en:menu_hook_enable) echo "Re-apply automatically after an update" ;;

        fr:menu_hook_disable) echo "Ne plus réappliquer automatiquement" ;;
        en:menu_hook_disable) echo "Stop re-applying automatically" ;;

        fr:menu_uninstall) echo "Tout désinstaller" ;;
        en:menu_uninstall) echo "Uninstall everything" ;;

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

        fr:missing_python) echo "python3 est requis." ;;
        en:missing_python) echo "python3 is required." ;;

        fr:missing_sha256sum) echo "sha256sum est requis." ;;
        en:missing_sha256sum) echo "sha256sum is required." ;;

        fr:backup_created) echo "Backup créé" ;;
        en:backup_created) echo "Backup created" ;;

        fr:backup_used) echo "Backup utilisé" ;;
        en:backup_used) echo "Backup used" ;;

        fr:no_backup_found) echo "Aucun backup trouvé." ;;
        en:no_backup_found) echo "No backup found." ;;

        fr:restore_done) echo "Restauration terminée depuis" ;;
        en:restore_done) echo "Restore completed from" ;;

        fr:restore_themes_kept) echo "Les fichiers des thèmes restent en place : seul le code de Proxmox a été remis comme dans le backup." ;;
        en:restore_themes_kept) echo "The theme files stay in place: only the Proxmox code was put back as in the backup." ;;

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

        fr:status_title) echo "État" ;;
        en:status_title) echo "Status" ;;

        fr:detected_version) echo "Version détectée" ;;
        en:detected_version) echo "Detected version" ;;

        fr:status_themes) echo "Fichiers des thèmes" ;;
        en:status_themes) echo "Theme files" ;;

        fr:status_selector) echo "Thèmes dans le menu « Thème de couleur »" ;;
        en:status_selector) echo "Themes in the \"Color Theme\" menu" ;;

        fr:status_charts) echo "Couleurs des graphiques" ;;
        en:status_charts) echo "Chart colors" ;;

        fr:status_logs) echo "Bouton de repli du journal" ;;
        en:status_logs) echo "Log panel collapse button" ;;

        fr:status_summary) echo "Option panneau de statut" ;;
        en:status_summary) echo "Status panel option" ;;

        fr:status_storage) echo "Option tailles en Tio" ;;
        en:status_storage) echo "TiB sizes option" ;;

        fr:status_auto_reapply) echo "Réapplication automatique" ;;
        en:status_auto_reapply) echo "Automatic re-apply" ;;

        fr:state_installed) echo "installés" ;;
        en:state_installed) echo "installed" ;;

        fr:state_outdated) echo "incomplets ou d'une autre version" ;;
        en:state_outdated) echo "incomplete or from another version" ;;

        fr:state_absent) echo "absents" ;;
        en:state_absent) echo "absent" ;;

        fr:state_applied) echo "en place" ;;
        en:state_applied) echo "in place" ;;

        fr:state_stock) echo "d'origine" ;;
        en:state_stock) echo "stock" ;;

        fr:state_unknown) echo "code non reconnu (version non prise en charge)" ;;
        en:state_unknown) echo "code not recognized (unsupported version)" ;;

        fr:status_enabled) echo "activée" ;;
        en:status_enabled) echo "enabled" ;;

        fr:status_disabled) echo "désactivée" ;;
        en:status_disabled) echo "disabled" ;;

        fr:available_backups) echo "Backups disponibles" ;;
        en:available_backups) echo "Available backups" ;;

        fr:choose_backup_number) echo "Choisissez le numéro du backup à restaurer" ;;
        en:choose_backup_number) echo "Choose a backup number to restore" ;;

        fr:bye) echo "À bientôt." ;;
        en:bye) echo "Bye." ;;

        fr:already_installed) echo "Les thèmes sont déjà installés et à jour. Aucune modification appliquée." ;;
        en:already_installed) echo "The themes are already installed and up to date. No changes applied." ;;

        fr:incompatible) echo "Le code attendu n'a pas été trouvé. Cette version de Proxmox VE n'est pas prise en charge." ;;
        en:incompatible) echo "The expected code was not found. This Proxmox VE version is not supported." ;;

        fr:incompatible_part) echo "Partie concernée" ;;
        en:incompatible_part) echo "Part concerned" ;;

        fr:no_file_modified) echo "Aucun fichier n'a été modifié." ;;
        en:no_file_modified) echo "No file has been modified." ;;

        fr:install_failed) echo "L'installation n'a pas pu être vérifiée. Restaurez le backup avec l'option 2 pour revenir à l'état précédent." ;;
        en:install_failed) echo "The installation could not be verified. Restore the backup with option 2 to go back to the previous state." ;;

        fr:installed_ok) echo "Thèmes installés." ;;
        en:installed_ok) echo "Themes installed." ;;

        fr:how_to_choose) echo "Dans l'interface web : cliquez sur votre nom d'utilisateur en haut à droite, puis « Thème de couleur », et choisissez un thème « Modern »." ;;
        en:how_to_choose) echo "In the web interface: click your user name at the top right, then \"Color Theme\", and pick a \"Modern\" theme." ;;

        fr:browser_cache) echo "Le navigateur peut garder l'ancienne version des fichiers : videz son cache pour ce site, ou vérifiez d'abord dans une fenêtre de navigation privée." ;;
        en:browser_cache) echo "Your browser may keep the old copy of the files: clear its cache for this site, or check in a private window first." ;;

        fr:warning_title) echo "AVERTISSEMENT" ;;
        en:warning_title) echo "WARNING" ;;

        fr:warning_body_1) echo "Ce script ajoute 15 fichiers de thème dans ${THEME_DIR} et modifie deux fichiers JavaScript fournis par Proxmox VE : proxmoxlib.js (thèmes dans le menu, couleurs des graphiques) et pvemanagerlib.js (bouton de repli du journal)." ;;
        en:warning_body_1) echo "This script adds 15 theme files to ${THEME_DIR} and modifies two JavaScript files provided by Proxmox VE: proxmoxlib.js (themes in the menu, chart colors) and pvemanagerlib.js (log panel collapse button)." ;;

        fr:warning_body_2) echo "Ceci est hors support. Les mises à jour des paquets proxmox-widget-toolkit et pve-manager écrasent ces modifications : les thèmes restent installés mais disparaissent du menu, sauf si la réapplication automatique est activée." ;;
        en:warning_body_2) echo "This is unsupported. Updates of the proxmox-widget-toolkit and pve-manager packages overwrite these changes: the themes stay installed but leave the menu, unless automatic re-apply is enabled." ;;

        fr:warning_body_3) echo "Aucun service n'est redémarré : pveproxy relit ces fichiers à chaque chargement de page." ;;
        en:warning_body_3) echo "No service is restarted: pveproxy reads these files on every page load." ;;

        fr:warning_body_4) echo "Veuillez garder une session SSH root active avant de continuer." ;;
        en:warning_body_4) echo "Please keep an active root SSH session open before continuing." ;;

        fr:type_yes) echo "Tapez 'yes' pour continuer" ;;
        en:type_yes) echo "Type 'yes' to continue" ;;

        fr:version_mismatch_title) echo "VERSIONS DIFFÉRENTES" ;;
        en:version_mismatch_title) echo "VERSION MISMATCH" ;;

        fr:version_mismatch_body) echo "Ce backup a été pris sur une autre version de Proxmox VE. Restaurer ces fichiers sur la version actuelle peut casser l'interface web." ;;
        en:version_mismatch_body) echo "This backup was taken on a different Proxmox VE version. Restoring these files on the current version may break the web interface." ;;

        fr:version_in_backup) echo "Dans le backup" ;;
        en:version_in_backup) echo "In the backup" ;;

        fr:version_installed) echo "Installé" ;;
        en:version_installed) echo "Installed" ;;

        fr:summary_title) echo "PANNEAU DE STATUT" ;;
        en:summary_title) echo "STATUS PANEL" ;;

        fr:summary_body_1) echo "Dans le résumé d'une VM ou d'un conteneur, Proxmox fixe la hauteur du panneau de statut et des notes à 300 pixels. Quand il y a plusieurs adresses IP ou une fenêtre étroite, le bas est coupé (le bouton « Plus », voire une adresse IP)." ;;
        en:summary_body_1) echo "In the summary of a VM or container, Proxmox fixes the height of the status and notes panels to 300 pixels. With several IP addresses or a narrow window, the bottom gets cut (the \"More\" button, sometimes an IP address)." ;;

        fr:summary_body_2) echo "Cette option en fait une hauteur minimale : les deux panneaux s'agrandissent ensemble pour tout afficher. Elle modifie une ligne de pvemanagerlib.js et fonctionne avec ou sans les thèmes." ;;
        en:summary_body_2) echo "This option turns it into a minimum height: both panels grow together to show everything. It changes one line of pvemanagerlib.js and works with or without the themes." ;;

        fr:storage_title) echo "TAILLES DES STOCKAGES" ;;
        en:storage_title) echo "STORAGE SIZES" ;;

        fr:storage_body_1) echo "Le bloc « Statut » d'un stockage est le seul endroit où Proxmox compte par 1000 (To) : un disque de 4 To formaté y apparaît par exemple à 3,94 To, alors que le reste de l'interface et Windows comptent par 1024 (3,58 Tio)." ;;
        en:storage_body_1) echo "The \"Status\" block of a storage is the only place where Proxmox counts by 1000 (TB): a formatted 4 TB disk shows there as 3.94 TB for example, while the rest of the interface and Windows count by 1024 (3.58 TiB)." ;;

        fr:storage_body_2) echo "Cette option le fait compter par 1024 comme partout ailleurs. Le pourcentage ne change pas. Elle modifie une ligne de pvemanagerlib.js et fonctionne avec ou sans les thèmes." ;;
        en:storage_body_2) echo "This option makes it count by 1024 like everywhere else. The percentage does not change. It changes one line of pvemanagerlib.js and works with or without the themes." ;;

        fr:option_enable_q) echo "L'option est désactivée. Elle va être activée." ;;
        en:option_enable_q) echo "The option is disabled. It is about to be enabled." ;;

        fr:option_disable_q) echo "L'option est activée. Elle va être désactivée." ;;
        en:option_disable_q) echo "The option is enabled. It is about to be disabled." ;;

        fr:option_enabled) echo "Option activée." ;;
        en:option_enabled) echo "Option enabled." ;;

        fr:option_disabled) echo "Option désactivée." ;;
        en:option_disabled) echo "Option disabled." ;;

        fr:option_failed) echo "La modification n'a pas pu être vérifiée. Restaurez le backup avec l'option 2." ;;
        en:option_failed) echo "The change could not be verified. Restore the backup with option 2." ;;

        fr:reload_hint) echo "Rechargez la page de l'interface web pour voir le résultat." ;;
        en:reload_hint) echo "Reload the web interface page to see the result." ;;

        fr:hook_enabled) echo "Les modifications en place seront réappliquées automatiquement après chaque mise à jour." ;;
        en:hook_enabled) echo "The changes in place will be re-applied automatically after every update." ;;

        fr:hook_disabled) echo "Réapplication automatique désactivée." ;;
        en:hook_disabled) echo "Automatic re-apply disabled." ;;

        fr:hook_already_enabled) echo "La réapplication automatique est déjà active." ;;
        en:hook_already_enabled) echo "Automatic re-apply is already active." ;;

        fr:hook_already_disabled) echo "La réapplication automatique n'est pas active." ;;
        en:hook_already_disabled) echo "Automatic re-apply is not active." ;;

        fr:hook_nothing) echo "Rien n'est en place à réappliquer. Installez d'abord les thèmes ou une option." ;;
        en:hook_nothing) echo "Nothing is in place to re-apply. Install the themes or an option first." ;;

        fr:hook_still_active) echo "La réapplication automatique est toujours active : les modifications reviendront à la prochaine mise à jour. Utilisez l'option 9 pour la désactiver." ;;
        en:hook_still_active) echo "Automatic re-apply is still active: the changes will come back on the next update. Use option 9 to disable it." ;;

        fr:hook_file) echo "Fichier de hook APT" ;;
        en:hook_file) echo "APT hook file" ;;

        fr:uninstall_title) echo "DÉSINSTALLATION" ;;
        en:uninstall_title) echo "UNINSTALL" ;;

        fr:uninstall_body_1) echo "Les 15 fichiers de thème sont supprimés, les modifications du code de Proxmox sont retirées une à une (celles des autres scripts restent en place) et la réapplication automatique est désactivée." ;;
        en:uninstall_body_1) echo "The 15 theme files are removed, the changes to the Proxmox code are taken out one by one (those of other scripts stay in place) and automatic re-apply is disabled." ;;

        fr:uninstall_body_2) echo "Un navigateur qui utilisait un thème Modern affichera l'interface claire d'origine, même si l'ordinateur est en mode sombre, jusqu'à ce qu'un autre thème soit choisi dans « Thème de couleur »." ;;
        en:uninstall_body_2) echo "A browser that used a Modern theme shows the stock light interface, even if the computer is in dark mode, until another theme is picked in \"Color Theme\"." ;;

        fr:nothing_to_uninstall) echo "Rien n'est installé. Aucune modification appliquée." ;;
        en:nothing_to_uninstall) echo "Nothing is installed. No changes applied." ;;

        fr:uninstall_unknown) echo "Une partie du code n'est pas reconnue et a été laissée telle quelle" ;;
        en:uninstall_unknown) echo "Part of the code is not recognized and was left as is" ;;

        fr:uninstall_done) echo "Désinstallation terminée." ;;
        en:uninstall_done) echo "Uninstall completed." ;;

        fr:uninstall_failed) echo "La désinstallation n'a pas pu être vérifiée. Restaurez le backup avec l'option 2." ;;
        en:uninstall_failed) echo "The uninstall could not be verified. Restore the backup with option 2." ;;

        fr:banner_subtitle) echo "Modern Theme" ;;
        en:banner_subtitle) echo "Modern Theme" ;;

        fr:repo_hint) echo "Thèmes modernes pour l'interface web Proxmox VE, 5 couleurs en clair et en sombre" ;;
        en:repo_hint) echo "Modern themes for the Proxmox VE web interface, 5 colors in light and dark" ;;

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
    [[ -f "$PX_FILE" ]] || { say_err "$(tr_msg file_not_found): $PX_FILE"; exit 1; }
    [[ -f "$PVE_FILE" ]] || { say_err "$(tr_msg file_not_found): $PVE_FILE"; exit 1; }
    [[ -d "$THEME_DIR" ]] || { say_err "$(tr_msg file_not_found): $THEME_DIR"; exit 1; }
    command -v python3 >/dev/null 2>&1 || { say_err "$(tr_msg missing_python)"; exit 1; }
    command -v sha256sum >/dev/null 2>&1 || { say_err "$(tr_msg missing_sha256sum)"; exit 1; }
}

# ------------------------------------------------------------
# Patch and theme engine
# ------------------------------------------------------------

# Every change to the Proxmox code is a whole block, matched with its exact
# indentation and unique in the shipped file, and is reverted by putting that
# same block back: uninstalling never touches the changes other scripts made
# to the same files. The same program is installed for the APT hook.
ENGINE_PY="$(cat <<'PY'
import os
import re
import sys
from pathlib import Path

ACCENTS = {"orange": "Orange", "blue": "Blue", "violet": "Violet", "green": "Green", "pink": "Pink"}
MODES = (("", "Auto"), ("-light", "Light"), ("-dark", "Dark"))

SELECTOR_STOCK = (
    "        theme_map: {\n"
    "            crisp: 'Light theme',\n"
    "            'proxmox-dark': 'Proxmox Dark',\n"
    "        },\n"
)
SELECTOR_PATCHED = SELECTOR_STOCK[:-len("        },\n")] + "".join(
    f"            'modern-{accent}{suffix}': 'Modern {label} ({mode})',\n"
    for accent, label in ACCENTS.items() for suffix, mode in MODES
) + "        },\n"

# RRDChart.checkThemeColors() already reads the background, text and grid
# colours from CSS variables; the Modern themes also set the series colours
# and fill opacity, which stock Proxmox hard codes per chart.
CHARTS_STOCK = (
    "        me.axes.forEach((axis) => {\n"
    "            axis.setLabel({ color: text });\n"
    "            axis.setTitle({ color: text });\n"
    "            axis.setStyle({ strokeStyle: primary });\n"
    "            axis.setGrid({ stroke: gridStroke });\n"
    "        });\n"
)
CHARTS_PATCHED = CHARTS_STOCK + (
    "        // Modern themes (Proxmox-Tools): series colours from the theme, if it sets them\n"
    "        let series = rootStyle.getPropertyValue('--pmt-chart-series').trim();\n"
    "        if (series) {\n"
    "            let colors = series.split(',').map((c) => c.trim());\n"
    "            let fillOpacity = parseFloat(rootStyle.getPropertyValue('--pmt-chart-fill-opacity'));\n"
    "            me.setColors(colors);\n"
    "            me.getSeries().forEach((s, i) =>\n"
    "                s.setStyle({\n"
    "                    opacity: 1,\n"
    "                    strokeOpacity: 1,\n"
    "                    strokeStyle: colors[i % colors.length],\n"
    "                    fillOpacity: isNaN(fillOpacity) ? 0.6 : fillOpacity,\n"
    "                }),\n"
    "            );\n"
    "        }\n"
)

# The south Logs panel has no header and folds only from the small arrow on
# its splitter, which the themes hide once this button exists.
LOGS_STOCK = (
    "                {\n"
    "                    itemId: 'clog',\n"
    "                    title: gettext('Cluster log'),\n"
    "                    xtype: 'pveClusterLog',\n"
    "                },\n"
    "            ],\n"
    "        });\n"
    "\n"
    "        me.callParent();\n"
)
LOGS_PATCHED = LOGS_STOCK + (
    "\n"
    "        // Modern themes (Proxmox-Tools): collapse button at the right of the tab bar\n"
    "        me.getTabBar().add([\n"
    "            { xtype: 'tbfill' },\n"
    "            {\n"
    "                xtype: 'tool',\n"
    "                type: 'collapse-bottom',\n"
    "                cls: 'pmt-logs-collapse',\n"
    "                tooltip: me.collapseToolText,\n"
    "                callback: () => me.collapse(),\n"
    "            },\n"
    "        ]);\n"
)

# PVE.guest.Summary puts the status and notes panels in a 300 px high box,
# which cuts the IP list and its More button when they need more room.
SUMMARY_STOCK = (
    "                    xtype: 'container',\n"
    "                    height: 300,\n"
    "                    layout: {\n"
    "                        type: 'hbox',\n"
    "                        align: 'stretch',\n"
    "                    },\n"
    "                    items: items,\n"
)
SUMMARY_PATCHED = (
    "                    xtype: 'container',\n"
    "                    minHeight: 300,\n"
    "                    layout: {\n"
    "                        type: 'hbox',\n"
    "                        align: 'stretchmax',\n"
    "                    },\n"
    "                    items: items,\n"
)

# PVE.storage.StatusView is the only place that asks for SI units (TB).
STORAGE_STOCK = (
    "            itemId: 'usage',\n"
    "            title: gettext('Usage'),\n"
    "            valueField: 'used',\n"
    "            maxField: 'total',\n"
    "            renderer: (val, max) => {\n"
    "                if (max === undefined) {\n"
    "                    return val;\n"
    "                }\n"
    "                return Proxmox.Utils.render_size_usage(val, max, true);\n"
    "            },\n"
)
STORAGE_PATCHED = STORAGE_STOCK.replace("render_size_usage(val, max, true)", "render_size_usage(val, max)")

PATCHES = {
    "selector": ("PX_FILE", SELECTOR_STOCK, SELECTOR_PATCHED),
    "charts": ("PX_FILE", CHARTS_STOCK, CHARTS_PATCHED),
    "logs": ("PVE_FILE", LOGS_STOCK, LOGS_PATCHED),
    "summary": ("PVE_FILE", SUMMARY_STOCK, SUMMARY_PATCHED),
    "storage": ("PVE_FILE", STORAGE_STOCK, STORAGE_PATCHED),
}

COLOR = re.compile(r"#[0-9a-fA-F]{3,8}\b|rgba?\([^)]*\)|hsla?\([^)]*\)")
HEADER = "/* Modern theme for Proxmox VE, installed by pve-modern-theme.sh (Proxmox-Tools) */\n"


def patch_state(name):
    env, stock, patched = PATCHES[name]
    path = Path(os.environ[env])
    if not path.is_file():
        return "unknown"
    text = path.read_text(encoding="utf-8")
    applied = text.count(patched)
    # an inserted block still contains the stock one
    pristine = text.count(stock) - applied * patched.count(stock)
    if applied == 1 and pristine == 0:
        return "patched"
    if applied == 0 and pristine == 1:
        return "stock"
    return "unknown"


def write_atomic(path, text):
    tmp = path.with_name(path.name + ".pmt-tmp")
    tmp.write_text(text, encoding="utf-8")
    os.chmod(tmp, path.stat().st_mode & 0o7777 if path.exists() else 0o644)
    os.replace(tmp, path)


def swap(name, before, after):
    env = PATCHES[name][0]
    path = Path(os.environ[env])
    text = path.read_text(encoding="utf-8")
    write_atomic(path, text.replace(before, after, 1))


def theme_files(parts_dir):
    parts = {p.name: p.read_text(encoding="utf-8") for p in Path(parts_dir).iterdir()}
    base = {
        "light": parts["light_head"] + parts["shared"] + parts["light_tail"],
        "dark": parts["dark_head"] + parts["shared"] + parts["dark_tail"],
    }
    maps = {}
    for line in parts["colors"].splitlines():
        accent, mode, before, after = line.split("\t")
        maps.setdefault((accent, mode), {})[before] = after
    files = {}
    for accent in ACCENTS:
        css = {mode: COLOR.sub(lambda m: maps.get((accent, mode), {}).get(m.group(0), m.group(0)), text)
               for mode, text in base.items()}
        files[f"theme-modern-{accent}-light.css"] = HEADER + css["light"]
        files[f"theme-modern-{accent}-dark.css"] = HEADER + css["dark"]
        files[f"theme-modern-{accent}.css"] = (
            HEADER
            + "@media not all and (prefers-color-scheme: dark) {\n" + css["light"] + "}\n"
            + "@media (prefers-color-scheme: dark) {\n" + css["dark"] + "}\n"
        )
    return files


def themes_state(theme_dir, parts_dir):
    files = theme_files(parts_dir)
    present = [n for n in files if (Path(theme_dir) / n).is_file()]
    if not present:
        return "absent"
    if len(present) == len(files) and all(
            (Path(theme_dir) / n).read_text(encoding="utf-8") == text for n, text in files.items()):
        return "installed"
    return "outdated"


def main(argv):
    command, args = argv[0], argv[1:]
    if command == "state":
        print(patch_state(args[0]))
    elif command in ("apply", "revert"):
        name = args[0]
        _, stock, patched = PATCHES[name]
        expected = "stock" if command == "apply" else "patched"
        if patch_state(name) != expected:
            return 1
        if command == "apply":
            swap(name, stock, patched)
        else:
            swap(name, patched, stock)
    elif command == "reapply":
        for name in args:
            if patch_state(name) == "stock":
                swap(name, PATCHES[name][1], PATCHES[name][2])
    elif command == "themes-state":
        print(themes_state(args[0], args[1]))
    elif command == "themes-write":
        for name, text in theme_files(args[1]).items():
            write_atomic(Path(args[0]) / name, text)
    elif command == "themes-remove":
        for name in theme_files(args[1]):
            (Path(args[0]) / name).unlink(missing_ok=True)
    else:
        return 2
    return 0


sys.exit(main(sys.argv[1:]))
PY
)"

engine() {
    PX_FILE="$PX_FILE" PVE_FILE="$PVE_FILE" python3 -c "$ENGINE_PY" "$@"
}

patch_state() {
    engine state "$1"
}

THEME_PARTS_DIR=""

cleanup() {
    if [[ -n "$THEME_PARTS_DIR" ]]; then
        rm -rf "$THEME_PARTS_DIR"
    fi
}
trap cleanup EXIT

# The themes ship as the orange light and dark CSS, split around the part they
# share, plus the colours to swap for each other accent.
theme_parts_dir() {
    if [[ -z "$THEME_PARTS_DIR" ]]; then
        THEME_PARTS_DIR="$(mktemp -d)"
        theme_css_light_head >"$THEME_PARTS_DIR/light_head"
        theme_css_dark_head >"$THEME_PARTS_DIR/dark_head"
        theme_css_shared >"$THEME_PARTS_DIR/shared"
        theme_css_light_tail >"$THEME_PARTS_DIR/light_tail"
        theme_css_dark_tail >"$THEME_PARTS_DIR/dark_tail"
        theme_accent_colors >"$THEME_PARTS_DIR/colors"
    fi
    echo "$THEME_PARTS_DIR"
}

themes_state() {
    engine themes-state "$THEME_DIR" "$(theme_parts_dir)"
}

# ------------------------------------------------------------
# Backups
# ------------------------------------------------------------

latest_backup_dir() {
    find /root -maxdepth 1 -type d -name 'pve-modern-theme-patch-*' | sort | tail -n1
}

list_backups_raw() {
    find /root -maxdepth 1 -type d -name 'pve-modern-theme-patch-*' | sort
}

create_backup() {
    local ts dir
    ts="$(date +%F-%H%M%S)"
    dir="${PATCH_PREFIX}-${ts}"
    mkdir -p "$dir"

    cp -a "$PX_FILE" "$PVE_FILE" "$dir/"

    {
        echo "created_at=$(date --iso-8601=seconds)"
        echo "hostname=$(hostname)"
        echo "px_file=$PX_FILE"
        echo "pve_file=$PVE_FILE"
        echo
        pveversion -v 2>/dev/null || true
    } >"$dir/INFO.txt"

    sha256sum "$dir/$(basename "$PX_FILE")" "$dir/$(basename "$PVE_FILE")" >"$dir/SHA256SUMS.txt"
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
# APT hook, so a package update does not silently drop the changes
# ------------------------------------------------------------

hook_is_enabled() {
    [[ -f "$APT_HOOK_FILE" ]]
}

applied_patches() {
    local name
    for name in selector charts logs summary storage; do
        if [[ "$(patch_state "$name")" == "patched" ]]; then
            echo "$name"
        fi
    done
}

# The hook only carries the changes in place when it is written, so an
# option the user never enabled never comes back after an update.
write_hook_file() {
    local patches
    patches="$(applied_patches | tr '\n' ' ')"

    mkdir -p "$HELPER_DIR"
    printf '%s\n' "$ENGINE_PY" >"$HELPER_DIR/engine.py"
    chmod 0644 "$HELPER_DIR/engine.py"

    cat >"$APT_HOOK_FILE" <<EOF_HOOK
// Managed by Proxmox-Tools pve-modern-theme.sh
// Re-applies the Modern theme changes when a package update restores the stock files.
DPkg::Post-Invoke {"if [ -f ${HELPER_DIR}/engine.py ]; then PX_FILE=${PX_FILE} PVE_FILE=${PVE_FILE} python3 ${HELPER_DIR}/engine.py reapply ${patches}|| true; fi"; };
EOF_HOOK
    chmod 0644 "$APT_HOOK_FILE"
}

remove_hook_files() {
    rm -f "$APT_HOOK_FILE"
    rm -rf "$HELPER_DIR"
}

# Keep the hook in step with the changes that are actually in place.
refresh_hook_file() {
    hook_is_enabled || return 0
    if [[ -n "$(applied_patches)" ]]; then
        write_hook_file
    else
        remove_hook_files
    fi
}

enable_hook() {
    if hook_is_enabled; then
        say_info "$(tr_msg hook_already_enabled)"
        return 0
    fi

    if [[ -z "$(applied_patches)" ]]; then
        say_info "$(tr_msg hook_nothing)"
        return 0
    fi

    write_hook_file
    say_ok "$(tr_msg hook_enabled)"
    say_info "$(tr_msg hook_file): ${PMX_CYAN}${APT_HOOK_FILE}${RESET}"
}

disable_hook() {
    if ! hook_is_enabled; then
        say_info "$(tr_msg hook_already_disabled)"
        return 0
    fi

    remove_hook_files
    say_ok "$(tr_msg hook_disabled)"
}

# ------------------------------------------------------------
# Actions
# ------------------------------------------------------------

patch_label() {
    case "$1" in
        selector) tr_msg status_selector ;;
        charts) tr_msg status_charts ;;
        logs) tr_msg status_logs ;;
        summary) tr_msg status_summary ;;
        storage) tr_msg status_storage ;;
    esac
}

state_label() {
    case "$1" in
        patched) echo "${PMX_GREEN}$(tr_msg state_applied)${RESET}" ;;
        stock) echo "${PMX_GREY}$(tr_msg state_stock)${RESET}" ;;
        *) echo "${PMX_RED}$(tr_msg state_unknown)${RESET}" ;;
    esac
}

show_status() {
    local themes_label hook_state

    case "$(themes_state)" in
        installed) themes_label="${PMX_GREEN}$(tr_msg state_installed)${RESET}" ;;
        outdated) themes_label="${PMX_AMBER}$(tr_msg state_outdated)${RESET}" ;;
        *) themes_label="${PMX_GREY}$(tr_msg state_absent)${RESET}" ;;
    esac

    if hook_is_enabled; then
        hook_state="${PMX_GREEN}$(tr_msg status_enabled)${RESET}"
    else
        hook_state="${PMX_GREY}$(tr_msg status_disabled)${RESET}"
    fi

    panel "$PMX_ORANGE" "$(tr_msg status_title)" \
        "$(tr_msg detected_version): pve-manager ${BOLD}$(installed_pkg_version pve-manager)${RESET} · proxmox-widget-toolkit ${BOLD}$(installed_pkg_version proxmox-widget-toolkit)${RESET}" \
        "$(tr_msg status_themes): ${BOLD}${themes_label}" \
        "$(tr_msg status_selector): ${BOLD}$(state_label "$(patch_state selector)")" \
        "$(tr_msg status_charts): ${BOLD}$(state_label "$(patch_state charts)")" \
        "$(tr_msg status_logs): ${BOLD}$(state_label "$(patch_state logs)")" \
        "$(tr_msg status_summary): ${BOLD}$(state_label "$(patch_state summary)")" \
        "$(tr_msg status_storage): ${BOLD}$(state_label "$(patch_state storage)")" \
        "$(tr_msg status_auto_reapply): ${BOLD}${hook_state}"
}

show_warning_and_confirm() {
    panel "$PMX_AMBER" "$(tr_msg warning_title)" \
        "$(tr_msg warning_body_1)" \
        "$(tr_msg warning_body_2)" \
        "$(tr_msg warning_body_3)" \
        "$(tr_msg warning_body_4)"

    if ! confirm_yes; then
        say_info "$(tr_msg cancelled)"
        return 1
    fi
    return 0
}

install_themes() {
    local name state backup_dir all_patched=1

    for name in selector charts logs; do
        state="$(patch_state "$name")"
        if [[ "$state" == "unknown" ]]; then
            say_err "$(tr_msg incompatible)"
            say_info "$(tr_msg incompatible_part): $(patch_label "$name")"
            say_info "$(tr_msg no_file_modified)"
            return 1
        fi
        if [[ "$state" != "patched" ]]; then
            all_patched=0
        fi
    done

    if [[ "$all_patched" -eq 1 && "$(themes_state)" == "installed" ]]; then
        say_ok "$(tr_msg already_installed)"
        return 0
    fi

    show_warning_and_confirm || return 0

    backup_dir="$(create_backup)"
    say_info "$(tr_msg backup_created): ${PMX_CYAN}${backup_dir}${RESET}"

    engine themes-write "$THEME_DIR" "$(theme_parts_dir)"
    for name in selector charts logs; do
        if [[ "$(patch_state "$name")" == "stock" ]]; then
            engine apply "$name"
        fi
    done

    for name in selector charts logs; do
        if [[ "$(patch_state "$name")" != "patched" ]]; then
            say_err "$(tr_msg install_failed)"
            return 1
        fi
    done
    if [[ "$(themes_state)" != "installed" ]]; then
        say_err "$(tr_msg install_failed)"
        return 1
    fi

    refresh_hook_file
    echo
    say_ok "$(tr_msg installed_ok)"
    say_info "$(tr_msg how_to_choose)"
    say_info "$(tr_msg browser_cache)"
    say_info "$(tr_msg backup_used): ${PMX_CYAN}${backup_dir}${RESET}"
}

toggle_option() {
    local name="$1" title="$2" body_1="$3" body_2="$4"
    local state question action expected done_msg backup_dir

    state="$(patch_state "$name")"
    case "$state" in
        stock) question="$(tr_msg option_enable_q)"; action="apply"; expected="patched"; done_msg="$(tr_msg option_enabled)" ;;
        patched) question="$(tr_msg option_disable_q)"; action="revert"; expected="stock"; done_msg="$(tr_msg option_disabled)" ;;
        *)
            say_err "$(tr_msg incompatible)"
            say_info "$(tr_msg no_file_modified)"
            return 1
            ;;
    esac

    panel "$PMX_AMBER" "$title" "$body_1" "$body_2" "${BOLD}${question}${RESET}"

    if ! confirm_yes; then
        say_info "$(tr_msg cancelled)"
        return 0
    fi

    backup_dir="$(create_backup)"
    say_info "$(tr_msg backup_created): ${PMX_CYAN}${backup_dir}${RESET}"

    engine "$action" "$name"

    if [[ "$(patch_state "$name")" != "$expected" ]]; then
        say_err "$(tr_msg option_failed)"
        return 1
    fi

    refresh_hook_file
    echo
    say_ok "$done_msg"
    say_info "$(tr_msg reload_hint)"
    say_info "$(tr_msg browser_cache)"
}

toggle_summary() {
    toggle_option summary "$(tr_msg summary_title)" "$(tr_msg summary_body_1)" "$(tr_msg summary_body_2)"
}

toggle_storage() {
    toggle_option storage "$(tr_msg storage_title)" "$(tr_msg storage_body_1)" "$(tr_msg storage_body_2)"
}

uninstall_all() {
    local name state backup_dir unknown=()

    if [[ "$(themes_state)" == "absent" && -z "$(applied_patches)" ]] && ! hook_is_enabled; then
        say_info "$(tr_msg nothing_to_uninstall)"
        return 0
    fi

    panel "$PMX_AMBER" "$(tr_msg uninstall_title)" \
        "$(tr_msg uninstall_body_1)" \
        "$(tr_msg uninstall_body_2)"

    if ! confirm_yes; then
        say_info "$(tr_msg cancelled)"
        return 0
    fi

    backup_dir="$(create_backup)"
    say_info "$(tr_msg backup_created): ${PMX_CYAN}${backup_dir}${RESET}"

    remove_hook_files
    engine themes-remove "$THEME_DIR" "$(theme_parts_dir)"
    for name in selector charts logs summary storage; do
        state="$(patch_state "$name")"
        if [[ "$state" == "patched" ]]; then
            engine revert "$name"
        elif [[ "$state" == "unknown" ]]; then
            unknown+=("$name")
        fi
    done

    if [[ -n "$(applied_patches)" || "$(themes_state)" != "absent" ]]; then
        say_err "$(tr_msg uninstall_failed)"
        return 1
    fi

    echo
    say_ok "$(tr_msg uninstall_done)"
    for name in "${unknown[@]}"; do
        say_warn "$(tr_msg uninstall_unknown): $(patch_label "$name")"
    done
    say_info "$(tr_msg reload_hint)"
}

confirm_backup_versions() {
    local dir="$1"
    local pkg backup_version installed_version
    local mismatch=()

    for pkg in pve-manager proxmox-widget-toolkit; do
        backup_version="$(pkg_version_from_backup "$dir" "$pkg")"
        installed_version="$(installed_pkg_version "$pkg")"
        [[ -n "$backup_version" && -n "$installed_version" ]] || continue
        [[ "$backup_version" != "$installed_version" ]] || continue
        mismatch+=("${pkg} · $(tr_msg version_in_backup) ${BOLD}${backup_version}${RESET} · $(tr_msg version_installed) ${BOLD}${installed_version}${RESET}")
    done

    [[ "${#mismatch[@]}" -gt 0 ]] || return 0

    panel "$PMX_AMBER" "$(tr_msg version_mismatch_title)" \
        "$(tr_msg version_mismatch_body)" \
        "${mismatch[@]}"

    if ! confirm_yes; then
        say_info "$(tr_msg restore_cancelled)"
        return 1
    fi
    return 0
}

restore_specific() {
    local dir="$1"
    local file
    [[ -d "$dir" ]] || { say_err "$(tr_msg file_not_found): $dir"; return 1; }
    for file in "$PX_FILE" "$PVE_FILE"; do
        [[ -f "$dir/$(basename "$file")" ]] || { say_err "$(tr_msg file_not_found): $dir/$(basename "$file")"; return 1; }
    done

    confirm_backup_versions "$dir" || return 0

    cp -a "$dir/$(basename "$PX_FILE")" "$PX_FILE"
    cp -a "$dir/$(basename "$PVE_FILE")" "$PVE_FILE"
    refresh_hook_file

    say_ok "$(tr_msg restore_done): ${PMX_CYAN}${dir}${RESET}"
    say_info "$(tr_msg restore_themes_kept)"

    if hook_is_enabled; then
        say_warn "$(tr_msg hook_still_active)"
    fi
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

    if (( 10#$choice < 1 || 10#$choice > ${#backups[@]} )); then
        say_err "$(tr_msg selection_out_of_range)"
        pause
        return
    fi

    restore_specific "${backups[$((10#$choice - 1))]}"
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
        printf " %b6)%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$(tr_msg menu_summary)"
        printf " %b7)%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$(tr_msg menu_storage)"
        printf " %b8)%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$(tr_msg menu_hook_enable)"
        printf " %b9)%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$(tr_msg menu_hook_disable)"
        printf " %b10)%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$(tr_msg menu_uninstall)"
        printf " %b11)%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$(tr_msg menu_quit)"
        echo

        read -r -p "$(tr_msg choose_option) [1-11]: " choice
        echo

        case "$choice" in
            1)
                menu_action install_themes
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
                menu_action toggle_summary
                pause
                ;;
            7)
                menu_action toggle_storage
                pause
                ;;
            8)
                menu_action enable_hook
                pause
                ;;
            9)
                menu_action disable_hook
                pause
                ;;
            10)
                menu_action uninstall_all
                pause
                ;;
            11)
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

# ------------------------------------------------------------
# Themes (CSS)
# ------------------------------------------------------------

# >>> generated by sources/pve-modern-theme/build.py, do not edit by hand
theme_css_light_head() {
    cat <<'PMT_CSS'
:root{color-scheme:light;--pwt-panel-background: #ffffff;--pwt-text-color: #1e2330;--pwt-gauge-back: #eef1f5;--pwt-gauge-warn: #f5a524;--pwt-gauge-crit: #e5484d}
.x-body{color:#1e2330}
.x-viewport>.x-body,body.x-border-layout-ct,div.x-border-layout-ct{background-color:#eceff4}
.x-panel-body-default,.x-window-body-default,.x-autocontainer-outerCt{color:#1e2330}
.x-panel-body-default,.x-window-body-default{background-color:#fff}
.x-plain-body-default,#versioninfo-body{color:#667085}
.x-btn-default-small{background-color:#e2590b;border-color:#e2590b}
.x-btn-default-small .x-btn-inner-default-small,.x-btn-default-small .x-btn-icon-el-default-small{color:#fff}
.x-btn-default-small.x-btn-over{background-color:#f06d1d;border-color:#f06d1d}
.x-btn-default-small.x-btn.x-btn-pressed{background-color:#b8470a;border-color:#b8470a}
.x-btn-default-small.x-btn.x-btn-disabled{background-color:#e2590b;border-color:#e2590b}
.x-btn-default-toolbar-small .x-btn-inner-default-toolbar-small{color:#1e2330}
.x-btn-default-toolbar-small .x-btn-icon-el-default-toolbar-small{color:#475467}
.x-btn.proxmox-inline-button{background-color:#fff;border-color:#d0d5dd}
.x-btn.proxmox-inline-button .x-btn-inner{color:#1e2330}
.x-btn.proxmox-inline-button .x-btn-icon-el{color:#475467}
.x-btn.proxmox-inline-button.x-btn-over{background-color:#f2f4f7;border-color:#d0d5dd}
.x-btn.proxmox-inline-button.x-btn-pressed{background-color:rgba(226,89,11,.1);border-color:#e2590b}
.x-btn.proxmox-inline-button.x-btn-pressed .x-btn-inner{color:#c2410c}
.x-window-header-default,.x-window-default{background-color:#fff;border-color:#d0d5dd}
.x-window-header-default .x-tool-img{color:#475467}
.x-form-text-default,.x-form-trigger-wrap-default{background-color:#fff;color:#1e2330}
.x-form-trigger-default{background-color:#fff}
.x-menu-item-active{background-color:#f2f4f7}
.x-grid-item-selected .x-grid-cell,.x-grid-item-selected .x-grid-cell-inner{color:#1e2330}
.x-grid-item-focused .x-grid-cell-inner::before{border-color:#e2590b}
.x-tree-icon,.x-tree-elbow-img{color:#475467}
.x-treelist-pve-nav .x-treelist-item-text,.x-treelist-pve-nav .x-treelist-item-icon,.x-treelist-pve-nav .x-treelist-item-expander{color:#1e2330}
.x-tab-bar-default{background-color:#fff}
.x-tab-default-top{background-color:rgba(0,0,0,0);border-color:rgba(0,0,0,0)}
.x-tab-inner-default{color:#667085}
.x-tab-default.x-tab.x-tab-active{background-color:#e2590b;border-color:#e2590b}
.x-tab-default.x-tab.x-tab-active .x-tab-inner-default{color:#fff}
.x-tab-default.x-tab.x-tab-disabled{background-color:rgba(0,0,0,0);border-color:rgba(0,0,0,0)}
a,.x-form-display-field a{color:#c2410c}
.x-splitter-collapsed,.x-layout-split-bottom{background-color:#eceff4}
:root{--pwt-chart-primary: #d0d5dd;--pwt-gauge-default: #e2590b;--pwt-chart-grid-stroke: #e4e7ec;--pmt-chart-fill-opacity: 0.22;--pmt-chart-series: #e2590b, #64748b, #cbd5e1, #c2410c}
*{scrollbar-width:thin;scrollbar-color:rgba(226,89,11,.55) rgba(0,0,0,0)}
#versioninfo-body{color:#667085}
.x-panel-default,.x-panel-default-framed{border-color:#e4e7ec}
.x-panel-header-default{background-color:#fff;border-color:#e4e7ec}
.x-panel-header-title-default>.x-title-text-default{color:#1e2330}
.x-panel-body-default{border-color:#e4e7ec}
.x-border-layout-ct>.x-panel-default,.x-border-layout-ct>.x-tab-panel,.x-border-layout-ct>.x-container-default,.x-border-layout-ct>.x-container>.x-panel-default{border-radius:10px;overflow:hidden;box-shadow:0 1px 2px rgba(16,24,40,.06),0 4px 16px rgba(16,24,40,.06)}
.pmx-rrd-chart,.x-panel-default.x-box-item[id^=proxmoxRRDChart],.x-panel-default[id^=pveNodeStatus],.x-panel-default[id^=pveGuestStatus]{border-radius:10px;overflow:hidden;border:1px solid #e4e7ec}
.x-toolbar-default{background-color:#fff;border-color:#e4e7ec}
.x-panel-header-text-default{font-weight:600;color:#1e2330}
.x-btn{border-radius:7px}
.x-btn-default-small{box-shadow:0 1px 0 hsla(0,0%,100%,.08) inset,0 2px 6px rgba(226,89,11,.25)}
.x-btn-default-toolbar-small:not(.proxmox-inline-button){background-color:rgba(0,0,0,0);border-color:#d0d5dd}
.x-btn-default-toolbar-small:not(.proxmox-inline-button).x-btn-over{background-color:#f2f4f7;border-color:#d0d5dd}
.proxmox-inline-button.x-btn-pressed{background-color:rgba(226,89,11,.1);border-color:#e2590b}
.proxmox-inline-button.x-btn-pressed .x-btn-inner{color:#9a3412}
.x-btn-inner-default-small,.x-btn-inner-default-toolbar-small{font-weight:500}
.x-form-trigger-wrap-default{border-radius:7px;border-color:#d0d5dd;overflow:hidden}
.x-form-trigger-wrap-focus,.x-form-trigger-wrap-default.x-form-trigger-wrap-focus{border-color:#e2590b;box-shadow:inset 0 0 0 1px #e2590b}
.x-treelist-pve-nav .x-treelist-item-selected>.x-treelist-row::before,.x-tree-panel .x-grid-item-selected .x-grid-cell:first-child::before{content:"";position:absolute;top:4px;bottom:4px;left:0;width:3px;border-radius:3px;background-color:#e2590b}
.x-tree-panel .x-grid-item-selected,.x-tree-panel .x-grid-item-focused{background-color:rgba(0,0,0,0)}
.x-tree-panel .x-grid-item-over>table,.x-tree-panel .x-grid-item-over{background-color:rgba(0,0,0,0)}
.x-tree-panel .x-grid-item .x-grid-cell:first-child{border-top-left-radius:7px;border-bottom-left-radius:7px}
.x-tree-panel .x-grid-item .x-grid-cell:last-child{border-top-right-radius:7px;border-bottom-right-radius:7px}
.x-tree-panel .x-grid-item-over .x-grid-cell{background-color:rgba(226,89,11,.06)}
.x-tree-panel .x-grid-item-selected .x-grid-cell{background-color:rgba(226,89,11,.1)}
.x-tree-panel .x-grid-item-selected .x-grid-cell:first-child{position:relative}
.x-tree-panel .x-grid-item-selected .x-tree-node-text{color:#9a3412;font-weight:600}
.x-treelist-pve-nav,.x-treelist-pve-nav .x-treelist-item{background-color:#fff}
.x-treelist-pve-nav .x-treelist-row{margin-left:8px;margin-right:8px;border-radius:7px}
.x-treelist-pve-nav .x-treelist-item-selected>.x-treelist-row{position:relative;background-color:rgba(226,89,11,.1)}
.x-treelist-pve-nav .x-treelist-item-selected>.x-treelist-row .x-treelist-item-text,.x-treelist-pve-nav .x-treelist-item-selected>.x-treelist-row .x-treelist-item-icon{color:#9a3412;font-weight:600}
.x-grid-header-ct,.x-column-header{background-color:#fff;border-color:#e4e7ec}
.x-column-header-text-inner{color:#667085;font-weight:600}
.x-grid-item{background-color:#fff}
.x-grid-item-alt{background-color:#fff}
.x-grid-body .x-grid-item.x-grid-item-over,.x-keyboard-mode .x-grid-body .x-grid-item.x-grid-item-focused.x-grid-item-over{background-color:rgba(226,89,11,.06)}
.x-grid-body .x-grid-item.x-grid-item-selected,.x-keyboard-mode .x-grid-body .x-grid-item.x-grid-item-focused.x-grid-item-selected{background-color:rgba(226,89,11,.1)}
.x-keyboard-mode .x-grid-body .x-grid-cell.x-grid-item-focused{background-color:rgba(0,0,0,0)}
.x-keyboard-mode .x-tree-panel .x-grid-body .x-grid-item-selected .x-grid-cell.x-grid-item-focused{background-color:rgba(226,89,11,.1)}
.x-keyboard-mode .x-grid-body .x-grid-item.x-grid-item-focused{background-color:rgba(0,0,0,0);color:#1e2330}
.x-tree-panel .x-grid-body .x-grid-item.x-grid-item-over,.x-tree-panel .x-grid-body .x-grid-item.x-grid-item-selected{background-color:rgba(0,0,0,0)}
.x-grid-with-row-lines .x-grid-item{border-color:#e4e7ec}
.x-tab-bar-default{background-color:#fff}
.x-tab-default-top{border-radius:999px;padding:3px 10px}
.x-tab-default-top .x-tab-inner-default{line-height:16px}
.x-tab-default-top:not(.x-tab-active){background-color:rgba(0,0,0,0);border-color:rgba(0,0,0,0)}
.x-tab-default-top.x-tab-over:not(.x-tab-active){background-color:rgba(226,89,11,.06)}
.x-progress-default{border-radius:999px;border:none;background-color:#eef1f5;overflow:hidden}
.x-progress-default .x-progress-bar-default{border-radius:999px;background:linear-gradient(90deg, #b8470a, #f06d1d)}
.x-window-default,.x-menu-default,.x-boundlist{border-radius:10px;box-shadow:0 20px 50px rgba(16,24,40,.18);overflow:hidden}
.x-window-header-default{background-color:#fff}
.x-splitter{background-color:rgba(0,0,0,0)}
.x-window-header-title-default>.x-title-text-default{color:#1e2330;font-weight:600}
.x-keyboard-mode .x-grid-item-focused .x-grid-cell-inner::before,.x-keyboard-mode .x-column-header.x-column-header-focus .x-column-header-inner::after,.x-keyboard-mode .x-btn-default-small.x-arrow-focus .x-btn-arrow-el,.x-keyboard-mode .x-btn-default-toolbar-small.x-arrow-focus .x-btn-arrow-el,.x-keyboard-mode .x-nbr .x-segmented-button-item.x-btn-focus::after{border-color:rgba(0,0,0,0)}
.x-keyboard-mode .x-grid-item-focused:not(.x-grid-item-selected) .x-grid-cell{box-shadow:inset 0 0 0 1px rgba(226,89,11,.45)}
.x-keyboard-mode .x-btn-focus.x-btn-default-small:not(.proxmox-inline-button){background-color:#e2590b;border-color:#e2590b;box-shadow:0 1px 0 hsla(0,0%,100%,.08) inset,0 2px 6px rgba(226,89,11,.25)}
.x-keyboard-mode .x-btn-focus.x-btn-default-small:not(.proxmox-inline-button).x-btn-over{background-color:#f06d1d;border-color:#f06d1d}
.x-keyboard-mode .x-btn-focus.x-btn-default-small:not(.proxmox-inline-button).x-btn-pressed,.x-keyboard-mode .x-btn-focus.x-btn-default-small:not(.proxmox-inline-button).x-btn-menu-active{background-color:#b8470a;border-color:#b8470a}
.x-keyboard-mode .x-btn-focus.x-btn-default-toolbar-small,.x-keyboard-mode .x-btn-focus.x-btn-default-toolbar-small.x-btn-over,.x-keyboard-mode .x-btn-focus.x-btn-default-toolbar-small.x-btn-pressed,.x-keyboard-mode .x-btn-focus.x-btn-default-toolbar-small.x-btn-menu-active{box-shadow:none}
.x-keyboard-mode .x-btn-focus.x-btn-default-toolbar-small:not(.proxmox-inline-button){background-color:rgba(0,0,0,0);border-color:#d0d5dd}
.x-keyboard-mode .x-btn-focus.x-btn-default-toolbar-small.x-btn-over:not(.proxmox-inline-button){background-color:#f2f4f7}
.x-keyboard-mode .x-btn-focus.proxmox-inline-button{background-image:none;background-color:#fff;border-color:#d0d5dd;box-shadow:none}
.x-keyboard-mode .x-btn-focus.proxmox-inline-button.x-btn-over{background-color:#f2f4f7}
.x-keyboard-mode .x-btn-focus.proxmox-inline-button.x-btn-pressed{background-color:rgba(226,89,11,.1);border-color:#e2590b}
.x-keyboard-mode .x-tab-focus.x-tab-default{background-color:rgba(0,0,0,0);border-color:rgba(0,0,0,0)}
.x-keyboard-mode .x-tab-focus.x-tab-default,.x-keyboard-mode .x-tab-focus.x-tab-default.x-tab-over,.x-keyboard-mode .x-tab-focus.x-tab-default.x-tab-active{box-shadow:none}
.x-keyboard-mode .x-tab-focus.x-tab-default.x-tab-over{background-color:rgba(226,89,11,.06);border-color:rgba(0,0,0,0)}
.x-keyboard-mode .x-tab-focus.x-tab-default.x-tab-active{background-color:#e2590b;border-color:#e2590b}
.x-keyboard-mode .x-tool-focus,.x-keyboard-mode .x-panel-header-default .x-tool-focus,.x-keyboard-mode .x-panel-header-default-framed .x-tool-focus,.x-keyboard-mode .x-window-header-default .x-tool-focus,.x-keyboard-mode .x-accordion-hd .x-tool-focus{outline:none}
.x-keyboard-mode .x-title-focus,.x-keyboard-mode .x-fieldset-header-tool-default.x-focus,.x-keyboard-mode .x-field-form-focus{outline-color:rgba(226,89,11,.5)}
.x-keyboard-mode .x-view-item-focused{outline-color:rgba(226,89,11,.5) !important}
.x-segmented-button .x-segmented-button-item.proxmox-inline-button{background-image:none;background-color:#fff;border-color:#d0d5dd;box-shadow:none}
.x-segmented-button .x-segmented-button-item.proxmox-inline-button .x-btn-inner{color:#667085;font-weight:600}
.x-segmented-button .x-segmented-button-item.proxmox-inline-button.x-btn-over{background-color:#f2f4f7}
.x-segmented-button .x-segmented-button-item.proxmox-inline-button.x-btn-pressed{background-color:#e2590b;background-image:linear-gradient(135deg, #f06d1d, #b8470a);border-color:#b8470a}
.x-segmented-button .x-segmented-button-item.proxmox-inline-button.x-btn-pressed .x-btn-inner{color:#fff}
.x-keyboard-mode .x-segmented-button .x-segmented-button-item.proxmox-inline-button{background-image:none;background-color:#fff;border-color:#d0d5dd;box-shadow:none}
.x-keyboard-mode .x-segmented-button .x-segmented-button-item.proxmox-inline-button .x-btn-inner{color:#667085;font-weight:600}
.x-keyboard-mode .x-segmented-button .x-segmented-button-item.proxmox-inline-button.x-btn-over{background-color:#f2f4f7}
.x-keyboard-mode .x-segmented-button .x-segmented-button-item.proxmox-inline-button.x-btn-pressed{background-color:#e2590b;background-image:linear-gradient(135deg, #f06d1d, #b8470a);border-color:#b8470a}
.x-keyboard-mode .x-segmented-button .x-segmented-button-item.proxmox-inline-button.x-btn-pressed .x-btn-inner{color:#fff}
.x-tip-default{background-color:#fff;border-color:#d0d5dd;border-radius:7px;box-shadow:0 1px 2px rgba(16,24,40,.06),0 4px 16px rgba(16,24,40,.06)}
.x-tip-default .x-tip-body-default{color:#1e2330}
.x-menu-item-default.x-menu-item-focus,.x-menu-item-default.x-menu-item-active{background-color:rgba(226,89,11,.1)}
.x-menu-item-default.x-menu-item-focus .x-menu-item-text,.x-menu-item-default.x-menu-item-focus .x-menu-item-icon-default,.x-menu-item-default.x-menu-item-active .x-menu-item-text,.x-menu-item-default.x-menu-item-active .x-menu-item-icon-default{color:#c2410c}
.x-legend,.x-legend-container{background-color:rgba(0,0,0,0)}
.x-legend-horizontal .x-legend-item{background-color:#fff;border-color:#d0d5dd}
.x-legend-horizontal .x-legend-item:first-child{border-left-color:#d0d5dd;border-top-left-radius:999px;border-bottom-left-radius:999px}
.x-legend-horizontal .x-legend-item:last-child{border-top-right-radius:999px;border-bottom-right-radius:999px}
.x-boundlist-item-over,.x-treelist-row-over,.x-treelist-pve-nav .x-treelist-row-over{background-color:rgba(226,89,11,.06);border-color:rgba(0,0,0,0)}
.x-boundlist-selected,.x-boundlist-item-over.x-boundlist-selected{background-color:rgba(226,89,11,.1);border-color:rgba(0,0,0,0);color:#c2410c}
PMT_CSS
}

theme_css_dark_head() {
    cat <<'PMT_CSS'
:root{--pwt-panel-background: #161a22;--pwt-text-color: #e0e4eb;--pwt-gauge-default: #f0690f;--pwt-gauge-back: #1f232e;--pwt-gauge-warn: #ffcc66;--pwt-gauge-crit: #e18484;--pwt-chart-primary: #f0690f;--pwt-chart-grid-stroke: #2a2f3c}
.x-legend-container{background-color:#181c25}
.x-legend-horizontal .x-legend-item{background-color:#1f232e;color:#e0e4eb;border-top:solid 1px #0d1016;border-right:solid 1px #0d1016;border-bottom:solid 1px #0d1016}
.x-legend-horizontal .x-legend-item:first-child{border-left:solid 1px #0d1016}
.x-tool .x-mask{backdrop-filter:none;background-color:#1f232e;opacity:.6}
.x-grid-icon-custom.running,.x-tree-icon-custom.running,.x-tree-icon-custom,.fa-database::before,.fa-tags::before,.fa-file-o::before,.fa-building::before,.x-action-col-icon::before,.fa-shield::before,.fa-file-text-o::before,.fa-clock-o::before,.x-tab-icon-el-default,.pve-icon-verify-lettering::after,.x-tree-icon-custom.lock-migrate::after,.x-grid-icon-custom.lock-migrate::after,.x-tree-icon-leaf:not(.x-tree-icon-custom)::before,.x-tree-icon-parent:not(.x-tree-icon-custom)::before,.x-tree-icon-parent-expanded:not(.x-tree-icon-custom)::before,.x-grid-filters-filtered-column .x-column-header-text::after{color:#bec4d0}
.x-tree-icon-parent:not(.x-tree-icon-custom)::before,.x-tree-icon-parent-expanded:not(.x-tree-icon-custom)::before{filter:invert(90%)}
.fa-ceph::before,.fa-sdn::before,.fa-network-wired::before,.pve-itype-treelist-item-icon-cdrom,.fa-chevron-right::before,.x-grid-row-console,.x-box-scroller-toolbar-default.x-box-scroller,.x-tree-elbow-img,.pve-itype-icon-qemu,.x-tree-node-computer,.x-grid-tree-node-expanded .x-tree-node-computer,.pbs-icon-tape,.pbs-icon-tape-drive,.x-tree-icon-leaf:not(.x-tree-icon-custom),.x-tree-icon-parent:not(.x-tree-icon-custom),.x-tree-icon-parent-expanded:not(.x-tree-icon-custom){filter:invert(78.0392156863%)}
.pve-itype-icon-cpu,.pve-itype-icon-cdrom,.pve-itype-icon-memory,.pve-itype-icon-pci,.pve-itype-icon-serial,.pve-itype-icon-die,.pmx-itype-icon-processor,.pmx-itype-icon-memory,.pve-itype-icon-storage,.x-tree-node-harddisk,.x-grid-tree-node-expanded .x-tree-node-harddisk{filter:invert(78.0392156863%)}
.pve-itype-icon-cpu .x-grid-cell-inner,.pve-itype-icon-cdrom .x-grid-cell-inner,.pve-itype-icon-memory .x-grid-cell-inner,.pve-itype-icon-pci .x-grid-cell-inner,.pve-itype-icon-serial .x-grid-cell-inner,.pve-itype-icon-die .x-grid-cell-inner,.pmx-itype-icon-processor .x-grid-cell-inner,.pmx-itype-icon-memory .x-grid-cell-inner,.pve-itype-icon-storage .x-grid-cell-inner,.x-tree-node-harddisk .x-grid-cell-inner,.x-grid-tree-node-expanded .x-tree-node-harddisk .x-grid-cell-inner{color:#000}
.x-keyboard-mode .pve-itype-icon-cpu.x-grid-item-focused,.x-keyboard-mode .pve-itype-icon-cdrom.x-grid-item-focused,.x-keyboard-mode .pve-itype-icon-memory.x-grid-item-focused,.x-keyboard-mode .pve-itype-icon-pci.x-grid-item-focused,.x-keyboard-mode .pve-itype-icon-serial.x-grid-item-focused,.x-keyboard-mode .pve-itype-icon-die.x-grid-item-focused,.x-keyboard-mode .pmx-itype-icon-processor.x-grid-item-focused,.x-keyboard-mode .pmx-itype-icon-memory.x-grid-item-focused,.x-keyboard-mode .pve-itype-icon-storage.x-grid-item-focused,.x-keyboard-mode .x-tree-node-harddisk.x-grid-item-focused,.x-keyboard-mode .x-grid-tree-node-expanded .x-tree-node-harddisk.x-grid-item-focused{background-color:rgb(195.9,191.9,181.5)}
.x-keyboard-mode .pve-itype-icon-cpu.x-grid-item-focused .x-grid-cell-inner::before,.x-keyboard-mode .pve-itype-icon-cdrom.x-grid-item-focused .x-grid-cell-inner::before,.x-keyboard-mode .pve-itype-icon-memory.x-grid-item-focused .x-grid-cell-inner::before,.x-keyboard-mode .pve-itype-icon-pci.x-grid-item-focused .x-grid-cell-inner::before,.x-keyboard-mode .pve-itype-icon-serial.x-grid-item-focused .x-grid-cell-inner::before,.x-keyboard-mode .pve-itype-icon-die.x-grid-item-focused .x-grid-cell-inner::before,.x-keyboard-mode .pmx-itype-icon-processor.x-grid-item-focused .x-grid-cell-inner::before,.x-keyboard-mode .pmx-itype-icon-memory.x-grid-item-focused .x-grid-cell-inner::before,.x-keyboard-mode .pve-itype-icon-storage.x-grid-item-focused .x-grid-cell-inner::before,.x-keyboard-mode .x-tree-node-harddisk.x-grid-item-focused .x-grid-cell-inner::before,.x-keyboard-mode .x-grid-tree-node-expanded .x-tree-node-harddisk.x-grid-item-focused .x-grid-cell-inner::before{border-color:rgb(37.5,145.5,217.5)}
.fa.black,.fa.black::after,.fa.black::before,.x-action-col-icon.fa-chevron-right::before{filter:none}
.x-tree-arrows .x-tree-expander{filter:brightness(200%)}
.x-tree-arrows .x-tree-expander-over .x-tree-expander{filter:brightness(0)}
.x-form-checkbox-default,.x-form-radio-default,.x-column-header-checkbox .x-column-header-checkbox::after,.x-grid-checkcolumn::after,.x-menu-item-checked .x-menu-item-icon-default.x-menu-item-checkbox,.x-menu-item-unchecked .x-menu-item-icon-default.x-menu-item-checkbox{filter:invert(78.0392156863%) hue-rotate(180deg) brightness(125%)}
.x-tree-icon-custom,.x-grid-icon-custom{color:#bec4d0}
.x-tree-icon-custom::after,.x-grid-icon-custom::after{color:#bec4d0;text-shadow:-1px 0 1px #161a22}
.x-tree-icon-custom.stopped,.x-tree-icon-custom.offline,.x-tree-icon-custom.unknown::after,.x-grid-icon-custom.stopped,.x-grid-icon-custom.offline,.x-grid-icon-custom.unknown::after{color:#768093}
.x-tree-icon-custom.locked::after,.x-grid-icon-custom.locked::after{color:#bec4d0}
.x-tree-icon-custom.lxc::after,.x-tree-icon-custom.qemu::after,.x-grid-icon-custom.lxc::after,.x-grid-icon-custom.qemu::after{background-color:#161a22;color:#bec4d0}
.pmx-tree-icon-custom::after{text-shadow:-1px 0 1px #161a22}
.pmx-tree-icon-custom.maintenance::before{color:#768093}
.pmx-tree-icon-custom.maintenance::after{color:#bec4d0}
.x-treelist-item-icon.lxc::after,.x-treelist-item-icon.qemu::after{background-color:#161a22;color:#bec4d0}
.x-grid-item .x-grid-icon-custom.lxc::after,.x-grid-item .x-grid-icon-custom.qemu::after{background-color:#161a22}
.x-grid-item-alt .x-grid-icon-custom.lxc::after,.x-grid-item-alt .x-grid-icon-custom.qemu::after{background-color:#0d1016}
.x-treelist-item-selected .lxc::after,.x-treelist-item-selected .qemu::after{background-color:#f0690f;text-shadow:-1px 0 1px #f0690f}
.x-grid-item-over .lxc::after,.x-grid-item-over .qemu::after,.x-treelist-item-over .lxc::after,.x-treelist-item-over .qemu::after,.x-grid-item-selected .lxc::after,.x-grid-item-selected .qemu::after,.x-keyboard-mode .x-grid-item-focused .lxc::after,.x-keyboard-mode .x-grid-item-focused .qemu::after{background-color:#2a2f3c !important;text-shadow:-1px 0 1px #2a2f3c}
.x-action-col-icon:hover::before,.x-action-col-icon:hover::after{text-shadow:-1px 0 1px #161a22}
.fa.black{color:#bec4d0}
.usage-wrapper{border:1px solid #bec4d0}
.usage-negative{background-color:rgba(0,0,0,0)}
.usage{background-color:#bec4d0}
.x-btn-default-small{background-color:#f0690f;border-color:#f0690f}
.x-btn-default-small.x-btn-over,.x-keyboard-mode .x-btn-default-small.x-btn-focus{background-color:#fa802e;border-color:#fa802e}
.x-btn-default-small.x-btn.x-btn-disabled{background-color:#f0690f}
.x-btn-default-small.x-btn.x-btn-pressed{background-color:#c65310;border-color:#f0690f}
.x-btn-default-toolbar-small{background-color:#242833;border-color:#333947}
.x-btn-default-toolbar-small .x-btn-inner-default-toolbar-small{color:#e0e4eb}
.x-btn-default-toolbar-small .x-btn-icon-el-default-toolbar-small{color:#e0e4eb}
.x-btn-default-toolbar-small .x-btn-wrap-default-toolbar-small.x-btn-arrow-right::after,.x-btn-default-toolbar-small .x-btn-wrap-default-toolbar-small.x-btn-split-right::after{filter:brightness(150%)}
.x-btn-default-toolbar-small.x-btn-over,.x-keyboard-mode .x-btn-default-toolbar-small.x-btn-focus{background-color:#333947;border-color:#333947}
.x-btn-default-toolbar-small.x-btn.x-btn-disabled{background-color:#242833}
.x-btn-default-toolbar-small.x-btn.x-btn-menu-active,.x-btn-default-toolbar-small.x-btn.x-btn-pressed{background-color:#c65310;border-color:#f0690f}
.x-form-trigger-default{background-color:#1f232e}
.x-boundlist{background-color:#1f232e;border-color:#1f232e}
.x-boundlist-item{background-color:#1f232e;border-color:#1f232e;color:#e0e4eb}
.x-boundlist-selected{background-color:rgb(33.6,37.6,48)}
.x-boundlist-item-over{background-color:#2a2f3c}
.x-form-display-field-default{color:#e0e4eb}
.x-form-text-default{background-color:#1f232e;color:#e0e4eb}
.x-form-trigger-wrap-default{border-color:#1f232e}
.x-form-trigger-wrap-default.x-form-trigger-wrap-focus{border-color:rgb(232.8,101.85,14.55)}
.x-form-item-label-default{color:#e0e4eb}
.x-form-spinner-default{background-color:#1f232e}
.x-form-cb-label-default{color:#bec4d0}
.x-fieldset-default{border-color:#242833}
.x-column-header{border-color:#242833}
.x-grid-item,.x-column-header-default,.x-grid-cell-row-numberer{color:#e0e4eb;background-color:#161a22}
.x-column-header-trigger{border-color:#333947}
.x-grid-cell-special{border-color:#242833}
.x-grid-group-hd{background-color:#161a22;border-color:#242833}
.x-grid-group-title{color:#e0e4eb}
.x-grid-header-ct{border:solid 1px #1f232e;background-color:#1f232e}
.x-grid-item-alt{background-color:#0d1016}
.x-grid-with-row-lines .x-grid-item{border-color:#242833;border-right:0}
.x-grid-with-row-lines .x-grid-item:last-child{border-color:#242833}
.x-grid-with-row-lines .x-grid-item:first-child{border-color:#242833}
.x-grid-with-row-lines .x-grid-item.x-grid-item-over,.x-grid-with-row-lines .x-grid-item.x-grid-item-selected{background-color:#2a2f3c;border-color:#242833}
.x-grid-with-row-lines .x-grid-item-selected+.x-grid-item,.x-grid-with-row-lines .x-grid-item-over+.x-grid-item{border-color:#242833}
.x-grid-item-over,.x-grid-item-selected{background-color:#2a2f3c}
.x-column-header-over,.x-column-header-open,.x-column-header-last .x-column-header-over .x-column-header-trigger{background-color:#2a2f3c}
.x-column-header-sort-ASC,.x-column-header-sort-DESC{background-color:rgb(87.4,49.7,28.3)}
.x-grid-row-summary .x-grid-cell,.x-grid-row-summary .x-grid-rowwrap,.x-grid-row-summary .x-grid-cell-rowbody{background-color:#161a22 !important;border-color:#242833}
.x-grid-with-col-lines .x-grid-cell,.x-grid-with-col-lines .x-grid-item-over .x-grid-cell,.x-grid-with-col-lines .x-grid-item-selected .x-grid-cell{border-color:#242833}
.x-dd-drag-proxy{background-color:#0d1016;border-color:#242833;color:#e0e4eb}
.x-keyboard-mode .x-grid-item-focused{background-color:#2a2f3c;color:#fff}
.x-keyboard-mode .x-grid-item-focused .x-grid-cell-inner::before{border-color:#f0690f}
.x-keyboard-mode .x-column-header.x-column-header-focus{color:#e0e4eb}
.x-keyboard-mode .x-column-header.x-column-header-focus .x-column-header-inner::after{border-color:#f0690f}
.x-keyboard-mode .proxmox-invalid-row .x-grid-item-focused{background-color:#521414}
.x-grid-empty{background-color:#161a22;color:#e0e4eb}
.x-menu-default{border-color:#1f232e}
.x-menu-body-default{background-color:#1f232e}
.x-menu-header{background-color:#f0690f}
.x-menu-item-default.x-menu-item-separator{background-color:#1f232e;border-color:#333947}
.x-menu-item-default.x-menu-item-focus,.x-menu-item-default.x-menu-item-active{background-color:#2a2f3c;color:#fff}
.x-menu-item-text-default{color:#e0e4eb}
.x-menu-item-icon-default{color:#bec4d0}
.x-menu-icon-separator-default{background-color:#1f232e;border-color:#333947}
.x-panel-header-default{background-color:#181c25;border:none}
.x-panel-header-default .x-tool-tool-el{background-color:rgba(0,0,0,0)}
.x-tool-img{filter:brightness(175%)}
.x-tool-img.x-tool-expand,.x-tool-img.x-tool-collapse,.x-tool-img.x-tool-refresh{filter:brightness(125%)}
.x-tool-img.x-tool-print{filter:invert(100%) hue-rotate(180deg) brightness(125%)}
.x-tool-over .x-tool-img{filter:brightness(200%)}
.x-tool-over .x-tool-img.x-tool-expand,.x-tool-over .x-tool-img.x-tool-collapse,.x-tool-over .x-tool-img.x-tool-refresh{filter:brightness(150%)}
.x-tool-over .x-tool-img.x-tool-print{filter:invert(100%) hue-rotate(180deg) brightness(150%)}
.x-panel-header-title-default{color:#ffa35c}
.x-panel-body-default{background-color:#161a22;border-color:#242833;color:#e0e4eb}
div[id^=pveResourceTree-][id$=-body]{border-color:#161a22}
.x-progress-default{background-color:#1f232e}
.x-progress-default .x-progress-bar-default{background-color:#f0690f}
.x-progress-default .x-progress-text{color:#e0e4eb}
.x-progress.warning .x-progress-bar{background-color:var(--pwt-gauge-warn)}
.x-progress.critical .x-progress-bar{background-color:var(--pwt-gauge-crit)}
.x-splitter{background-color:#0d1016}
.x-splitter-horizontal{background-color:#0d1016}
.x-keyboard-mode .x-splitter-focus::after{border-color:#f0690f}
.x-layout-split-bottom{opacity:.7}
.x-tab-bar-default{background-color:#161a22}
.x-tab-default.x-tab-over{background-color:#c65310;border-color:#c65310}
.x-tab-default.x-tab.x-tab-active{background-color:#fa802e;border-color:#fa802e}
.x-tab-default.x-tab.x-tab-disabled{background-color:#161a22;border-color:rgba(0,0,0,0);color:#e0e4eb}
.x-keyboard-mode .x-tab-default.x-tab-focus,.x-keyboard-mode .x-tab-default.x-tab-focus.x-tab-over,.x-keyboard-mode .x-tab-default.x-tab-focus.x-tab-active{background-color:#f0690f;border-color:#f0690f}
.x-tab-default-top{background-color:#161a22;border-color:#161a22}
.x-tab-inner-default{color:#e0e4eb}
.x-tip-default{background-color:#0d1016;border-color:#242833}
.x-tip-body-default{color:#e0e4eb}
.x-tip-form-invalid{background-color:#1f232e;border-color:#242833}
.x-tip-body-form-invalid{color:#e0e4eb}
.x-toolbar{background-color:#161a22}
.x-toolbar-default{background-color:#161a22;border-color:#242833}
.x-toolbar-default.x-docked-top{border-width:1px;border-color:#242833}
.x-toolbar-default .x-toolbar-separator{border-color:#333947}
.x-toolbar-text-default{color:#e0e4eb}
.x-treelist-item{background-color:#161a22}
.x-treelist-item-text,.x-treelist-item-icon,.x-treelist-row-over .x-treelist-item-icon,.x-treelist-row-over .x-treelist-item-text{color:#e0e4eb}
.x-treelist-item-selected>.x-treelist-row{background-color:#f0690f}
.x-treelist-row-over{background-color:#2a2f3c}
.x-treelist-pve-nav{background-color:#161a22;border-color:#333947}
.x-window-default{background-color:#0d1016;border-color:rgba(0,0,0,0)}
.x-window-header-default{background-color:#161a22;border-color:rgba(0,0,0,0)}
.x-window-header-default .x-mask{background-color:rgba(22,26,34,.7)}
.x-window-header-title-default{color:#ffa35c}
.x-window-body-default{background-color:#161a22;border-color:#242833;color:#e0e4eb}
.x-window-ghost{background-color:#161a22}
.x-window-header-default .x-tool-img{background-color:rgba(0,0,0,0)}
.x-message-box .x-window-body{background-color:#1f232e}
:root{color-scheme:dark}
.x-body{color:#e0e4eb;background-color:#0d1016}
.x-viewport>.x-body{background-color:#0d1016}
body.x-border-layout-ct,div.x-border-layout-ct{background-color:#0d1016}
.x-mask{background-color:rgba(22,26,34,.5)}
.x-css-shadow{box-shadow:#000 0 -1px 15px 5px !important}
img[id^=proxmoxlogo-][id$=-img]{filter:invert(1) hue-rotate(180deg)}
img[id^=proxmoxLogoSvg-][id$=-img]{filter:invert(1) hue-rotate(180deg)}
div[id^=versioninfo-]+div[id^=panel-]>div[id^=panel-][id$=-bodyWrap]>div,div.eol-notice+div[id^=panel-]>div[id^=panel-][id$=-bodyWrap]>div{background-color:rgba(0,0,0,0);border-color:rgba(0,0,0,0)}
.x-fieldset-header-default>.x-fieldset-header-text{color:#e0e4eb}
.proxmox-invalid-row{background-color:#521414}
.proxmox-warning-row{background-color:#640}
.proxmox-disabled-row td{color:#8790a1}
.pmx-hint{background-color:#640}
.pmx-hint a{color:#ffc599}
.pmx-hint a:active{color:#ffa35c}
.pmx-unclickable{pointer-events:none}
.pmx-journal-prio-0,.pmx-journal-prio-1,.pmx-journal-prio-2,.pmx-journal-prio-3{color:#ff7a7a}
.pmx-journal-prio-4{color:#ffb454}
.pmx-journal-prio-7,.pmx-journal-reboot{color:#aaa}
.proxmox-inline-button{background-color:#242833;border-color:#333947;color:#e0e4eb}
.proxmox-inline-button.x-btn-over,.proxmox-inline-button.x-btn.x-btn-pressed.x-btn-default-toolbar-small,.x-keyboard-mode .proxmox-inline-button.x-btn-default-toolbar-small.x-btn-focus{background-color:#333947;border-color:#333947}
.proxmox-inline-button .x-btn-inner,.proxmox-inline-button .x-btn-icon-el{color:#e0e4eb}
.x-grid-row-loading,.x-treelist-item-loading .x-treelist-item-icon,.x-treelist-nav .x-treelist-item-loading .x-treelist-item-icon,.x-mask-msg-text,.x-grid-tree-loading .x-tree-icon{filter:invert(78.0392156863%);color:#000}
.x-keyboard-mode .x-grid-item-focused.x-grid-row-loading{background-color:rgb(195.9,191.9,181.5)}
.x-keyboard-mode .x-grid-item-focused.x-grid-row-loading .x-grid-cell-inner::before{border-color:rgb(37.5,145.5,217.5) !important}
.x-mask-msg{background-color:#1f232e;border:solid 1px #242833}
.pmx-md code{background-color:#0d1016}
.pmx-md pre code{border-color:#242833}
.pmx-md tbody tr td{border-color:#333947}
.pmx-md tbody tr:nth-of-type(2n){background-color:#0d1016}
.pmx-md tbody tr:hover td{background-color:#2a2f3c}
.pmx-md a{color:#ffa35c}
.pmx-md a:active{color:#ffc599}
.proxmox-apt-repos .x-grid-group-hd{background-color:#0d1016;border-color:#242833}
.proxmox-apt-repos .x-grid-group-title{color:#e0e4eb}
:root{--pmg-spam-high-neg: hsl(205, 65%, 20%);--pmg-spam-high-pos: hsl(0, 55%, 20%);--pmg-spam-mid-neg: hsl(205, 65%, 30%);--pmg-spam-mid-pos: hsl(0, 55%, 30%);--pmg-spam-low-neg: hsl(205, 65%, 40%);--pmg-spam-low-pos: hsl(0, 55%, 40%)}
.info-blue{color:#ffa35c !important}
.critical{color:hsl(0,100%,65%) !important}
tr.blocked,.x-keyboard-mode tr.blocked .x-grid-item-focused{background-color:#521414}
tr.quarantine,.x-keyboard-mode tr.quarantine .x-grid-item-focused{background-color:#5c2c0a}
tr.bounced,.x-keyboard-mode tr.bounced .x-grid-item-focused{background-color:#640}
.pmg-mail-preview-themed div>iframe{filter:brightness(95%) invert(95%)}
table.osds tr{border-color:#333947}
table.osds td{border-color:#333947}
.install-mask{background-color:#161a22;color:#e0e4eb}
.x-window.install-mask{box-shadow:#000 0 -1px 5px 1px !important}
div.monitor{border-color:#333947}
.pve-edit-tag.editable span{background-color:#1f232e;color:#e0e4eb;border-color:#333947}
.proxmox-tags-full .proxmox-tag-light,.proxmox-tags-full .proxmox-tag-dark,.proxmox-tags-circle .proxmox-tag-light,.proxmox-tags-circle .proxmox-tag-dark{outline:1px solid rgba(31,35,46,.3)}
.x-datepicker,.x-datepicker-column-header,.x-monthpicker{background-color:#161a22;color:#e0e4eb;border-color:rgba(0,0,0,0)}
.x-datepicker-month .x-btn-over.x-btn-default-small{background-color:#2a2f3c}
.x-monthpicker-months{border-color:#242833}
.x-datepicker-header{background-color:#0d1016}
.x-datepicker-cell,.x-monthpicker-item-inner{border-color:rgba(0,0,0,0)}
.x-datepicker-date,.x-monthpicker-item-inner{color:#e0e4eb}
.x-datepicker-prevday .x-datepicker-date,.x-datepicker-nextday .x-datepicker-date{color:#8790a1}
.x-datepicker-footer,.x-monthpicker-buttons{background-color:#0d1016}
.x-datepicker-selected div.x-datepicker-date,.x-monthpicker-item a.x-monthpicker-selected,a.x-monthpicker-item-inner:hover,div.x-datepicker-date:hover{background-color:#2a2f3c;color:#fff}
.x-datepicker-disabled .x-datepicker-date{background-color:#0d1016}
.x-datepicker-disabled div.x-datepicker-date:hover{background-color:#161a22}
:root{--pwt-chart-primary: #333947;--pwt-gauge-default: #f0690f;--pwt-chart-grid-stroke: #242833;--pmt-chart-fill-opacity: 0.28;--pmt-chart-series: #f0690f, #94a3b8, #475569, #ffa35c}
*{scrollbar-width:thin;scrollbar-color:rgba(240,105,15,.55) rgba(0,0,0,0)}
#versioninfo-body{color:#8790a1}
.x-panel-default,.x-panel-default-framed{border-color:#242833}
.x-panel-header-default{background-color:#161a22;border-color:#242833}
.x-panel-header-title-default>.x-title-text-default{color:#e0e4eb}
.x-panel-body-default{border-color:#242833}
.x-border-layout-ct>.x-panel-default,.x-border-layout-ct>.x-tab-panel,.x-border-layout-ct>.x-container-default,.x-border-layout-ct>.x-container>.x-panel-default{border-radius:10px;overflow:hidden;box-shadow:0 1px 2px rgba(0,0,0,.35),0 8px 24px rgba(0,0,0,.18)}
.pmx-rrd-chart,.x-panel-default.x-box-item[id^=proxmoxRRDChart],.x-panel-default[id^=pveNodeStatus],.x-panel-default[id^=pveGuestStatus]{border-radius:10px;overflow:hidden;border:1px solid #242833}
.x-toolbar-default{background-color:#161a22;border-color:#242833}
.x-panel-header-text-default{font-weight:600;color:#e0e4eb}
.x-btn{border-radius:7px}
.x-btn-default-small{box-shadow:0 1px 0 hsla(0,0%,100%,.08) inset,0 2px 6px rgba(240,105,15,.25)}
.x-btn-default-toolbar-small:not(.proxmox-inline-button){background-color:rgba(0,0,0,0);border-color:#333947}
.x-btn-default-toolbar-small:not(.proxmox-inline-button).x-btn-over{background-color:#2a2f3c;border-color:#333947}
.proxmox-inline-button.x-btn-pressed{background-color:rgba(240,105,15,.14);border-color:#f0690f}
.proxmox-inline-button.x-btn-pressed .x-btn-inner{color:#ffc599}
.x-btn-inner-default-small,.x-btn-inner-default-toolbar-small{font-weight:500}
.x-form-trigger-wrap-default{border-radius:7px;border-color:#333947;overflow:hidden}
.x-form-trigger-wrap-focus,.x-form-trigger-wrap-default.x-form-trigger-wrap-focus{border-color:#f0690f;box-shadow:inset 0 0 0 1px #f0690f}
.x-treelist-pve-nav .x-treelist-item-selected>.x-treelist-row::before,.x-tree-panel .x-grid-item-selected .x-grid-cell:first-child::before{content:"";position:absolute;top:4px;bottom:4px;left:0;width:3px;border-radius:3px;background-color:#f0690f}
.x-tree-panel .x-grid-item-selected,.x-tree-panel .x-grid-item-focused{background-color:rgba(0,0,0,0)}
.x-tree-panel .x-grid-item-over>table,.x-tree-panel .x-grid-item-over{background-color:rgba(0,0,0,0)}
.x-tree-panel .x-grid-item .x-grid-cell:first-child{border-top-left-radius:7px;border-bottom-left-radius:7px}
.x-tree-panel .x-grid-item .x-grid-cell:last-child{border-top-right-radius:7px;border-bottom-right-radius:7px}
.x-tree-panel .x-grid-item-over .x-grid-cell{background-color:rgba(240,105,15,.1)}
.x-tree-panel .x-grid-item-selected .x-grid-cell{background-color:rgba(240,105,15,.14)}
.x-tree-panel .x-grid-item-selected .x-grid-cell:first-child{position:relative}
.x-tree-panel .x-grid-item-selected .x-tree-node-text{color:#ffc599;font-weight:600}
.x-treelist-pve-nav,.x-treelist-pve-nav .x-treelist-item{background-color:#161a22}
.x-treelist-pve-nav .x-treelist-row{margin-left:8px;margin-right:8px;border-radius:7px}
.x-treelist-pve-nav .x-treelist-item-selected>.x-treelist-row{position:relative;background-color:rgba(240,105,15,.14)}
.x-treelist-pve-nav .x-treelist-item-selected>.x-treelist-row .x-treelist-item-text,.x-treelist-pve-nav .x-treelist-item-selected>.x-treelist-row .x-treelist-item-icon{color:#ffc599;font-weight:600}
.x-grid-header-ct,.x-column-header{background-color:#161a22;border-color:#242833}
.x-column-header-text-inner{color:#8790a1;font-weight:600}
.x-grid-item{background-color:#181c25}
.x-grid-item-alt{background-color:#181c25}
.x-grid-body .x-grid-item.x-grid-item-over,.x-keyboard-mode .x-grid-body .x-grid-item.x-grid-item-focused.x-grid-item-over{background-color:rgba(240,105,15,.1)}
.x-grid-body .x-grid-item.x-grid-item-selected,.x-keyboard-mode .x-grid-body .x-grid-item.x-grid-item-focused.x-grid-item-selected{background-color:rgba(240,105,15,.14)}
.x-keyboard-mode .x-grid-body .x-grid-cell.x-grid-item-focused{background-color:rgba(0,0,0,0)}
.x-keyboard-mode .x-tree-panel .x-grid-body .x-grid-item-selected .x-grid-cell.x-grid-item-focused{background-color:rgba(240,105,15,.14)}
.x-keyboard-mode .x-grid-body .x-grid-item.x-grid-item-focused{background-color:rgba(0,0,0,0);color:#e0e4eb}
.x-tree-panel .x-grid-body .x-grid-item.x-grid-item-over,.x-tree-panel .x-grid-body .x-grid-item.x-grid-item-selected{background-color:rgba(0,0,0,0)}
.x-grid-with-row-lines .x-grid-item{border-color:#242833}
.x-tab-bar-default{background-color:#161a22}
.x-tab-default-top{border-radius:999px;padding:3px 10px}
.x-tab-default-top .x-tab-inner-default{line-height:16px}
.x-tab-default-top:not(.x-tab-active){background-color:rgba(0,0,0,0);border-color:rgba(0,0,0,0)}
.x-tab-default-top.x-tab-over:not(.x-tab-active){background-color:rgba(240,105,15,.1)}
.x-progress-default{border-radius:999px;border:none;background-color:#1f232e;overflow:hidden}
.x-progress-default .x-progress-bar-default{border-radius:999px;background:linear-gradient(90deg, #c65310, #fa802e)}
.x-window-default,.x-menu-default,.x-boundlist{border-radius:10px;box-shadow:0 20px 50px rgba(0,0,0,.55);overflow:hidden}
.x-window-header-default{background-color:#161a22}
.x-splitter{background-color:rgba(0,0,0,0)}
.x-window-header-title-default>.x-title-text-default{color:#e0e4eb;font-weight:600}
.x-keyboard-mode .x-grid-item-focused .x-grid-cell-inner::before,.x-keyboard-mode .x-column-header.x-column-header-focus .x-column-header-inner::after,.x-keyboard-mode .x-btn-default-small.x-arrow-focus .x-btn-arrow-el,.x-keyboard-mode .x-btn-default-toolbar-small.x-arrow-focus .x-btn-arrow-el,.x-keyboard-mode .x-nbr .x-segmented-button-item.x-btn-focus::after{border-color:rgba(0,0,0,0)}
.x-keyboard-mode .x-grid-item-focused:not(.x-grid-item-selected) .x-grid-cell{box-shadow:inset 0 0 0 1px rgba(240,105,15,.45)}
.x-keyboard-mode .x-btn-focus.x-btn-default-small:not(.proxmox-inline-button){background-color:#f0690f;border-color:#f0690f;box-shadow:0 1px 0 hsla(0,0%,100%,.08) inset,0 2px 6px rgba(240,105,15,.25)}
.x-keyboard-mode .x-btn-focus.x-btn-default-small:not(.proxmox-inline-button).x-btn-over{background-color:#fa802e;border-color:#fa802e}
.x-keyboard-mode .x-btn-focus.x-btn-default-small:not(.proxmox-inline-button).x-btn-pressed,.x-keyboard-mode .x-btn-focus.x-btn-default-small:not(.proxmox-inline-button).x-btn-menu-active{background-color:#c65310;border-color:#c65310}
.x-keyboard-mode .x-btn-focus.x-btn-default-toolbar-small,.x-keyboard-mode .x-btn-focus.x-btn-default-toolbar-small.x-btn-over,.x-keyboard-mode .x-btn-focus.x-btn-default-toolbar-small.x-btn-pressed,.x-keyboard-mode .x-btn-focus.x-btn-default-toolbar-small.x-btn-menu-active{box-shadow:none}
.x-keyboard-mode .x-btn-focus.x-btn-default-toolbar-small:not(.proxmox-inline-button){background-color:rgba(0,0,0,0);border-color:#333947}
.x-keyboard-mode .x-btn-focus.x-btn-default-toolbar-small.x-btn-over:not(.proxmox-inline-button){background-color:#2a2f3c}
.x-keyboard-mode .x-btn-focus.proxmox-inline-button{background-image:none;background-color:#242833;border-color:#333947;box-shadow:none}
.x-keyboard-mode .x-btn-focus.proxmox-inline-button.x-btn-over{background-color:#333947}
.x-keyboard-mode .x-btn-focus.proxmox-inline-button.x-btn-pressed{background-color:rgba(240,105,15,.14);border-color:#f0690f}
.x-keyboard-mode .x-tab-focus.x-tab-default{background-color:rgba(0,0,0,0);border-color:rgba(0,0,0,0)}
.x-keyboard-mode .x-tab-focus.x-tab-default,.x-keyboard-mode .x-tab-focus.x-tab-default.x-tab-over,.x-keyboard-mode .x-tab-focus.x-tab-default.x-tab-active{box-shadow:none}
.x-keyboard-mode .x-tab-focus.x-tab-default.x-tab-over{background-color:rgba(240,105,15,.1);border-color:rgba(0,0,0,0)}
.x-keyboard-mode .x-tab-focus.x-tab-default.x-tab-active{background-color:#f0690f;border-color:#f0690f}
.x-keyboard-mode .x-tool-focus,.x-keyboard-mode .x-panel-header-default .x-tool-focus,.x-keyboard-mode .x-panel-header-default-framed .x-tool-focus,.x-keyboard-mode .x-window-header-default .x-tool-focus,.x-keyboard-mode .x-accordion-hd .x-tool-focus{outline:none}
.x-keyboard-mode .x-title-focus,.x-keyboard-mode .x-fieldset-header-tool-default.x-focus,.x-keyboard-mode .x-field-form-focus{outline-color:rgba(240,105,15,.5)}
.x-keyboard-mode .x-view-item-focused{outline-color:rgba(240,105,15,.5) !important}
.x-segmented-button .x-segmented-button-item.proxmox-inline-button{background-image:none;background-color:#242833;border-color:#333947;box-shadow:none}
.x-segmented-button .x-segmented-button-item.proxmox-inline-button .x-btn-inner{color:#8790a1;font-weight:600}
.x-segmented-button .x-segmented-button-item.proxmox-inline-button.x-btn-over{background-color:#333947}
.x-segmented-button .x-segmented-button-item.proxmox-inline-button.x-btn-pressed{background-color:#f0690f;background-image:linear-gradient(135deg, #fa802e, #c65310);border-color:#c65310}
.x-segmented-button .x-segmented-button-item.proxmox-inline-button.x-btn-pressed .x-btn-inner{color:#fff}
.x-keyboard-mode .x-segmented-button .x-segmented-button-item.proxmox-inline-button{background-image:none;background-color:#242833;border-color:#333947;box-shadow:none}
.x-keyboard-mode .x-segmented-button .x-segmented-button-item.proxmox-inline-button .x-btn-inner{color:#8790a1;font-weight:600}
.x-keyboard-mode .x-segmented-button .x-segmented-button-item.proxmox-inline-button.x-btn-over{background-color:#333947}
.x-keyboard-mode .x-segmented-button .x-segmented-button-item.proxmox-inline-button.x-btn-pressed{background-color:#f0690f;background-image:linear-gradient(135deg, #fa802e, #c65310);border-color:#c65310}
.x-keyboard-mode .x-segmented-button .x-segmented-button-item.proxmox-inline-button.x-btn-pressed .x-btn-inner{color:#fff}
.x-tip-default{background-color:#161a22;border-color:#333947;border-radius:7px;box-shadow:0 1px 2px rgba(0,0,0,.35),0 8px 24px rgba(0,0,0,.18)}
.x-tip-default .x-tip-body-default{color:#e0e4eb}
.x-menu-item-default.x-menu-item-focus,.x-menu-item-default.x-menu-item-active{background-color:rgba(240,105,15,.14)}
.x-menu-item-default.x-menu-item-focus .x-menu-item-text,.x-menu-item-default.x-menu-item-focus .x-menu-item-icon-default,.x-menu-item-default.x-menu-item-active .x-menu-item-text,.x-menu-item-default.x-menu-item-active .x-menu-item-icon-default{color:#ffa35c}
.x-legend,.x-legend-container{background-color:rgba(0,0,0,0)}
.x-legend-horizontal .x-legend-item{background-color:#242833;border-color:#333947}
.x-legend-horizontal .x-legend-item:first-child{border-left-color:#333947;border-top-left-radius:999px;border-bottom-left-radius:999px}
.x-legend-horizontal .x-legend-item:last-child{border-top-right-radius:999px;border-bottom-right-radius:999px}
.x-boundlist-item-over,.x-treelist-row-over,.x-treelist-pve-nav .x-treelist-row-over{background-color:rgba(240,105,15,.1);border-color:rgba(0,0,0,0)}
.x-boundlist-selected,.x-boundlist-item-over.x-boundlist-selected{background-color:rgba(240,105,15,.14);border-color:rgba(0,0,0,0);color:#ffa35c}
PMT_CSS
}

theme_css_shared() {
    cat <<'PMT_CSS'
.x-css-shadow{border-radius:10px}
.x-grid-with-col-lines .x-grid-item.x-grid-item-over .x-grid-cell,.x-grid-with-col-lines .x-grid-item.x-grid-item-selected .x-grid-cell{border-right-color:rgba(0,0,0,0)}
.fa-users::before,.fa-user-o::before,.fa-user::before,.fa-unlock::before,.fa-undo::before,.fa-tv::before,.fa-times::before,.fa-th-large::before,.fa-th::before,.fa-terminal::before,.fa-tasks::before,.fa-tags::before,.fa-support::before,.fa-sticky-note-o::before,.fa-square-o::before,.fa-square::before,.fa-sitemap::before,.fa-shield::before,.fa-server::before,.fa-send-o::before,.fa-search::before,.fa-road::before,.fa-retweet::before,.fa-refresh::before,.fa-question-circle::before,.fa-power-off::before,.fa-plus::before,.fa-play::before,.fa-pencil-square-o::before,.fa-pencil::before,.fa-network-wired::before,.fa-minus-square::before,.fa-microchip::before,.fa-map-signs::before,.fa-map::before,.fa-male::before,.fa-lock::before,.fa-list-ol::before,.fa-list-alt::before,.fa-list::before,.fa-key::before,.fa-info::before,.fa-history::before,.fa-heartbeat::before,.fa-hdd-o::before,.fa-group::before,.fa-globe::before,.fa-gears::before,.fa-gear::before,.fa-folder-o::before,.fa-folder::before,.fa-floppy-o::before,.fa-files-o::before,.fa-file-o::before,.fa-eye::before,.fa-external-link::before,.fa-exchange::before,.fa-ellipsis-v::before,.fa-desktop::before,.fa-database::before,.fa-cube::before,.fa-comments-o::before,.fa-cogs::before,.fa-cloud::before,.fa-clock-o::before,.fa-chevron-right::before,.fa-check::before,.fa-certificate::before,.fa-building::before,.fa-book::before,.fa-bolt::before,.fa-bell-o::before,.fa-bars::before,.fa-bar-chart::before,.fa-address-book-o::before{content:"";display:inline-block;width:16px;height:16px;margin:-1px;vertical-align:-3px;background-color:currentColor;-webkit-mask:var(--modern-icon) center/contain no-repeat;mask:var(--modern-icon) center/contain no-repeat}
.fa-address-book-o::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M208,32H64a8,8,0,0,0-8,8V216a8,8,0,0,0,8,8H208a8,8,0,0,0,8-8V40A8,8,0,0,0,208,32ZM136,144a32,32,0,1,1,32-32A32,32,0,0,1,136,144Z' opacity='0.4'/%3E%3Cpath d='M208,20H64A20,20,0,0,0,44,40V60H32a12,12,0,0,0,0,24H44v32H32a12,12,0,0,0,0,24H44v32H32a12,12,0,0,0,0,24H44v20a20,20,0,0,0,20,20H208a20,20,0,0,0,20-20V40A20,20,0,0,0,208,20Zm-4,192H68V44H204ZM100.8,171.37a48,48,0,0,1,70.4,0,12,12,0,0,0,17.6-16.32,72,72,0,0,0-19.21-14.68,44,44,0,1,0-67.19,0,72.12,72.12,0,0,0-19.2,14.68,12,12,0,0,0,17.6,16.32ZM116,112a20,20,0,1,1,20,20A20,20,0,0,1,116,112Z'/%3E%3C/svg%3E")}
.fa-bar-chart::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M208,40V208H152V40Z' opacity='0.4'/%3E%3Cpath d='M224,196h-4V40a12,12,0,0,0-12-12H152a12,12,0,0,0-12,12V76H96A12,12,0,0,0,84,88v36H48a12,12,0,0,0-12,12v60H32a12,12,0,0,0,0,24H224a12,12,0,0,0,0-24ZM164,52h32V196H164Zm-56,48h32v96H108ZM60,148H84v48H60Z'/%3E%3C/svg%3E")}
.fa-bars::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M228,128a12,12,0,0,1-12,12H40a12,12,0,0,1,0-24H216A12,12,0,0,1,228,128ZM40,76H216a12,12,0,0,0,0-24H40a12,12,0,0,0,0,24ZM216,180H40a12,12,0,0,0,0,24H216a12,12,0,0,0,0-24Z'/%3E%3C/svg%3E")}
.fa-bell-o::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M208,192H48a8,8,0,0,1-6.88-12C47.71,168.6,56,139.81,56,104a72,72,0,0,1,144,0c0,35.82,8.3,64.6,14.9,76A8,8,0,0,1,208,192Z' opacity='0.4'/%3E%3Cpath d='M225.29,165.93C216.61,151,212,129.57,212,104a84,84,0,0,0-168,0c0,25.58-4.59,47-13.27,61.93A20.08,20.08,0,0,0,30.66,186,19.77,19.77,0,0,0,48,196H84.18a44,44,0,0,0,87.64,0H208a19.77,19.77,0,0,0,17.31-10A20.08,20.08,0,0,0,225.29,165.93ZM128,212a20,20,0,0,1-19.6-16h39.2A20,20,0,0,1,128,212ZM54.66,172C63.51,154,68,131.14,68,104a60,60,0,0,1,120,0c0,27.13,4.48,50,13.33,68Z'/%3E%3C/svg%3E")}
.fa-bolt::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M96,240l16-80L48,136,160,16,144,96l64,24Z' opacity='0.4'/%3E%3Cpath d='M219.71,117.38a12,12,0,0,0-7.25-8.52L161.28,88.39l10.59-70.61a12,12,0,0,0-20.64-10l-112,120a12,12,0,0,0,4.31,19.33l51.18,20.47L84.13,238.22a12,12,0,0,0,20.64,10l112-120A12,12,0,0,0,219.71,117.38ZM113.6,203.55l6.27-41.77a12,12,0,0,0-7.41-12.92L68.74,131.37,142.4,52.45l-6.27,41.77a12,12,0,0,0,7.41,12.92l43.72,17.49Z'/%3E%3C/svg%3E")}
.fa-book::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M232,56V200H160a32,32,0,0,0-32,32,32,32,0,0,0-32-32H24V56H96a32,32,0,0,1,32,32,32,32,0,0,1,32-32Z' opacity='0.4'/%3E%3Cpath d='M232,44H160a43.86,43.86,0,0,0-32,13.85A43.86,43.86,0,0,0,96,44H24A12,12,0,0,0,12,56V200a12,12,0,0,0,12,12H96a20,20,0,0,1,20,20,12,12,0,0,0,24,0,20,20,0,0,1,20-20h72a12,12,0,0,0,12-12V56A12,12,0,0,0,232,44ZM96,188H36V68H96a20,20,0,0,1,20,20V192.81A43.79,43.79,0,0,0,96,188Zm124,0H160a43.71,43.71,0,0,0-20,4.83V88a20,20,0,0,1,20-20h60Z'/%3E%3C/svg%3E")}
.fa-building::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M216,152v48a8,8,0,0,1-8,8H48a8,8,0,0,1-8-8V152a8,8,0,0,1,8-8H208A8,8,0,0,1,216,152ZM208,48H48a8,8,0,0,0-8,8v48a8,8,0,0,0,8,8H208a8,8,0,0,0,8-8V56A8,8,0,0,0,208,48Z' opacity='0.4'/%3E%3Cpath d='M208,36H48A20,20,0,0,0,28,56V200a20,20,0,0,0,20,20H208a20,20,0,0,0,20-20V56A20,20,0,0,0,208,36Zm-4,24v56H52V60ZM52,196V140H204v56ZM160,88a16,16,0,1,1,16,16A16,16,0,0,1,160,88Zm32,80a16,16,0,1,1-16-16A16,16,0,0,1,192,168Z'/%3E%3C/svg%3E")}
.fa-certificate::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M224,56V90.06h0a44,44,0,1,0-56,67.88h0V192H40a8,8,0,0,1-8-8V56a8,8,0,0,1,8-8H216A8,8,0,0,1,224,56Z' opacity='0.4'/%3E%3Cpath d='M128,140a12,12,0,0,1-12,12H72a12,12,0,0,1,0-24h44A12,12,0,0,1,128,140ZM116,88H72a12,12,0,0,0,0,24h44a12,12,0,0,0,0-24Zm120,79.14V228a12,12,0,0,1-17.95,10.42L196,225.82,174,238.42A12,12,0,0,1,156,228V204H40a20,20,0,0,1-20-20V56A20,20,0,0,1,40,36H216a20,20,0,0,1,20,20V88.86a55.87,55.87,0,0,1,0,78.28ZM196,160a32,32,0,1,0-32-32A32,32,0,0,0,196,160Zm-40,20V167.14a56,56,0,0,1,56-92.8V60H44V180Zm56,27.32V181.66a55.87,55.87,0,0,1-32,0v25.66l10.05-5.74a12,12,0,0,1,11.9,0Z'/%3E%3C/svg%3E")}
.fa-check::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M232.49,80.49l-128,128a12,12,0,0,1-17,0l-56-56a12,12,0,1,1,17-17L96,183,215.51,63.51a12,12,0,0,1,17,17Z'/%3E%3C/svg%3E")}
.fa-chevron-right::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M184.49,136.49l-80,80a12,12,0,0,1-17-17L159,128,87.51,56.49a12,12,0,1,1,17-17l80,80A12,12,0,0,1,184.49,136.49Z'/%3E%3C/svg%3E")}
.fa-clock-o::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M224,128a96,96,0,1,1-96-96A96,96,0,0,1,224,128Z' opacity='0.4'/%3E%3Cpath d='M128,20A108,108,0,1,0,236,128,108.12,108.12,0,0,0,128,20Zm0,192a84,84,0,1,1,84-84A84.09,84.09,0,0,1,128,212Zm68-84a12,12,0,0,1-12,12H128a12,12,0,0,1-12-12V72a12,12,0,0,1,24,0v44h44A12,12,0,0,1,196,128Z'/%3E%3C/svg%3E")}
.fa-cloud::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M240,128a80,80,0,0,1-80,80H72A56,56,0,1,1,85.92,97.74l0,.1A80,80,0,0,1,240,128Z' opacity='0.4'/%3E%3Cpath d='M160,36A92.09,92.09,0,0,0,79,84.36,68,68,0,1,0,72,220h88a92,92,0,0,0,0-184Zm0,160H72a44,44,0,0,1-1.82-88A91.86,91.86,0,0,0,68,128a12,12,0,0,0,24,0,68,68,0,1,1,68,68Z'/%3E%3C/svg%3E")}
.fa-cogs::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M40,92H70.06a36,36,0,0,0,67.88,0H216a12,12,0,0,0,0-24H137.94a36,36,0,0,0-67.88,0H40a12,12,0,0,0,0,24Zm64-24A12,12,0,1,1,92,80,12,12,0,0,1,104,68Zm112,96H201.94a36,36,0,0,0-67.88,0H40a12,12,0,0,0,0,24h94.06a36,36,0,0,0,67.88,0H216a12,12,0,0,0,0-24Zm-48,24a12,12,0,1,1,12-12A12,12,0,0,1,168,188Z'/%3E%3C/svg%3E")}
.fa-comments-o::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M231.66,213.73a8,8,0,0,1-9.93,9.93L194,215.5A72.05,72.05,0,0,1,92.06,175.89h0c1.31.07,2.62.11,3.94.11a72,72,0,0,0,67.93-95.88h0A72,72,0,0,1,223.5,186Z' opacity='0.4'/%3E%3Cpath d='M236.34,187.09A84,84,0,0,0,172.29,68.9,84,84,0,0,0,19.66,139.09l-6.84,23.26a20,20,0,0,0,24.83,24.83l23.26-6.84a83.94,83.94,0,0,0,22.76,6.74,84.06,84.06,0,0,0,111.42,41.26l23.26,6.84a20,20,0,0,0,24.83-24.83ZM62,155.5a11.88,11.88,0,0,0-3.39.49l-20.72,6.09L44,141.35a12,12,0,0,0-.93-9A60,60,0,1,1,67.7,156.92,12,12,0,0,0,62,155.5Zm150.89,24.8a12,12,0,0,0-.93,9l6.09,20.73L197.36,204a12,12,0,0,0-9.06.93A60,60,0,0,1,111,186.63a83.93,83.93,0,0,0,68.55-91.37,60,60,0,0,1,33.38,85Z'/%3E%3C/svg%3E")}
.fa-cube::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M128,129.09V232a8,8,0,0,1-3.84-1l-88-48.16a8,8,0,0,1-4.16-7V80.2a8,8,0,0,1,.7-3.27Z' opacity='0.4'/%3E%3Cpath d='M225.6,62.64l-88-48.17a19.91,19.91,0,0,0-19.2,0l-88,48.17A20,20,0,0,0,20,80.19v95.62a20,20,0,0,0,10.4,17.55l88,48.17a19.89,19.89,0,0,0,19.2,0l88-48.17A20,20,0,0,0,236,175.81V80.19A20,20,0,0,0,225.6,62.64ZM128,36.57,200,76,128,115.4,56,76ZM44,96.79l72,39.4v76.67L44,173.44Zm96,116.07V136.19l72-39.4v76.65Z'/%3E%3C/svg%3E")}
.fa-database::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M216,80c0,26.51-39.4,48-88,48S40,106.51,40,80s39.4-48,88-48S216,53.49,216,80Z' opacity='0.4'/%3E%3Cpath d='M196,35.52C177.62,25.51,153.48,20,128,20S78.38,25.51,60,35.52C39.37,46.79,28,62.58,28,80v96c0,17.42,11.37,33.21,32,44.48,18.35,10,42.49,15.52,68,15.52s49.62-5.51,68-15.52c20.66-11.27,32-27.06,32-44.48V80C228,62.58,216.63,46.79,196,35.52ZM204,128c0,17-31.21,36-76,36s-76-19-76-36v-8.46a88.9,88.9,0,0,0,8,4.94c18.35,10,42.49,15.52,68,15.52s49.62-5.51,68-15.52a88.9,88.9,0,0,0,8-4.94ZM128,44c44.79,0,76,19,76,36s-31.21,36-76,36S52,97,52,80,83.21,44,128,44Zm0,168c-44.79,0-76-19-76-36v-8.46a88.9,88.9,0,0,0,8,4.94c18.35,10,42.49,15.52,68,15.52s49.62-5.51,68-15.52a88.9,88.9,0,0,0,8-4.94V176C204,193,172.79,212,128,212Z'/%3E%3C/svg%3E")}
.fa-desktop::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M224,64v88H32V64A16,16,0,0,1,48,48H208A16,16,0,0,1,224,64Z' opacity='0.4'/%3E%3Cpath d='M208,36H48A28,28,0,0,0,20,64V172a28,28,0,0,0,28,28h68v12H96a12,12,0,0,0,0,24h64a12,12,0,0,0,0-24H140V200h68a28,28,0,0,0,28-28V64A28,28,0,0,0,208,36ZM48,60H208a4,4,0,0,1,4,4v72H44V64A4,4,0,0,1,48,60ZM208,176H48a4,4,0,0,1-4-4V160H212v12A4,4,0,0,1,208,176Z'/%3E%3C/svg%3E")}
.fa-ellipsis-v::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M112,60a16,16,0,1,1,16,16A16,16,0,0,1,112,60Zm16,52a16,16,0,1,0,16,16A16,16,0,0,0,128,112Zm0,68a16,16,0,1,0,16,16A16,16,0,0,0,128,180Z'/%3E%3C/svg%3E")}
.fa-exchange::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M216.49,184.49l-32,32a12,12,0,0,1-17-17L179,188H48a12,12,0,0,1,0-24H179l-11.52-11.51a12,12,0,0,1,17-17l32,32A12,12,0,0,1,216.49,184.49Zm-145-64a12,12,0,0,0,17-17L77,92H208a12,12,0,0,0,0-24H77L88.49,56.49a12,12,0,0,0-17-17l-32,32a12,12,0,0,0,0,17Z'/%3E%3C/svg%3E")}
.fa-external-link::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M184,80V208a8,8,0,0,1-8,8H48a8,8,0,0,1-8-8V80a8,8,0,0,1,8-8H176A8,8,0,0,1,184,80Z' opacity='0.4'/%3E%3Cpath d='M228,104a12,12,0,0,1-24,0V69l-59.51,59.51a12,12,0,0,1-17-17L187,52H152a12,12,0,0,1,0-24h64a12,12,0,0,1,12,12Zm-44,24a12,12,0,0,0-12,12v64H52V84h64a12,12,0,0,0,0-24H48A20,20,0,0,0,28,80V208a20,20,0,0,0,20,20H176a20,20,0,0,0,20-20V140A12,12,0,0,0,184,128Z'/%3E%3C/svg%3E")}
.fa-eye::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M128,56C48,56,16,128,16,128s32,72,112,72,112-72,112-72S208,56,128,56Zm0,112a40,40,0,1,1,40-40A40,40,0,0,1,128,168Z' opacity='0.4'/%3E%3Cpath d='M251,123.13c-.37-.81-9.13-20.26-28.48-39.61C196.63,57.67,164,44,128,44S59.37,57.67,33.51,83.52C14.16,102.87,5.4,122.32,5,123.13a12.08,12.08,0,0,0,0,9.75c.37.82,9.13,20.26,28.49,39.61C59.37,198.34,92,212,128,212s68.63-13.66,94.48-39.51c19.36-19.35,28.12-38.79,28.49-39.61A12.08,12.08,0,0,0,251,123.13Zm-46.06,33C183.47,177.27,157.59,188,128,188s-55.47-10.73-76.91-31.88A130.36,130.36,0,0,1,29.52,128,130.45,130.45,0,0,1,51.09,99.89C72.54,78.73,98.41,68,128,68s55.46,10.73,76.91,31.89A130.36,130.36,0,0,1,226.48,128,130.45,130.45,0,0,1,204.91,156.12ZM128,84a44,44,0,1,0,44,44A44.05,44.05,0,0,0,128,84Zm0,64a20,20,0,1,1,20-20A20,20,0,0,1,128,148Z'/%3E%3C/svg%3E")}
.fa-file-o::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M208,88H152V32Z' opacity='0.4'/%3E%3Cpath d='M216.49,79.52l-56-56A12,12,0,0,0,152,20H56A20,20,0,0,0,36,40V216a20,20,0,0,0,20,20H200a20,20,0,0,0,20-20V88A12,12,0,0,0,216.49,79.52ZM160,57l23,23H160ZM60,212V44h76V92a12,12,0,0,0,12,12h48V212Z'/%3E%3C/svg%3E")}
.fa-files-o::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M208,72V184a8,8,0,0,1-8,8H176V104L136,64H80V40a8,8,0,0,1,8-8h80Z' opacity='0.4'/%3E%3Cpath d='M220.49,59.51l-40-40A12,12,0,0,0,172,16H92A20,20,0,0,0,72,36V56H56A20,20,0,0,0,36,76V216a20,20,0,0,0,20,20H164a20,20,0,0,0,20-20V196h20a20,20,0,0,0,20-20V68A12,12,0,0,0,220.49,59.51ZM160,212H60V80h67l33,33Zm40-40H184V108a12,12,0,0,0-3.51-8.49l-40-40A12,12,0,0,0,132,56H96V40h71l33,33Zm-56-28a12,12,0,0,1-12,12H88a12,12,0,0,1,0-24h44A12,12,0,0,1,144,144Zm0,40a12,12,0,0,1-12,12H88a12,12,0,0,1,0-24h44A12,12,0,0,1,144,184Z'/%3E%3C/svg%3E")}
.fa-floppy-o::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M216,83.31V208a8,8,0,0,1-8,8H176V152a8,8,0,0,0-8-8H88a8,8,0,0,0-8,8v64H48a8,8,0,0,1-8-8V48a8,8,0,0,1,8-8H172.69a8,8,0,0,1,5.65,2.34l35.32,35.32A8,8,0,0,1,216,83.31Z' opacity='0.4'/%3E%3Cpath d='M222.14,69.17,186.83,33.86A19.86,19.86,0,0,0,172.69,28H48A20,20,0,0,0,28,48V208a20,20,0,0,0,20,20H208a20,20,0,0,0,20-20V83.31A19.86,19.86,0,0,0,222.14,69.17ZM164,204H92V160h72Zm40,0H188V156a20,20,0,0,0-20-20H88a20,20,0,0,0-20,20v48H52V52H171l33,33ZM164,84a12,12,0,0,1-12,12H96a12,12,0,0,1,0-24h56A12,12,0,0,1,164,84Z'/%3E%3C/svg%3E")}
.fa-folder::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M128,80H32V56a8,8,0,0,1,8-8H92.69a8,8,0,0,1,5.65,2.34Z' opacity='0.4'/%3E%3Cpath d='M216,68H133.39l-26-29.29a20,20,0,0,0-15-6.71H40A20,20,0,0,0,20,52V200.62A19.41,19.41,0,0,0,39.38,220H216.89A19.13,19.13,0,0,0,236,200.89V88A20,20,0,0,0,216,68ZM44,56H90.61l10.67,12H44ZM212,196H44V92H212Z'/%3E%3C/svg%3E")}
.fa-folder-o::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M128,80H32V56a8,8,0,0,1,8-8H92.69a8,8,0,0,1,5.65,2.34Z' opacity='0.4'/%3E%3Cpath d='M216,68H133.39l-26-29.29a20,20,0,0,0-15-6.71H40A20,20,0,0,0,20,52V200.62A19.41,19.41,0,0,0,39.38,220H216.89A19.13,19.13,0,0,0,236,200.89V88A20,20,0,0,0,216,68ZM44,56H90.61l10.67,12H44ZM212,196H44V92H212Z'/%3E%3C/svg%3E")}
.fa-gear::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M230.1,108.76,198.25,90.62c-.64-1.16-1.31-2.29-2-3.41l-.12-36A104.61,104.61,0,0,0,162,32L130,49.89c-1.34,0-2.69,0-4,0L94,32A104.58,104.58,0,0,0,59.89,51.25l-.16,36c-.7,1.12-1.37,2.26-2,3.41l-31.84,18.1a99.15,99.15,0,0,0,0,38.46l31.85,18.14c.64,1.16,1.31,2.29,2,3.41l.12,36A104.61,104.61,0,0,0,94,224l32-17.87c1.34,0,2.69,0,4,0L162,224a104.58,104.58,0,0,0,34.08-19.25l.16-36c.7-1.12,1.37-2.26,2-3.41l31.84-18.1A99.15,99.15,0,0,0,230.1,108.76ZM128,168a40,40,0,1,1,40-40A40,40,0,0,1,128,168Z' opacity='0.4'/%3E%3Cpath d='M128,76a52,52,0,1,0,52,52A52.06,52.06,0,0,0,128,76Zm0,80a28,28,0,1,1,28-28A28,28,0,0,1,128,156Zm113.86-49.57A12,12,0,0,0,236,98.34L208.21,82.49l-.11-31.31a12,12,0,0,0-4.25-9.12,116,116,0,0,0-38-21.41,12,12,0,0,0-9.68.89L128,37.27,99.83,21.53a12,12,0,0,0-9.7-.9,116.06,116.06,0,0,0-38,21.47,12,12,0,0,0-4.24,9.1l-.14,31.34L20,98.35a12,12,0,0,0-5.85,8.11,110.7,110.7,0,0,0,0,43.11A12,12,0,0,0,20,157.66l27.82,15.85.11,31.31a12,12,0,0,0,4.25,9.12,116,116,0,0,0,38,21.41,12,12,0,0,0,9.68-.89L128,218.73l28.14,15.74a12,12,0,0,0,9.7.9,116.06,116.06,0,0,0,38-21.47,12,12,0,0,0,4.24-9.1l.14-31.34,27.81-15.81a12,12,0,0,0,5.85-8.11A110.7,110.7,0,0,0,241.86,106.43Zm-22.63,33.18-26.88,15.28a11.94,11.94,0,0,0-4.55,4.59c-.54,1-1.11,1.93-1.7,2.88a12,12,0,0,0-1.83,6.31L184.13,199a91.83,91.83,0,0,1-21.07,11.87l-27.15-15.19a12,12,0,0,0-5.86-1.53h-.29c-1.14,0-2.3,0-3.44,0a12.08,12.08,0,0,0-6.14,1.51L93,210.82A92.27,92.27,0,0,1,71.88,199l-.11-30.24a12,12,0,0,0-1.83-6.32c-.58-.94-1.16-1.91-1.7-2.88A11.92,11.92,0,0,0,63.7,155L36.8,139.63a86.53,86.53,0,0,1,0-23.24l26.88-15.28a12,12,0,0,0,4.55-4.58c.54-1,1.11-1.94,1.7-2.89a12,12,0,0,0,1.83-6.31L71.87,57A91.83,91.83,0,0,1,92.94,45.17l27.15,15.19a11.92,11.92,0,0,0,6.15,1.52c1.14,0,2.3,0,3.44,0a12.08,12.08,0,0,0,6.14-1.51L163,45.18A92.27,92.27,0,0,1,184.12,57l.11,30.24a12,12,0,0,0,1.83,6.32c.58.94,1.16,1.91,1.7,2.88A11.92,11.92,0,0,0,192.3,101l26.9,15.33A86.53,86.53,0,0,1,219.23,139.61Z'/%3E%3C/svg%3E")}
.fa-gears::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M40,92H70.06a36,36,0,0,0,67.88,0H216a12,12,0,0,0,0-24H137.94a36,36,0,0,0-67.88,0H40a12,12,0,0,0,0,24Zm64-24A12,12,0,1,1,92,80,12,12,0,0,1,104,68Zm112,96H201.94a36,36,0,0,0-67.88,0H40a12,12,0,0,0,0,24h94.06a36,36,0,0,0,67.88,0H216a12,12,0,0,0,0-24Zm-48,24a12,12,0,1,1,12-12A12,12,0,0,1,168,188Z'/%3E%3C/svg%3E")}
.fa-globe::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M224,128a96,96,0,1,1-96-96A96,96,0,0,1,224,128Z' opacity='0.4'/%3E%3Cpath d='M128,20A108,108,0,1,0,236,128,108.12,108.12,0,0,0,128,20Zm0,187a113.4,113.4,0,0,1-20.39-35h40.82a116.94,116.94,0,0,1-10,20.77A108.61,108.61,0,0,1,128,207Zm-26.49-59a135.42,135.42,0,0,1,0-40h53a135.42,135.42,0,0,1,0,40ZM44,128a83.49,83.49,0,0,1,2.43-20H77.25a160.63,160.63,0,0,0,0,40H46.43A83.49,83.49,0,0,1,44,128Zm84-79a113.4,113.4,0,0,1,20.39,35H107.59a116.94,116.94,0,0,1,10-20.77A108.61,108.61,0,0,1,128,49Zm50.73,59h30.82a83.52,83.52,0,0,1,0,40H178.75a160.63,160.63,0,0,0,0-40Zm20.77-24H173.71a140.82,140.82,0,0,0-15.5-34.36A84.51,84.51,0,0,1,199.52,84ZM97.79,49.64A140.82,140.82,0,0,0,82.29,84H56.48A84.51,84.51,0,0,1,97.79,49.64ZM56.48,172H82.29a140.82,140.82,0,0,0,15.5,34.36A84.51,84.51,0,0,1,56.48,172Zm101.73,34.36A140.82,140.82,0,0,0,173.71,172h25.81A84.51,84.51,0,0,1,158.21,206.36Z'/%3E%3C/svg%3E")}
.fa-group::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M136,108A52,52,0,1,1,84,56,52,52,0,0,1,136,108Z' opacity='0.4'/%3E%3Cpath d='M125.18,156.94a64,64,0,1,0-82.36,0,100.23,100.23,0,0,0-39.49,32,12,12,0,0,0,19.35,14.2,76,76,0,0,1,122.64,0,12,12,0,0,0,19.36-14.2A100.33,100.33,0,0,0,125.18,156.94ZM44,108a40,40,0,1,1,40,40A40,40,0,0,1,44,108Zm206.1,97.67a12,12,0,0,1-16.78-2.57A76.31,76.31,0,0,0,172,172a12,12,0,0,1,0-24,40,40,0,1,0-10.3-78.67,12,12,0,1,1-6.16-23.19,64,64,0,0,1,57.64,110.8,100.23,100.23,0,0,1,39.49,32A12,12,0,0,1,250.1,205.67Z'/%3E%3C/svg%3E")}
.fa-hdd-o::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M232,80v96a8,8,0,0,1-8,8H32a8,8,0,0,1-8-8V80a8,8,0,0,1,8-8H224A8,8,0,0,1,232,80Z' opacity='0.4'/%3E%3Cpath d='M224,60H32A20,20,0,0,0,12,80v96a20,20,0,0,0,20,20H224a20,20,0,0,0,20-20V80A20,20,0,0,0,224,60Zm-4,112H36V84H220Zm-56-44a16,16,0,1,1,16,16A16,16,0,0,1,164,128Z'/%3E%3C/svg%3E")}
.fa-heartbeat::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M232,102c0,66-104,122-104,122S24,168,24,102A54,54,0,0,1,78,48c22.59,0,41.94,12.31,50,32,8.06-19.69,27.41-32,50-32A54,54,0,0,1,232,102Z' opacity='0.4'/%3E%3Cpath d='M71.76,148H31.7a12,12,0,1,1,0-24H65.33l12.45-18.66a12,12,0,0,1,20,0l22,33,6-9a12,12,0,0,1,10-5.34h24a12,12,0,1,1,0,24h-17.6l-12.46,18.66a12,12,0,0,1-20,0l-22-33-6,9A12,12,0,0,1,71.76,148ZM177.91,36c-20.12,0-38,7.93-50.07,21.56C115.74,43.93,97.89,36,77.76,36A66,66,0,0,0,12.07,94.68,12,12,0,0,0,36,97.32,42,42,0,0,1,77.76,60c17.83,0,32.75,9.4,38.95,24.54a12,12,0,0,0,22.25,0C145.16,69.4,160.08,60,177.91,60A42.08,42.08,0,0,1,220,102c0,29.42-25.86,57.77-47.56,76.36a329,329,0,0,1-44.58,31.81c-10.87-6.45-35.37-22-56.51-42.73a12,12,0,1,0-16.84,17.12c30.39,29.81,66.15,49.2,67.66,50a12.06,12.06,0,0,0,11.39,0C138,232.14,244,174.34,244,102A66.12,66.12,0,0,0,177.91,36Z'/%3E%3C/svg%3E")}
.fa-history::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M216,128a88,88,0,1,1-88-88A88,88,0,0,1,216,128Z' opacity='0.4'/%3E%3Cpath d='M140,80v41.21l34.17,20.5a12,12,0,1,1-12.34,20.58l-40-24A12,12,0,0,1,116,128V80a12,12,0,0,1,24,0ZM128,28A99.38,99.38,0,0,0,57.24,57.34c-4.69,4.74-9,9.37-13.24,14V64a12,12,0,0,0-24,0v40a12,12,0,0,0,12,12H72a12,12,0,0,0,0-24H57.77C63,86,68.37,80.22,74.26,74.26a76,76,0,1,1,1.58,109,12,12,0,0,0-16.48,17.46A100,100,0,1,0,128,28Z'/%3E%3C/svg%3E")}
.fa-info::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M108,84a16,16,0,1,1,16,16A16,16,0,0,1,108,84Zm128,44A108,108,0,1,1,128,20,108.12,108.12,0,0,1,236,128Zm-24,0a84,84,0,1,0-84,84A84.09,84.09,0,0,0,212,128Zm-72,36.68V132a20,20,0,0,0-20-20,12,12,0,0,0-4,23.32V168a20,20,0,0,0,20,20,12,12,0,0,0,4-23.32Z'/%3E%3C/svg%3E")}
.fa-key::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M232,98.36C230.73,136.92,198.67,168,160.09,168a71.68,71.68,0,0,1-26.92-5.17h0L120,176H96v24H72v24H40a8,8,0,0,1-8-8V187.31a8,8,0,0,1,2.34-5.65l58.83-58.83h0A71.68,71.68,0,0,1,88,95.91c0-38.58,31.08-70.64,69.64-71.87A72,72,0,0,1,232,98.36Z' opacity='0.4'/%3E%3Cpath d='M196,76a16,16,0,1,1-16-16A16,16,0,0,1,196,76Zm48,22.74A84.3,84.3,0,0,1,160.11,180H160a83.52,83.52,0,0,1-23.65-3.38l-7.86,7.87A12,12,0,0,1,120,188H108v12a12,12,0,0,1-12,12H84v12a12,12,0,0,1-12,12H40a20,20,0,0,1-20-20V187.31a19.86,19.86,0,0,1,5.86-14.14l53.52-53.52A84,84,0,1,1,244,98.74ZM202.43,53.57A59.48,59.48,0,0,0,158,36c-32,1-58,27.89-58,59.89a59.69,59.69,0,0,0,4.2,22.19,12,12,0,0,1-2.55,13.21L44,189v23H60V200a12,12,0,0,1,12-12H84V176a12,12,0,0,1,12-12h19l9.65-9.65a12,12,0,0,1,13.22-2.55A59.58,59.58,0,0,0,160,156h.08c32,0,58.87-26.07,59.89-58A59.55,59.55,0,0,0,202.43,53.57Z'/%3E%3C/svg%3E")}
.fa-list::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M84,64A12,12,0,0,1,96,52H216a12,12,0,0,1,0,24H96A12,12,0,0,1,84,64Zm132,52H96a12,12,0,0,0,0,24H216a12,12,0,0,0,0-24Zm0,64H96a12,12,0,0,0,0,24H216a12,12,0,0,0,0-24ZM56,52H40a12,12,0,0,0,0,24H56a12,12,0,0,0,0-24Zm0,64H40a12,12,0,0,0,0,24H56a12,12,0,0,0,0-24Zm0,64H40a12,12,0,0,0,0,24H56a12,12,0,0,0,0-24Z'/%3E%3C/svg%3E")}
.fa-list-alt::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M76,64A12,12,0,0,1,88,52H216a12,12,0,0,1,0,24H88A12,12,0,0,1,76,64Zm140,52H88a12,12,0,0,0,0,24H216a12,12,0,0,0,0-24Zm0,64H88a12,12,0,0,0,0,24H216a12,12,0,0,0,0-24ZM44,112a16,16,0,1,0,16,16A16,16,0,0,0,44,112Zm0-64A16,16,0,1,0,60,64,16,16,0,0,0,44,48Zm0,128a16,16,0,1,0,16,16A16,16,0,0,0,44,176Z'/%3E%3C/svg%3E")}
.fa-list-ol::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M228,128a12,12,0,0,1-12,12H116a12,12,0,0,1,0-24H216A12,12,0,0,1,228,128ZM116,76H216a12,12,0,0,0,0-24H116a12,12,0,0,0,0,24ZM216,180H116a12,12,0,0,0,0,24H216a12,12,0,0,0,0-24ZM44,59.31V104a12,12,0,0,0,24,0V40A12,12,0,0,0,50.64,29.27l-16,8a12,12,0,0,0,9.36,22Zm39.73,96.86a27.7,27.7,0,0,0-11.2-18.63A28.89,28.89,0,0,0,32.9,143a27.71,27.71,0,0,0-4.17,7.54,12,12,0,0,0,22.55,8.21,4,4,0,0,1,.58-1,4.78,4.78,0,0,1,6.5-.82,3.82,3.82,0,0,1,1.61,2.6,3.63,3.63,0,0,1-.77,2.77l-.13.17L30.39,200.82A12,12,0,0,0,40,220H72a12,12,0,0,0,0-24H64l14.28-19.11A27.48,27.48,0,0,0,83.73,156.17Z'/%3E%3C/svg%3E")}
.fa-lock::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M216,96V208a8,8,0,0,1-8,8H48a8,8,0,0,1-8-8V96a8,8,0,0,1,8-8H208A8,8,0,0,1,216,96Z' opacity='0.4'/%3E%3Cpath d='M208,76H180V56A52,52,0,0,0,76,56V76H48A20,20,0,0,0,28,96V208a20,20,0,0,0,20,20H208a20,20,0,0,0,20-20V96A20,20,0,0,0,208,76ZM100,56a28,28,0,0,1,56,0V76H100ZM204,204H52V100H204Z'/%3E%3C/svg%3E")}
.fa-male::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M192,96a64,64,0,1,1-64-64A64,64,0,0,1,192,96Z' opacity='0.4'/%3E%3Cpath d='M234.38,210a123.36,123.36,0,0,0-60.78-53.23,76,76,0,1,0-91.2,0A123.36,123.36,0,0,0,21.62,210a12,12,0,1,0,20.77,12c18.12-31.32,50.12-50,85.61-50s67.49,18.69,85.61,50a12,12,0,0,0,20.77-12ZM76,96a52,52,0,1,1,52,52A52.06,52.06,0,0,1,76,96Z'/%3E%3C/svg%3E")}
.fa-map::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M160,72V216L96,184V40Z' opacity='0.4'/%3E%3Cpath d='M231.38,46.54a12,12,0,0,0-10.29-2.18L161.4,59.28l-60-30a12,12,0,0,0-8.28-.91l-64,16A12,12,0,0,0,20,56V200a12,12,0,0,0,14.91,11.64L94.6,196.72l60,30a12,12,0,0,0,8.28.91l64-16A12,12,0,0,0,236,200V56A12,12,0,0,0,231.38,46.54ZM108,59.42l40,20V196.58l-40-20Zm-64,6,40-10V174.63l-40,10ZM212,190.63l-40,10V81.37l40-10Z'/%3E%3C/svg%3E")}
.fa-map-signs::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M200,164a36.07,36.07,0,0,0-33.94,24H72a28,28,0,0,1,0-56h96a44,44,0,0,0,0-88H72a12,12,0,0,0,0,24h96a20,20,0,0,1,0,40H72a52,52,0,0,0,0,104h94.06A36,36,0,1,0,200,164Zm0,48a12,12,0,1,1,12-12A12,12,0,0,1,200,212Z'/%3E%3C/svg%3E")}
.fa-microchip::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M200,48H56a8,8,0,0,0-8,8V200a8,8,0,0,0,8,8H200a8,8,0,0,0,8-8V56A8,8,0,0,0,200,48ZM152,152H104V104h48Z' opacity='0.4'/%3E%3Cpath d='M156,88H100a12,12,0,0,0-12,12v56a12,12,0,0,0,12,12h56a12,12,0,0,0,12-12V100A12,12,0,0,0,156,88Zm-12,56H112V112h32Zm88-4H220V116h12a12,12,0,0,0,0-24H220V56a20,20,0,0,0-20-20H164V24a12,12,0,0,0-24,0V36H116V24a12,12,0,0,0-24,0V36H56A20,20,0,0,0,36,56V92H24a12,12,0,0,0,0,24H36v24H24a12,12,0,0,0,0,24H36v36a20,20,0,0,0,20,20H92v12a12,12,0,0,0,24,0V220h24v12a12,12,0,0,0,24,0V220h36a20,20,0,0,0,20-20V164h12a12,12,0,0,0,0-24Zm-36,56H60V60H196Z'/%3E%3C/svg%3E")}
.fa-minus-square::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M216,48V208a8,8,0,0,1-8,8H48a8,8,0,0,1-8-8V48a8,8,0,0,1,8-8H208A8,8,0,0,1,216,48Z' opacity='0.4'/%3E%3Cpath d='M208,28H48A20,20,0,0,0,28,48V208a20,20,0,0,0,20,20H208a20,20,0,0,0,20-20V48A20,20,0,0,0,208,28Zm-4,176H52V52H204ZM76,128a12,12,0,0,1,12-12h80a12,12,0,0,1,0,24H88A12,12,0,0,1,76,128Z'/%3E%3C/svg%3E")}
.fa-network-wired::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M152,40V72a8,8,0,0,1-8,8H112a8,8,0,0,1-8-8V40a8,8,0,0,1,8-8h32A8,8,0,0,1,152,40ZM80,168H48a8,8,0,0,0-8,8v32a8,8,0,0,0,8,8H80a8,8,0,0,0,8-8V176A8,8,0,0,0,80,168Zm128,0H176a8,8,0,0,0-8,8v32a8,8,0,0,0,8,8h32a8,8,0,0,0,8-8V176A8,8,0,0,0,208,168Z' opacity='0.4'/%3E%3Cpath d='M232,108H140V92h4a20,20,0,0,0,20-20V40a20,20,0,0,0-20-20H112A20,20,0,0,0,92,40V72a20,20,0,0,0,20,20h4v16H24a12,12,0,0,0,0,24H52v24H48a20,20,0,0,0-20,20v32a20,20,0,0,0,20,20H80a20,20,0,0,0,20-20V176a20,20,0,0,0-20-20H76V132H180v24h-4a20,20,0,0,0-20,20v32a20,20,0,0,0,20,20h32a20,20,0,0,0,20-20V176a20,20,0,0,0-20-20h-4V132h28a12,12,0,0,0,0-24ZM116,44h24V68H116ZM76,204H52V180H76Zm128,0H180V180h24Z'/%3E%3C/svg%3E")}
.fa-pencil::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M221.66,90.34,192,120,136,64l29.66-29.66a8,8,0,0,1,11.31,0L221.66,79A8,8,0,0,1,221.66,90.34Z' opacity='0.4'/%3E%3Cpath d='M230.14,70.54,185.46,25.85a20,20,0,0,0-28.29,0L33.86,149.17A19.85,19.85,0,0,0,28,163.31V208a20,20,0,0,0,20,20H92.69a19.86,19.86,0,0,0,14.14-5.86L230.14,98.82a20,20,0,0,0,0-28.28ZM91,204H52V165l84-84,39,39ZM192,103,153,64l18.34-18.34,39,39Z'/%3E%3C/svg%3E")}
.fa-pencil-square-o::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M221.66,90.34,192,120,136,64l29.66-29.66a8,8,0,0,1,11.31,0L221.66,79A8,8,0,0,1,221.66,90.34Z' opacity='0.4'/%3E%3Cpath d='M230.15,70.54,185.46,25.86a20,20,0,0,0-28.28,0L33.86,149.17A19.86,19.86,0,0,0,28,163.31V208a20,20,0,0,0,20,20H216a12,12,0,0,0,0-24H125L230.15,98.83A20,20,0,0,0,230.15,70.54ZM91,204H52V165l84-84,39,39ZM192,103,153,64l18.34-18.34,39,39Z'/%3E%3C/svg%3E")}
.fa-play::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M228.23,134.69,84.15,222.81A8,8,0,0,1,72,216.12V39.88a8,8,0,0,1,12.15-6.69l144.08,88.12A7.82,7.82,0,0,1,228.23,134.69Z' opacity='0.4'/%3E%3Cpath d='M234.49,111.07,90.41,22.94A20,20,0,0,0,60,39.87V216.13a20,20,0,0,0,30.41,16.93l144.08-88.13a19.82,19.82,0,0,0,0-33.86ZM84,208.85V47.15L216.16,128Z'/%3E%3C/svg%3E")}
.fa-plus::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M228,128a12,12,0,0,1-12,12H140v76a12,12,0,0,1-24,0V140H40a12,12,0,0,1,0-24h76V40a12,12,0,0,1,24,0v76h76A12,12,0,0,1,228,128Z'/%3E%3C/svg%3E")}
.fa-power-off::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M116,128V48a12,12,0,0,1,24,0v80a12,12,0,0,1-24,0Zm66.55-82a12,12,0,0,0-13.1,20.1C191.41,80.37,204,103,204,128a76,76,0,0,1-152,0c0-25,12.59-47.63,34.55-61.95A12,12,0,0,0,73.45,46C44.56,64.78,28,94.69,28,128a100,100,0,0,0,200,0C228,94.69,211.44,64.78,182.55,46Z'/%3E%3C/svg%3E")}
.fa-question-circle::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M144,180a16,16,0,1,1-16-16A16,16,0,0,1,144,180Zm92-52A108,108,0,1,1,128,20,108.12,108.12,0,0,1,236,128Zm-24,0a84,84,0,1,0-84,84A84.09,84.09,0,0,0,212,128ZM128,64c-24.26,0-44,17.94-44,40v4a12,12,0,0,0,24,0v-4c0-8.82,9-16,20-16s20,7.18,20,16-9,16-20,16a12,12,0,0,0-12,12v8a12,12,0,0,0,23.73,2.56C158.31,137.88,172,122.37,172,104,172,81.94,152.26,64,128,64Z'/%3E%3C/svg%3E")}
.fa-refresh::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M228,48V96a12,12,0,0,1-12,12H168a12,12,0,0,1,0-24h19l-7.8-7.8a75.55,75.55,0,0,0-53.32-22.26h-.43A75.49,75.49,0,0,0,72.39,75.57,12,12,0,1,1,55.61,58.41a99.38,99.38,0,0,1,69.87-28.47H126A99.42,99.42,0,0,1,196.2,59.23L204,67V48a12,12,0,0,1,24,0ZM183.61,180.43a75.49,75.49,0,0,1-53.09,21.63h-.43A75.55,75.55,0,0,1,76.77,179.8L69,172H88a12,12,0,0,0,0-24H40a12,12,0,0,0-12,12v48a12,12,0,0,0,24,0V189l7.8,7.8A99.42,99.42,0,0,0,130,226.06h.56a99.38,99.38,0,0,0,69.87-28.47,12,12,0,0,0-16.78-17.16Z'/%3E%3C/svg%3E")}
.fa-retweet::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M20,128A76.08,76.08,0,0,1,96,52h99l-3.52-3.51a12,12,0,1,1,17-17l24,24a12,12,0,0,1,0,17l-24,24a12,12,0,0,1-17-17L195,76H96a52.06,52.06,0,0,0-52,52,12,12,0,0,1-24,0Zm204-12a12,12,0,0,0-12,12,52.06,52.06,0,0,1-52,52H61l3.52-3.51a12,12,0,1,0-17-17l-24,24a12,12,0,0,0,0,17l24,24a12,12,0,1,0,17-17L61,204h99a76.08,76.08,0,0,0,76-76A12,12,0,0,0,224,116Z'/%3E%3C/svg%3E")}
.fa-road::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M200,164a36.07,36.07,0,0,0-33.94,24H72a28,28,0,0,1,0-56h96a44,44,0,0,0,0-88H72a12,12,0,0,0,0,24h96a20,20,0,0,1,0,40H72a52,52,0,0,0,0,104h94.06A36,36,0,1,0,200,164Zm0,48a12,12,0,1,1,12-12A12,12,0,0,1,200,212Z'/%3E%3C/svg%3E")}
.fa-search::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M192,112a80,80,0,1,1-80-80A80,80,0,0,1,192,112Z' opacity='0.4'/%3E%3Cpath d='M232.49,215.51,185,168a92.12,92.12,0,1,0-17,17l47.53,47.54a12,12,0,0,0,17-17ZM44,112a68,68,0,1,1,68,68A68.07,68.07,0,0,1,44,112Z'/%3E%3C/svg%3E")}
.fa-send-o::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M223.69,42.18l-58.22,192a8,8,0,0,1-14.92,1.25L108,148,20.58,105.45a8,8,0,0,1,1.25-14.92l192-58.22A8,8,0,0,1,223.69,42.18Z' opacity='0.4'/%3E%3Cpath d='M230.14,25.86a20,20,0,0,0-19.57-5.11l-.22.07L18.44,79a20,20,0,0,0-3.06,37.25L99,157l40.71,83.65a19.81,19.81,0,0,0,18,11.38c.57,0,1.15,0,1.73-.07A19.82,19.82,0,0,0,177,237.56L235.18,45.65a1.42,1.42,0,0,0,.07-.22A20,20,0,0,0,230.14,25.86ZM156.91,221.07l-34.37-70.64,46-45.95a12,12,0,0,0-17-17l-46,46L34.93,99.09,210,46Z'/%3E%3C/svg%3E")}
.fa-server::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M136,32V216H40V85.35a8,8,0,0,1,3.56-6.66l80-53.33A8,8,0,0,1,136,32Z' opacity='0.4'/%3E%3Cpath d='M240,204H228V96a20,20,0,0,0-20-20H172V32a20,20,0,0,0-28.45-18.12l-104,48.54A20.06,20.06,0,0,0,28,80.55V204H16a12,12,0,0,0,0,24H240a12,12,0,0,0,0-24ZM204,100V204H172V100ZM52,83.09,148,38.3V204H52ZM132,112v12a12,12,0,0,1-24,0V112a12,12,0,0,1,24,0Zm-40,0v12a12,12,0,0,1-24,0V112a12,12,0,0,1,24,0Zm0,52v12a12,12,0,0,1-24,0V164a12,12,0,0,1,24,0Zm40,0v12a12,12,0,0,1-24,0V164a12,12,0,0,1,24,0Z'/%3E%3C/svg%3E")}
.fa-shield::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M216,56v56c0,96-88,120-88,120S40,208,40,112V56a8,8,0,0,1,8-8H208A8,8,0,0,1,216,56Z' opacity='0.4'/%3E%3Cpath d='M208,36H48A20,20,0,0,0,28,56v56c0,54.29,26.32,87.22,48.4,105.29,23.71,19.39,47.44,26,48.44,26.29a12.1,12.1,0,0,0,6.32,0c1-.28,24.73-6.9,48.44-26.29,22.08-18.07,48.4-51,48.4-105.29V56A20,20,0,0,0,208,36Zm-4,76c0,35.71-13.09,64.69-38.91,86.15A126.28,126.28,0,0,1,128,219.38a126.14,126.14,0,0,1-37.09-21.23C65.09,176.69,52,147.71,52,112V60H204Z'/%3E%3C/svg%3E")}
.fa-sitemap::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M64,112v32a8,8,0,0,1-8,8H24a8,8,0,0,1-8-8V112a8,8,0,0,1,8-8H56A8,8,0,0,1,64,112ZM208,40H160a8,8,0,0,0-8,8V96a8,8,0,0,0,8,8h48a8,8,0,0,0,8-8V48A8,8,0,0,0,208,40Zm0,112H160a8,8,0,0,0-8,8v48a8,8,0,0,0,8,8h48a8,8,0,0,0,8-8V160A8,8,0,0,0,208,152Z' opacity='0.4'/%3E%3Cpath d='M160,116h48a20,20,0,0,0,20-20V48a20,20,0,0,0-20-20H160a20,20,0,0,0-20,20V60H128a28,28,0,0,0-28,28v28H76v-4A20,20,0,0,0,56,92H24A20,20,0,0,0,4,112v32a20,20,0,0,0,20,20H56a20,20,0,0,0,20-20v-4h24v28a28,28,0,0,0,28,28h12v12a20,20,0,0,0,20,20h48a20,20,0,0,0,20-20V160a20,20,0,0,0-20-20H160a20,20,0,0,0-20,20v12H128a4,4,0,0,1-4-4V88a4,4,0,0,1,4-4h12V96A20,20,0,0,0,160,116ZM52,140H28V116H52Zm112,24h40v40H164Zm0-112h40V92H164Z'/%3E%3C/svg%3E")}
.fa-square::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M216,48V208a8,8,0,0,1-8,8H48a8,8,0,0,1-8-8V48a8,8,0,0,1,8-8H208A8,8,0,0,1,216,48Z' opacity='0.4'/%3E%3Cpath d='M208,28H48A20,20,0,0,0,28,48V208a20,20,0,0,0,20,20H208a20,20,0,0,0,20-20V48A20,20,0,0,0,208,28Zm-4,176H52V52H204Z'/%3E%3C/svg%3E")}
.fa-square-o::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M208,56V200a8,8,0,0,1-8,8H128V48h72A8,8,0,0,1,208,56Z' opacity='0.4'/%3E%3Cpath d='M200,36H56A20,20,0,0,0,36,56V200a20,20,0,0,0,20,20H200a20,20,0,0,0,20-20V56A20,20,0,0,0,200,36Zm-60,64h56v16H140Zm0,40h56v16H140Zm56-64H140V60h56ZM60,60h56V196H60Zm80,136V180h56v16Z'/%3E%3C/svg%3E")}
.fa-sticky-note-o::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M216,160l-56,56V160Z' opacity='0.4'/%3E%3Cpath d='M84,108A12,12,0,0,1,96,96h64a12,12,0,0,1,0,24H96A12,12,0,0,1,84,108Zm32,28H96a12,12,0,0,0,0,24h20a12,12,0,0,0,0-24ZM228,48V156.69a19.86,19.86,0,0,1-5.86,14.14l-51.31,51.31A19.86,19.86,0,0,1,156.69,228H48a20,20,0,0,1-20-20V48A20,20,0,0,1,48,28H208A20,20,0,0,1,228,48ZM52,204h92V156a12,12,0,0,1,12-12h48V52H52Zm139-36H168v23Z'/%3E%3C/svg%3E")}
.fa-support::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M195.88,195.88l-39.6-39.6a40,40,0,0,0,0-56.56l39.6-39.6A96,96,0,0,1,195.88,195.88ZM60.12,60.12a96,96,0,0,0,0,135.76l39.6-39.6a40,40,0,0,1,0-56.56Z' opacity='0.4'/%3E%3Cpath d='M128,20A108,108,0,1,0,236,128,108.12,108.12,0,0,0,128,20Zm44.25,135.28a51.89,51.89,0,0,0,0-54.56l23-23a83.84,83.84,0,0,1,0,100.56ZM100,128a28,28,0,1,1,28,28A28,28,0,0,1,100,128Zm78.28-67.25-23,23a51.89,51.89,0,0,0-54.56,0l-23-23a83.84,83.84,0,0,1,100.56,0Zm-117.53,17,23,23a51.89,51.89,0,0,0,0,54.56l-23,23a83.84,83.84,0,0,1,0-100.56Zm17,117.53,23-23a51.89,51.89,0,0,0,54.56,0l23,23a83.84,83.84,0,0,1-100.56,0Z'/%3E%3C/svg%3E")}
.fa-tags::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M237.66,153,153,237.66a8,8,0,0,1-11.31,0L42.34,138.34A8,8,0,0,1,40,132.69V40h92.69a8,8,0,0,1,5.65,2.34l99.32,99.32A8,8,0,0,1,237.66,153Z' opacity='0.4'/%3E%3Cpath d='M246.15,133.18,146.83,33.86A19.85,19.85,0,0,0,132.69,28H40A12,12,0,0,0,28,40v92.69a19.85,19.85,0,0,0,5.86,14.14l99.32,99.32a20,20,0,0,0,28.28,0l84.69-84.69A20,20,0,0,0,246.15,133.18Zm-98.83,93.17L52,131V52h79l95.32,95.32ZM104,88A16,16,0,1,1,88,72,16,16,0,0,1,104,88Z'/%3E%3C/svg%3E")}
.fa-tasks::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M228,128a12,12,0,0,1-12,12H128a12,12,0,0,1,0-24h88A12,12,0,0,1,228,128ZM128,76h88a12,12,0,0,0,0-24H128a12,12,0,0,0,0,24Zm88,104H128a12,12,0,0,0,0,24h88a12,12,0,0,0,0-24ZM79.51,39.51,56,63l-7.51-7.52a12,12,0,0,0-17,17l16,16a12,12,0,0,0,17,0l32-32a12,12,0,0,0-17-17Zm0,64L56,127l-7.51-7.52a12,12,0,1,0-17,17l16,16a12,12,0,0,0,17,0l32-32a12,12,0,0,0-17-17Zm0,64L56,191l-7.51-7.52a12,12,0,1,0-17,17l16,16a12,12,0,0,0,17,0l32-32a12,12,0,0,0-17-17Z'/%3E%3C/svg%3E")}
.fa-terminal::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M224,56V200a8,8,0,0,1-8,8H40a8,8,0,0,1-8-8V56a8,8,0,0,1,8-8H216A8,8,0,0,1,224,56Z' opacity='0.4'/%3E%3Cpath d='M72.5,150.63,100.79,128,72.5,105.37a12,12,0,1,1,15-18.74l40,32a12,12,0,0,1,0,18.74l-40,32a12,12,0,0,1-15-18.74ZM144,172h32a12,12,0,0,0,0-24H144a12,12,0,0,0,0,24ZM236,56V200a20,20,0,0,1-20,20H40a20,20,0,0,1-20-20V56A20,20,0,0,1,40,36H216A20,20,0,0,1,236,56Zm-24,4H44V196H212Z'/%3E%3C/svg%3E")}
.fa-th::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M152,40V72a8,8,0,0,1-8,8H112a8,8,0,0,1-8-8V40a8,8,0,0,1,8-8h32A8,8,0,0,1,152,40ZM80,168H48a8,8,0,0,0-8,8v32a8,8,0,0,0,8,8H80a8,8,0,0,0,8-8V176A8,8,0,0,0,80,168Zm128,0H176a8,8,0,0,0-8,8v32a8,8,0,0,0,8,8h32a8,8,0,0,0,8-8V176A8,8,0,0,0,208,168Z' opacity='0.4'/%3E%3Cpath d='M232,108H140V92h4a20,20,0,0,0,20-20V40a20,20,0,0,0-20-20H112A20,20,0,0,0,92,40V72a20,20,0,0,0,20,20h4v16H24a12,12,0,0,0,0,24H52v24H48a20,20,0,0,0-20,20v32a20,20,0,0,0,20,20H80a20,20,0,0,0,20-20V176a20,20,0,0,0-20-20H76V132H180v24h-4a20,20,0,0,0-20,20v32a20,20,0,0,0,20,20h32a20,20,0,0,0,20-20V176a20,20,0,0,0-20-20h-4V132h28a12,12,0,0,0,0-24ZM116,44h24V68H116ZM76,204H52V180H76Zm128,0H180V180h24Z'/%3E%3C/svg%3E")}
.fa-th-large::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M112,56v48a8,8,0,0,1-8,8H56a8,8,0,0,1-8-8V56a8,8,0,0,1,8-8h48A8,8,0,0,1,112,56Zm88-8H152a8,8,0,0,0-8,8v48a8,8,0,0,0,8,8h48a8,8,0,0,0,8-8V56A8,8,0,0,0,200,48Zm-96,96H56a8,8,0,0,0-8,8v48a8,8,0,0,0,8,8h48a8,8,0,0,0,8-8V152A8,8,0,0,0,104,144Zm96,0H152a8,8,0,0,0-8,8v48a8,8,0,0,0,8,8h48a8,8,0,0,0,8-8V152A8,8,0,0,0,200,144Z' opacity='0.4'/%3E%3Cpath d='M100,36H56A20,20,0,0,0,36,56v44a20,20,0,0,0,20,20h44a20,20,0,0,0,20-20V56A20,20,0,0,0,100,36ZM96,96H60V60H96ZM200,36H156a20,20,0,0,0-20,20v44a20,20,0,0,0,20,20h44a20,20,0,0,0,20-20V56A20,20,0,0,0,200,36Zm-4,60H160V60h36Zm-96,40H56a20,20,0,0,0-20,20v44a20,20,0,0,0,20,20h44a20,20,0,0,0,20-20V156A20,20,0,0,0,100,136Zm-4,60H60V160H96Zm104-60H156a20,20,0,0,0-20,20v44a20,20,0,0,0,20,20h44a20,20,0,0,0,20-20V156A20,20,0,0,0,200,136Zm-4,60H160V160h36Z'/%3E%3C/svg%3E")}
.fa-times::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M208.49,191.51a12,12,0,0,1-17,17L128,145,64.49,208.49a12,12,0,0,1-17-17L111,128,47.51,64.49a12,12,0,0,1,17-17L128,111l63.51-63.52a12,12,0,0,1,17,17L145,128Z'/%3E%3C/svg%3E")}
.fa-tv::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M224,64V176a16,16,0,0,1-16,16H48a16,16,0,0,1-16-16V64A16,16,0,0,1,48,48H208A16,16,0,0,1,224,64Z' opacity='0.4'/%3E%3Cpath d='M208,36H48A28,28,0,0,0,20,64V176a28,28,0,0,0,28,28H208a28,28,0,0,0,28-28V64A28,28,0,0,0,208,36Zm4,140a4,4,0,0,1-4,4H48a4,4,0,0,1-4-4V64a4,4,0,0,1,4-4H208a4,4,0,0,1,4,4Zm-40,52a12,12,0,0,1-12,12H96a12,12,0,0,1,0-24h64A12,12,0,0,1,172,228Z'/%3E%3C/svg%3E")}
.fa-undo::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M244,56v48a12,12,0,0,1-12,12H184a12,12,0,1,1,0-24H201.1l-19-17.38c-.13-.12-.26-.24-.38-.37A76,76,0,1,0,127,204h1a75.53,75.53,0,0,0,52.15-20.72,12,12,0,0,1,16.49,17.45A99.45,99.45,0,0,1,128,228h-1.37A100,100,0,1,1,198.51,57.06L220,76.72V56a12,12,0,0,1,24,0Z'/%3E%3C/svg%3E")}
.fa-unlock::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M216,96V208a8,8,0,0,1-8,8H48a8,8,0,0,1-8-8V96a8,8,0,0,1,8-8H208A8,8,0,0,1,216,96Z' opacity='0.4'/%3E%3Cpath d='M208,76H100V56a28,28,0,0,1,28-28c13.51,0,25.65,9.62,28.24,22.39a12,12,0,1,0,23.52-4.78C174.87,21.5,153.1,4,128,4A52.06,52.06,0,0,0,76,56V76H48A20,20,0,0,0,28,96V208a20,20,0,0,0,20,20H208a20,20,0,0,0,20-20V96A20,20,0,0,0,208,76Zm-4,128H52V100H204Z'/%3E%3C/svg%3E")}
.fa-user::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M192,96a64,64,0,1,1-64-64A64,64,0,0,1,192,96Z' opacity='0.4'/%3E%3Cpath d='M234.38,210a123.36,123.36,0,0,0-60.78-53.23,76,76,0,1,0-91.2,0A123.36,123.36,0,0,0,21.62,210a12,12,0,1,0,20.77,12c18.12-31.32,50.12-50,85.61-50s67.49,18.69,85.61,50a12,12,0,0,0,20.77-12ZM76,96a52,52,0,1,1,52,52A52.06,52.06,0,0,1,76,96Z'/%3E%3C/svg%3E")}
.fa-user-o::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M192,96a64,64,0,1,1-64-64A64,64,0,0,1,192,96Z' opacity='0.4'/%3E%3Cpath d='M234.38,210a123.36,123.36,0,0,0-60.78-53.23,76,76,0,1,0-91.2,0A123.36,123.36,0,0,0,21.62,210a12,12,0,1,0,20.77,12c18.12-31.32,50.12-50,85.61-50s67.49,18.69,85.61,50a12,12,0,0,0,20.77-12ZM76,96a52,52,0,1,1,52,52A52.06,52.06,0,0,1,76,96Z'/%3E%3C/svg%3E")}
.fa-users::before{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M136,108A52,52,0,1,1,84,56,52,52,0,0,1,136,108Z' opacity='0.4'/%3E%3Cpath d='M125.18,156.94a64,64,0,1,0-82.36,0,100.23,100.23,0,0,0-39.49,32,12,12,0,0,0,19.35,14.2,76,76,0,0,1,122.64,0,12,12,0,0,0,19.36-14.2A100.33,100.33,0,0,0,125.18,156.94ZM44,108a40,40,0,1,1,40,40A40,40,0,0,1,44,108Zm206.1,97.67a12,12,0,0,1-16.78-2.57A76.31,76.31,0,0,0,172,172a12,12,0,0,1,0-24,40,40,0,1,0-10.3-78.67,12,12,0,1,1-6.16-23.19,64,64,0,0,1,57.64,110.8,100.23,100.23,0,0,1,39.49,32A12,12,0,0,1,250.1,205.67Z'/%3E%3C/svg%3E")}
.x-tool .x-tool-img.x-tool-tool-el{background-image:none;background-color:currentColor;filter:none;-webkit-mask:var(--modern-icon) center/contain no-repeat;mask:var(--modern-icon) center/contain no-repeat}
.x-tool-img.x-tool-close{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M208.49,191.51a12,12,0,0,1-17,17L128,145,64.49,208.49a12,12,0,0,1-17-17L111,128,47.51,64.49a12,12,0,0,1,17-17L128,111l63.51-63.52a12,12,0,0,1,17,17L145,128Z'/%3E%3C/svg%3E")}
.x-tool-img.x-tool-collapse{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M216.49,168.49a12,12,0,0,1-17,0L128,97,56.49,168.49a12,12,0,0,1-17-17l80-80a12,12,0,0,1,17,0l80,80A12,12,0,0,1,216.49,168.49Z'/%3E%3C/svg%3E")}
.x-tool-img.x-tool-collapse-bottom{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M216.49,104.49l-80,80a12,12,0,0,1-17,0l-80-80a12,12,0,0,1,17-17L128,159l71.51-71.52a12,12,0,0,1,17,17Z'/%3E%3C/svg%3E")}
.x-tool-img.x-tool-collapse-left{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M168.49,199.51a12,12,0,0,1-17,17l-80-80a12,12,0,0,1,0-17l80-80a12,12,0,0,1,17,17L97,128Z'/%3E%3C/svg%3E")}
.x-tool-img.x-tool-collapse-right{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M184.49,136.49l-80,80a12,12,0,0,1-17-17L159,128,87.51,56.49a12,12,0,1,1,17-17l80,80A12,12,0,0,1,184.49,136.49Z'/%3E%3C/svg%3E")}
.x-tool-img.x-tool-collapse-top{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M216.49,168.49a12,12,0,0,1-17,0L128,97,56.49,168.49a12,12,0,0,1-17-17l80-80a12,12,0,0,1,17,0l80,80A12,12,0,0,1,216.49,168.49Z'/%3E%3C/svg%3E")}
.x-tool-img.x-tool-down{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M216.49,104.49l-80,80a12,12,0,0,1-17,0l-80-80a12,12,0,0,1,17-17L128,159l71.51-71.52a12,12,0,0,1,17,17Z'/%3E%3C/svg%3E")}
.x-tool-img.x-tool-expand{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M216.49,104.49l-80,80a12,12,0,0,1-17,0l-80-80a12,12,0,0,1,17-17L128,159l71.51-71.52a12,12,0,0,1,17,17Z'/%3E%3C/svg%3E")}
.x-tool-img.x-tool-expand-bottom{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M216.49,104.49l-80,80a12,12,0,0,1-17,0l-80-80a12,12,0,0,1,17-17L128,159l71.51-71.52a12,12,0,0,1,17,17Z'/%3E%3C/svg%3E")}
.x-tool-img.x-tool-expand-left{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M168.49,199.51a12,12,0,0,1-17,17l-80-80a12,12,0,0,1,0-17l80-80a12,12,0,0,1,17,17L97,128Z'/%3E%3C/svg%3E")}
.x-tool-img.x-tool-expand-right{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M184.49,136.49l-80,80a12,12,0,0,1-17-17L159,128,87.51,56.49a12,12,0,1,1,17-17l80,80A12,12,0,0,1,184.49,136.49Z'/%3E%3C/svg%3E")}
.x-tool-img.x-tool-expand-top{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M216.49,168.49a12,12,0,0,1-17,0L128,97,56.49,168.49a12,12,0,0,1-17-17l80-80a12,12,0,0,1,17,0l80,80A12,12,0,0,1,216.49,168.49Z'/%3E%3C/svg%3E")}
.x-tool-img.x-tool-gear{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M230.1,108.76,198.25,90.62c-.64-1.16-1.31-2.29-2-3.41l-.12-36A104.61,104.61,0,0,0,162,32L130,49.89c-1.34,0-2.69,0-4,0L94,32A104.58,104.58,0,0,0,59.89,51.25l-.16,36c-.7,1.12-1.37,2.26-2,3.41l-31.84,18.1a99.15,99.15,0,0,0,0,38.46l31.85,18.14c.64,1.16,1.31,2.29,2,3.41l.12,36A104.61,104.61,0,0,0,94,224l32-17.87c1.34,0,2.69,0,4,0L162,224a104.58,104.58,0,0,0,34.08-19.25l.16-36c.7-1.12,1.37-2.26,2-3.41l31.84-18.1A99.15,99.15,0,0,0,230.1,108.76ZM128,168a40,40,0,1,1,40-40A40,40,0,0,1,128,168Z' opacity='0.4'/%3E%3Cpath d='M128,76a52,52,0,1,0,52,52A52.06,52.06,0,0,0,128,76Zm0,80a28,28,0,1,1,28-28A28,28,0,0,1,128,156Zm113.86-49.57A12,12,0,0,0,236,98.34L208.21,82.49l-.11-31.31a12,12,0,0,0-4.25-9.12,116,116,0,0,0-38-21.41,12,12,0,0,0-9.68.89L128,37.27,99.83,21.53a12,12,0,0,0-9.7-.9,116.06,116.06,0,0,0-38,21.47,12,12,0,0,0-4.24,9.1l-.14,31.34L20,98.35a12,12,0,0,0-5.85,8.11,110.7,110.7,0,0,0,0,43.11A12,12,0,0,0,20,157.66l27.82,15.85.11,31.31a12,12,0,0,0,4.25,9.12,116,116,0,0,0,38,21.41,12,12,0,0,0,9.68-.89L128,218.73l28.14,15.74a12,12,0,0,0,9.7.9,116.06,116.06,0,0,0,38-21.47,12,12,0,0,0,4.24-9.1l.14-31.34,27.81-15.81a12,12,0,0,0,5.85-8.11A110.7,110.7,0,0,0,241.86,106.43Zm-22.63,33.18-26.88,15.28a11.94,11.94,0,0,0-4.55,4.59c-.54,1-1.11,1.93-1.7,2.88a12,12,0,0,0-1.83,6.31L184.13,199a91.83,91.83,0,0,1-21.07,11.87l-27.15-15.19a12,12,0,0,0-5.86-1.53h-.29c-1.14,0-2.3,0-3.44,0a12.08,12.08,0,0,0-6.14,1.51L93,210.82A92.27,92.27,0,0,1,71.88,199l-.11-30.24a12,12,0,0,0-1.83-6.32c-.58-.94-1.16-1.91-1.7-2.88A11.92,11.92,0,0,0,63.7,155L36.8,139.63a86.53,86.53,0,0,1,0-23.24l26.88-15.28a12,12,0,0,0,4.55-4.58c.54-1,1.11-1.94,1.7-2.89a12,12,0,0,0,1.83-6.31L71.87,57A91.83,91.83,0,0,1,92.94,45.17l27.15,15.19a11.92,11.92,0,0,0,6.15,1.52c1.14,0,2.3,0,3.44,0a12.08,12.08,0,0,0,6.14-1.51L163,45.18A92.27,92.27,0,0,1,184.12,57l.11,30.24a12,12,0,0,0,1.83,6.32c.58.94,1.16,1.91,1.7,2.88A11.92,11.92,0,0,0,192.3,101l26.9,15.33A86.53,86.53,0,0,1,219.23,139.61Z'/%3E%3C/svg%3E")}
.x-tool-img.x-tool-help{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M144,180a16,16,0,1,1-16-16A16,16,0,0,1,144,180Zm92-52A108,108,0,1,1,128,20,108.12,108.12,0,0,1,236,128Zm-24,0a84,84,0,1,0-84,84A84.09,84.09,0,0,0,212,128ZM128,64c-24.26,0-44,17.94-44,40v4a12,12,0,0,0,24,0v-4c0-8.82,9-16,20-16s20,7.18,20,16-9,16-20,16a12,12,0,0,0-12,12v8a12,12,0,0,0,23.73,2.56C158.31,137.88,172,122.37,172,104,172,81.94,152.26,64,128,64Z'/%3E%3C/svg%3E")}
.x-tool-img.x-tool-left{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M168.49,199.51a12,12,0,0,1-17,17l-80-80a12,12,0,0,1,0-17l80-80a12,12,0,0,1,17,17L97,128Z'/%3E%3C/svg%3E")}
.x-tool-img.x-tool-maximize{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M220,48V88a12,12,0,0,1-24,0V60H168a12,12,0,0,1,0-24h40A12,12,0,0,1,220,48ZM88,196H60V168a12,12,0,0,0-24,0v40a12,12,0,0,0,12,12H88a12,12,0,0,0,0-24Zm120-40a12,12,0,0,0-12,12v28H168a12,12,0,0,0,0,24h40a12,12,0,0,0,12-12V168A12,12,0,0,0,208,156ZM88,36H48A12,12,0,0,0,36,48V88a12,12,0,0,0,24,0V60H88a12,12,0,0,0,0-24Z'/%3E%3C/svg%3E")}
.x-tool-img.x-tool-minimize{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M228,128a12,12,0,0,1-12,12H40a12,12,0,0,1,0-24H216A12,12,0,0,1,228,128Z'/%3E%3C/svg%3E")}
.x-tool-img.x-tool-minus{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M228,128a12,12,0,0,1-12,12H40a12,12,0,0,1,0-24H216A12,12,0,0,1,228,128Z'/%3E%3C/svg%3E")}
.x-tool-img.x-tool-move{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M87.51,64.49a12,12,0,0,1,0-17l32-32a12,12,0,0,1,17,0l32,32a12,12,0,0,1-17,17L140,53V96a12,12,0,0,1-24,0V53L104.49,64.49A12,12,0,0,1,87.51,64.49Zm64,127L140,203V160a12,12,0,0,0-24,0v43l-11.51-11.52a12,12,0,0,0-17,17l32,32a12,12,0,0,0,17,0l32-32a12,12,0,0,0-17-17Zm89-72-32-32a12,12,0,0,0-17,17L203,116H160a12,12,0,0,0,0,24h43l-11.52,11.51a12,12,0,0,0,17,17l32-32A12,12,0,0,0,240.49,119.51ZM53,140H96a12,12,0,0,0,0-24H53l11.52-11.51a12,12,0,1,0-17-17l-32,32a12,12,0,0,0,0,17l32,32a12,12,0,1,0,17-17Z'/%3E%3C/svg%3E")}
.x-tool-img.x-tool-next{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M184.49,136.49l-80,80a12,12,0,0,1-17-17L159,128,87.51,56.49a12,12,0,1,1,17-17l80,80A12,12,0,0,1,184.49,136.49Z'/%3E%3C/svg%3E")}
.x-tool-img.x-tool-pin{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M229.66,98.34,172.39,155.8c11.46,22.93-1.72,45.86-10.11,57a8,8,0,0,1-12,.83L42.34,105.76A8,8,0,0,1,43,93.85c29.65-23.92,57.4-10,57.4-10l57.27-57.46a8,8,0,0,1,11.31,0L229.66,87A8,8,0,0,1,229.66,98.34Z' opacity='0.4'/%3E%3Cpath d='M238.15,78.54,177.46,17.86a20,20,0,0,0-28.3,0L97.2,70c-12.43-3.33-36.68-5.72-61.74,14.5a20,20,0,0,0-1.6,29.73l45.46,45.47-39.8,39.8a12,12,0,0,0,17,17l39.8-39.81,45.47,45.46A20,20,0,0,0,155.91,228c.46,0,.93,0,1.4-.05A20,20,0,0,0,171.87,220c4.69-6.23,11-16.13,14.44-28s3.45-22.88.16-33.4l51.7-51.87A20,20,0,0,0,238.15,78.54Zm-74.26,68.79a12,12,0,0,0-2.23,13.84c3.43,6.86,6.9,21-6.28,40.65L54.08,100.53c21.09-14.59,39.53-6.64,41-6a11.67,11.67,0,0,0,13.81-2.29l54.43-54.61,55,55Z'/%3E%3C/svg%3E")}
.x-tool-img.x-tool-plus{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M228,128a12,12,0,0,1-12,12H140v76a12,12,0,0,1-24,0V140H40a12,12,0,0,1,0-24h76V40a12,12,0,0,1,24,0v76h76A12,12,0,0,1,228,128Z'/%3E%3C/svg%3E")}
.x-tool-img.x-tool-prev{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M168.49,199.51a12,12,0,0,1-17,17l-80-80a12,12,0,0,1,0-17l80-80a12,12,0,0,1,17,17L97,128Z'/%3E%3C/svg%3E")}
.x-tool-img.x-tool-print{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M232,96v80H192V152H64v24H24V96c0-8.84,7.76-16,17.33-16H214.67C224.24,80,232,87.16,232,96Z' opacity='0.4'/%3E%3Cpath d='M214.67,68H204V40a12,12,0,0,0-12-12H64A12,12,0,0,0,52,40V68H41.33C25.16,68,12,80.56,12,96v80a12,12,0,0,0,12,12H52v28a12,12,0,0,0,12,12H192a12,12,0,0,0,12-12V188h28a12,12,0,0,0,12-12V96C244,80.56,230.84,68,214.67,68ZM76,52H180V68H76ZM180,204H76V172H180Zm40-40H204v-4a12,12,0,0,0-12-12H64a12,12,0,0,0-12,12v4H36V96c0-2.17,2.44-4,5.33-4H214.67c2.89,0,5.33,1.83,5.33,4Zm-16-44a16,16,0,1,1-16-16A16,16,0,0,1,204,120Z'/%3E%3C/svg%3E")}
.x-tool-img.x-tool-refresh{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M228,48V96a12,12,0,0,1-12,12H168a12,12,0,0,1,0-24h19l-7.8-7.8a75.55,75.55,0,0,0-53.32-22.26h-.43A75.49,75.49,0,0,0,72.39,75.57,12,12,0,1,1,55.61,58.41a99.38,99.38,0,0,1,69.87-28.47H126A99.42,99.42,0,0,1,196.2,59.23L204,67V48a12,12,0,0,1,24,0ZM183.61,180.43a75.49,75.49,0,0,1-53.09,21.63h-.43A75.55,75.55,0,0,1,76.77,179.8L69,172H88a12,12,0,0,0,0-24H40a12,12,0,0,0-12,12v48a12,12,0,0,0,24,0V189l7.8,7.8A99.42,99.42,0,0,0,130,226.06h.56a99.38,99.38,0,0,0,69.87-28.47,12,12,0,0,0-16.78-17.16Z'/%3E%3C/svg%3E")}
.x-tool-img.x-tool-resize{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M220,48V96a12,12,0,0,1-24,0V77l-39.51,39.52a12,12,0,0,1-17-17L179,60H160a12,12,0,0,1,0-24h48A12,12,0,0,1,220,48ZM99.51,139.51,60,179V160a12,12,0,0,0-24,0v48a12,12,0,0,0,12,12H96a12,12,0,0,0,0-24H77l39.52-39.51a12,12,0,0,0-17-17Z'/%3E%3C/svg%3E")}
.x-tool-img.x-tool-restore{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M148,96V48a12,12,0,0,1,24,0V84h36a12,12,0,0,1,0,24H160A12,12,0,0,1,148,96ZM96,148H48a12,12,0,0,0,0,24H84v36a12,12,0,0,0,24,0V160A12,12,0,0,0,96,148Zm112,0H160a12,12,0,0,0-12,12v48a12,12,0,0,0,24,0V172h36a12,12,0,0,0,0-24ZM96,36A12,12,0,0,0,84,48V84H48a12,12,0,0,0,0,24H96a12,12,0,0,0,12-12V48A12,12,0,0,0,96,36Z'/%3E%3C/svg%3E")}
.x-tool-img.x-tool-right{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M184.49,136.49l-80,80a12,12,0,0,1-17-17L159,128,87.51,56.49a12,12,0,1,1,17-17l80,80A12,12,0,0,1,184.49,136.49Z'/%3E%3C/svg%3E")}
.x-tool-img.x-tool-save{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M216,83.31V208a8,8,0,0,1-8,8H176V152a8,8,0,0,0-8-8H88a8,8,0,0,0-8,8v64H48a8,8,0,0,1-8-8V48a8,8,0,0,1,8-8H172.69a8,8,0,0,1,5.65,2.34l35.32,35.32A8,8,0,0,1,216,83.31Z' opacity='0.4'/%3E%3Cpath d='M222.14,69.17,186.83,33.86A19.86,19.86,0,0,0,172.69,28H48A20,20,0,0,0,28,48V208a20,20,0,0,0,20,20H208a20,20,0,0,0,20-20V83.31A19.86,19.86,0,0,0,222.14,69.17ZM164,204H92V160h72Zm40,0H188V156a20,20,0,0,0-20-20H88a20,20,0,0,0-20,20v48H52V52H171l33,33ZM164,84a12,12,0,0,1-12,12H96a12,12,0,0,1,0-24h56A12,12,0,0,1,164,84Z'/%3E%3C/svg%3E")}
.x-tool-img.x-tool-search{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M192,112a80,80,0,1,1-80-80A80,80,0,0,1,192,112Z' opacity='0.4'/%3E%3Cpath d='M232.49,215.51,185,168a92.12,92.12,0,1,0-17,17l47.53,47.54a12,12,0,0,0,17-17ZM44,112a68,68,0,1,1,68,68A68.07,68.07,0,0,1,44,112Z'/%3E%3C/svg%3E")}
.x-tool-img.x-tool-toggle{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M184.49,167.51a12,12,0,0,1,0,17l-48,48a12,12,0,0,1-17,0l-48-48a12,12,0,0,1,17-17L128,207l39.51-39.52A12,12,0,0,1,184.49,167.51Zm-96-79L128,49l39.51,39.52a12,12,0,0,0,17-17l-48-48a12,12,0,0,0-17,0l-48,48a12,12,0,0,0,17,17Z'/%3E%3C/svg%3E")}
.x-tool-img.x-tool-unpin{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M56.88,31.93A12,12,0,1,0,39.12,48.07L60,71A76,76,0,0,0,35.46,84.51a20,20,0,0,0-1.6,29.73l45.46,45.47-39.8,39.8a12,12,0,0,0,17,17l39.8-39.81,45.47,45.46A20,20,0,0,0,155.9,228c.47,0,.94,0,1.41-.05A20,20,0,0,0,171.87,220a97.47,97.47,0,0,0,9.54-15.46l17.72,19.49a12,12,0,1,0,17.76-16.14Zm98.49,169.88L54.08,100.52C62,95,70.31,92.12,78.91,91.83l84.51,93A62,62,0,0,1,155.37,201.81Zm82.78-95-39,39.11a12,12,0,1,1-17-16.95l36.19-36.3-55-55L130.59,70.5a12,12,0,0,1-17-16.94l35.57-35.69a20,20,0,0,1,28.3,0l60.69,60.68A20,20,0,0,1,238.15,106.83Z'/%3E%3C/svg%3E")}
.x-tool-img.x-tool-up{--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M216.49,168.49a12,12,0,0,1-17,0L128,97,56.49,168.49a12,12,0,0,1-17-17l80-80a12,12,0,0,1,17,0l80,80A12,12,0,0,1,216.49,168.49Z'/%3E%3C/svg%3E")}
.x-treelist-item-icon::before{height:24px;margin:0 -1px;vertical-align:top}
PMT_CSS
}

theme_css_light_tail() {
    cat <<'PMT_CSS'
.pmx-itype-icon-memory{background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23475467'%3E%3Cpath d='M232,64H24a8,8,0,0,0-8,8V176H240V72A8,8,0,0,0,232,64ZM112,144H48V96h64Zm96,0H144V96h64Z' opacity='0.4'/%3E%3Cpath d='M232,52H24A20,20,0,0,0,4,72V200a12,12,0,0,0,24,0V188H48v12a12,12,0,0,0,24,0V188H92v12a12,12,0,0,0,24,0V188h24v12a12,12,0,0,0,24,0V188h20v12a12,12,0,0,0,24,0V188h20v12a12,12,0,0,0,24,0V72A20,20,0,0,0,232,52ZM28,76H228v88H28Zm92,64V100a12,12,0,0,0-12-12H56a12,12,0,0,0-12,12v40a12,12,0,0,0,12,12h52A12,12,0,0,0,120,140ZM96,128H68V112H96Zm52,24h52a12,12,0,0,0,12-12V100a12,12,0,0,0-12-12H148a12,12,0,0,0-12,12v40A12,12,0,0,0,148,152Zm12-40h28v16H160Z'/%3E%3C/svg%3E")}
.pmx-itype-icon-processor{background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23475467'%3E%3Cpath d='M200,48H56a8,8,0,0,0-8,8V200a8,8,0,0,0,8,8H200a8,8,0,0,0,8-8V56A8,8,0,0,0,200,48ZM152,152H104V104h48Z' opacity='0.4'/%3E%3Cpath d='M156,88H100a12,12,0,0,0-12,12v56a12,12,0,0,0,12,12h56a12,12,0,0,0,12-12V100A12,12,0,0,0,156,88Zm-12,56H112V112h32Zm88-4H220V116h12a12,12,0,0,0,0-24H220V56a20,20,0,0,0-20-20H164V24a12,12,0,0,0-24,0V36H116V24a12,12,0,0,0-24,0V36H56A20,20,0,0,0,36,56V92H24a12,12,0,0,0,0,24H36v24H24a12,12,0,0,0,0,24H36v36a20,20,0,0,0,20,20H92v12a12,12,0,0,0,24,0V220h24v12a12,12,0,0,0,24,0V220h36a20,20,0,0,0,20-20V164h12a12,12,0,0,0,0-24Zm-36,56H60V60H196Z'/%3E%3C/svg%3E")}
.pmx-itype-icon-memory,.pmx-itype-icon-processor{background-size:16px;filter:none}
.pmx-itype-icon-memory .x-grid-cell-inner,.pmx-itype-icon-processor .x-grid-cell-inner{color:inherit}
.x-tree-icon-custom.online::after,.x-tree-icon-custom.running::after,.x-tree-icon-custom.paused::after,.x-tree-icon-custom.suspended::after,.x-tree-icon-custom.unknown::after,.x-tree-icon-custom.error::after,.x-tree-icon-custom.offline::after,.x-tree-icon-custom.ha-error::after,.x-grid-icon-custom.online::after,.x-grid-icon-custom.running::after,.x-grid-icon-custom.paused::after,.x-grid-icon-custom.suspended::after,.x-grid-icon-custom.unknown::after,.x-grid-icon-custom.error::after,.x-grid-icon-custom.offline::after,.x-grid-icon-custom.ha-error::after{content:"";position:absolute;right:-6px;bottom:3px;left:auto;top:auto;width:6px;height:6px;border-radius:50%;text-shadow:none;box-shadow:0 0 0 2px #fff}
.x-tree-icon-custom.online::after,.x-tree-icon-custom.running::after,.x-grid-icon-custom.online::after,.x-grid-icon-custom.running::after{background-color:#22c55e}
.x-tree-icon-custom.paused::after,.x-tree-icon-custom.suspended::after,.x-grid-icon-custom.paused::after,.x-grid-icon-custom.suspended::after{background-color:#f59e0b}
.x-tree-icon-custom.unknown::after,.x-grid-icon-custom.unknown::after{background-color:#94a3b8}
.x-tree-icon-custom.error::after,.x-tree-icon-custom.offline::after,.x-tree-icon-custom.ha-error::after,.x-grid-icon-custom.error::after,.x-grid-icon-custom.offline::after,.x-grid-icon-custom.ha-error::after{background-color:#ef4444}
.x-tree-icon-custom.stopped,.x-grid-icon-custom.stopped{color:#98a2b3;opacity:.6}
.x-tree-icon-custom,.x-grid-icon-custom{position:relative}
.x-grid-icon-custom{margin-right:9px}
.proxmox-tags-full .proxmox-tag-light,.proxmox-tags-full .proxmox-tag-dark{border-radius:999px;padding:1px 7px}
body>.x-mask{background-color:rgba(16,24,40,.25);backdrop-filter:blur(3px)}
.usage-wrapper{margin-left:-3px;width:5px;padding:0;border:none;border-radius:3px;overflow:hidden;background-color:#d0d5dd}
.usage{background-color:#e2590b}
.x-tree-icon-custom::before,.x-grid-icon-custom::before{width:18px;height:18px;vertical-align:-4px}
.x-form-checkbox-default,.x-form-radio-default,.x-grid-checkcolumn::after{box-sizing:border-box;width:15px;height:15px;border:1.5px solid #98a2b3;background:#fff none;filter:none;transition:background-color .15s,border-color .15s}
.x-form-checkbox-default,.x-grid-checkcolumn::after{border-radius:4px}
.x-form-radio-default{border-radius:50%}
.x-form-cb-checked .x-form-checkbox-default,.x-keyboard-mode .x-form-cb-checked .x-form-checkbox-focus.x-form-checkbox-default,.x-grid-checkcolumn-checked::after{border-color:#e2590b;background:#e2590b url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23fff'%3E%3Cpath d='M232.49,80.49l-128,128a12,12,0,0,1-17,0l-56-56a12,12,0,1,1,17-17L96,183,215.51,63.51a12,12,0,0,1,17,17Z'/%3E%3C/svg%3E") center/11px no-repeat}
.x-form-cb-checked .x-form-radio-default,.x-keyboard-mode .x-form-cb-checked .x-form-radio-focus.x-form-radio-default{border-color:#e2590b;background:radial-gradient(circle, #e2590b 0 3.5px, #ffffff 4px)}
.x-form-checkbox-focus.x-form-checkbox-default,.x-form-radio-focus.x-form-radio-default{border-color:#e2590b}
.x-btn-wrap-default-toolbar-small.x-btn-arrow-right::after,.x-btn-wrap-default-toolbar-small.x-btn-split-right::after{background-image:none;background-color:#667085;filter:none;-webkit-mask:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M216.49,104.49l-80,80a12,12,0,0,1-17,0l-80-80a12,12,0,0,1,17-17L128,159l71.51-71.52a12,12,0,0,1,17,17Z'/%3E%3C/svg%3E") center/10px no-repeat;mask:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M216.49,104.49l-80,80a12,12,0,0,1-17,0l-80-80a12,12,0,0,1,17-17L128,159l71.51-71.52a12,12,0,0,1,17,17Z'/%3E%3C/svg%3E") center/10px no-repeat}
.pve-tag-inline-button .fa{padding-left:6px}
.x-border-layout-ct>.x-panel>.x-panel-bodyWrap>.x-tab-bar-default,.x-toolbar-default:has(>.x-box-inner .x-panel-header-text-default),.x-window-header-default,.x-panel-header-default{background-color:#fff;background-image:linear-gradient(rgba(226, 89, 11, 0.1), rgba(226, 89, 11, 0.1));border-color:rgba(226,89,11,.25)}
.x-tool{isolation:isolate}
.x-tool::before{content:"";position:absolute;inset:-4px;z-index:-1;border-radius:6px;transition:background-color .15s}
.x-tool.x-tool-over::before{background-color:#f2f4f7}
.x-tool-img,.x-tool-tool-el{color:#475467}
.x-tool-disabled{opacity:.45}
.x-tool-disabled .x-mask{background-color:rgba(0,0,0,0)}
.x-tool .x-tool-tool-el:not(.x-tool-img){font-size:0;background-color:currentColor;-webkit-mask:var(--modern-icon) center/contain no-repeat;mask:var(--modern-icon) center/contain no-repeat}
.x-panel-header .x-tool .x-tool-tool-el:not(.x-tool-img){--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M221.66,90.34,192,120,136,64l29.66-29.66a8,8,0,0,1,11.31,0L221.66,79A8,8,0,0,1,221.66,90.34Z' opacity='0.4'/%3E%3Cpath d='M230.15,70.54,185.46,25.86a20,20,0,0,0-28.28,0L33.86,149.17A19.86,19.86,0,0,0,28,163.31V208a20,20,0,0,0,20,20H216a12,12,0,0,0,0-24H125L230.15,98.83A20,20,0,0,0,230.15,70.54ZM91,204H52V165l84-84,39,39ZM192,103,153,64l18.34-18.34,39,39Z'/%3E%3C/svg%3E")}
.x-window-header .x-tool .x-tool-tool-el:not(.x-tool-img){--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M228,128a100,100,0,0,1-98.66,100H128a99.39,99.39,0,0,1-68.62-27.29,12,12,0,0,1,16.48-17.45,76,76,0,1,0-1.57-109c-.13.13-.25.25-.39.37L54.89,92H72a12,12,0,0,1,0,24H24a12,12,0,0,1-12-12V56a12,12,0,0,1,24,0V76.72L57.48,57.06A100,100,0,0,1,228,128Z'/%3E%3C/svg%3E")}
.x-window-header-default .x-title-text,.x-panel-header-default .x-title-text{color:#9a3412}
.x-window-header-default .x-tool-img,.x-window-header-default .x-tool-tool-el,.x-window-header-default .x-component,.x-window-header-default .x-autocontainer-innerCt,.x-panel-header-default .x-tool-img,.x-panel-header-default .x-tool-tool-el,.x-panel-header-default .x-component,.x-panel-header-default .x-autocontainer-innerCt{color:#9a3412}
.x-window-header-default .x-tool.x-tool-over::before,.x-panel-header-default .x-tool.x-tool-over::before{background-color:rgba(226,89,11,.1)}
.x-window-header-default .x-title-text{font-weight:600}
.x-panel-header-default{border-radius:10px 10px 0 0}
.x-window-header-default{border-radius:9px 9px 0 0}
.x-panel-default:has(>.x-panel-header-default){border-radius:10px;clip-path:inset(0 round 10px)}
.x-toolbar-default:has(>.x-box-inner .x-panel-header-text-default){border-radius:10px 10px 0 0}
.x-toolbar-default:has(>.x-box-inner .x-panel-header-text-default) .x-panel-header-text-default{color:#9a3412}
.x-toolbar-default:has(>.x-box-inner .x-panel-header-text-default) .x-btn.x-btn-default-toolbar-small,.x-toolbar-default:has(>.x-box-inner .x-panel-header-text-default) .x-btn.x-btn-default-toolbar-small.x-btn-focus,.x-toolbar-default:has(>.x-box-inner .x-panel-header-text-default) .x-btn.x-btn-default-toolbar-small.x-btn-pressed{background-color:rgba(226,89,11,.1);border-color:rgba(0,0,0,0);box-shadow:none}
.x-toolbar-default:has(>.x-box-inner .x-panel-header-text-default) .x-btn.x-btn-default-toolbar-small.x-btn-over,.x-toolbar-default:has(>.x-box-inner .x-panel-header-text-default) .x-btn.x-btn-default-toolbar-small.x-btn-focus.x-btn-over,.x-toolbar-default:has(>.x-box-inner .x-panel-header-text-default) .x-btn.x-btn-default-toolbar-small.x-btn-menu-active{background-color:rgba(226,89,11,.2)}
.x-toolbar-default:has(>.x-box-inner .x-panel-header-text-default) .x-btn.x-btn-default-toolbar-small .fa-play{color:#22c55e}
.x-toolbar-default:has(>.x-box-inner .x-panel-header-text-default) .x-btn.x-btn-default-toolbar-small .fa-power-off{color:#ef4444}
.x-toolbar-default:has(>.x-box-inner .x-panel-header-text-default) .x-btn.x-btn-default-toolbar-small .fa-undo,.x-toolbar-default:has(>.x-box-inner .x-panel-header-text-default) .x-btn.x-btn-default-toolbar-small .fa-refresh{color:#f59e0b}
.x-toolbar-default:has(>.x-box-inner .x-panel-header-text-default) .x-btn.x-btn-default-toolbar-small .fa-terminal{color:#e2590b}
.x-border-layout-ct>.x-panel>.x-panel-bodyWrap>.x-tab-bar-default{border-radius:10px 10px 0 0}
body:has(.pmt-logs-collapse) .x-splitter .x-collapse-el{display:none}
.x-keyboard-mode .x-splitter-focus::after{border-color:rgba(0,0,0,0)}
PMT_CSS
}

theme_css_dark_tail() {
    cat <<'PMT_CSS'
.pmx-itype-icon-memory{background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23bec4d0'%3E%3Cpath d='M232,64H24a8,8,0,0,0-8,8V176H240V72A8,8,0,0,0,232,64ZM112,144H48V96h64Zm96,0H144V96h64Z' opacity='0.4'/%3E%3Cpath d='M232,52H24A20,20,0,0,0,4,72V200a12,12,0,0,0,24,0V188H48v12a12,12,0,0,0,24,0V188H92v12a12,12,0,0,0,24,0V188h24v12a12,12,0,0,0,24,0V188h20v12a12,12,0,0,0,24,0V188h20v12a12,12,0,0,0,24,0V72A20,20,0,0,0,232,52ZM28,76H228v88H28Zm92,64V100a12,12,0,0,0-12-12H56a12,12,0,0,0-12,12v40a12,12,0,0,0,12,12h52A12,12,0,0,0,120,140ZM96,128H68V112H96Zm52,24h52a12,12,0,0,0,12-12V100a12,12,0,0,0-12-12H148a12,12,0,0,0-12,12v40A12,12,0,0,0,148,152Zm12-40h28v16H160Z'/%3E%3C/svg%3E")}
.pmx-itype-icon-processor{background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23bec4d0'%3E%3Cpath d='M200,48H56a8,8,0,0,0-8,8V200a8,8,0,0,0,8,8H200a8,8,0,0,0,8-8V56A8,8,0,0,0,200,48ZM152,152H104V104h48Z' opacity='0.4'/%3E%3Cpath d='M156,88H100a12,12,0,0,0-12,12v56a12,12,0,0,0,12,12h56a12,12,0,0,0,12-12V100A12,12,0,0,0,156,88Zm-12,56H112V112h32Zm88-4H220V116h12a12,12,0,0,0,0-24H220V56a20,20,0,0,0-20-20H164V24a12,12,0,0,0-24,0V36H116V24a12,12,0,0,0-24,0V36H56A20,20,0,0,0,36,56V92H24a12,12,0,0,0,0,24H36v24H24a12,12,0,0,0,0,24H36v36a20,20,0,0,0,20,20H92v12a12,12,0,0,0,24,0V220h24v12a12,12,0,0,0,24,0V220h36a20,20,0,0,0,20-20V164h12a12,12,0,0,0,0-24Zm-36,56H60V60H196Z'/%3E%3C/svg%3E")}
.pmx-itype-icon-memory,.pmx-itype-icon-processor{background-size:16px;filter:none}
.pmx-itype-icon-memory .x-grid-cell-inner,.pmx-itype-icon-processor .x-grid-cell-inner{color:inherit}
.x-tree-icon-custom.online::after,.x-tree-icon-custom.running::after,.x-tree-icon-custom.paused::after,.x-tree-icon-custom.suspended::after,.x-tree-icon-custom.unknown::after,.x-tree-icon-custom.error::after,.x-tree-icon-custom.offline::after,.x-tree-icon-custom.ha-error::after,.x-grid-icon-custom.online::after,.x-grid-icon-custom.running::after,.x-grid-icon-custom.paused::after,.x-grid-icon-custom.suspended::after,.x-grid-icon-custom.unknown::after,.x-grid-icon-custom.error::after,.x-grid-icon-custom.offline::after,.x-grid-icon-custom.ha-error::after{content:"";position:absolute;right:-6px;bottom:3px;left:auto;top:auto;width:6px;height:6px;border-radius:50%;text-shadow:none;box-shadow:0 0 0 2px #161a22}
.x-tree-icon-custom.online::after,.x-tree-icon-custom.running::after,.x-grid-icon-custom.online::after,.x-grid-icon-custom.running::after{background-color:#22c55e}
.x-tree-icon-custom.paused::after,.x-tree-icon-custom.suspended::after,.x-grid-icon-custom.paused::after,.x-grid-icon-custom.suspended::after{background-color:#f59e0b}
.x-tree-icon-custom.unknown::after,.x-grid-icon-custom.unknown::after{background-color:#94a3b8}
.x-tree-icon-custom.error::after,.x-tree-icon-custom.offline::after,.x-tree-icon-custom.ha-error::after,.x-grid-icon-custom.error::after,.x-grid-icon-custom.offline::after,.x-grid-icon-custom.ha-error::after{background-color:#ef4444}
.x-tree-icon-custom.stopped,.x-grid-icon-custom.stopped{color:#768093;opacity:.6}
.x-tree-icon-custom,.x-grid-icon-custom{position:relative}
.x-grid-icon-custom{margin-right:9px}
.proxmox-tags-full .proxmox-tag-light,.proxmox-tags-full .proxmox-tag-dark{border-radius:999px;padding:1px 7px}
body>.x-mask{background-color:rgba(5,7,12,.55);backdrop-filter:blur(3px)}
.usage-wrapper{margin-left:-3px;width:5px;padding:0;border:none;border-radius:3px;overflow:hidden;background-color:#333947}
.usage{background-color:#f0690f}
.x-tree-icon-custom::before,.x-grid-icon-custom::before{width:18px;height:18px;vertical-align:-4px}
.x-form-checkbox-default,.x-form-radio-default,.x-grid-checkcolumn::after{box-sizing:border-box;width:15px;height:15px;border:1.5px solid #768093;background:#181c25 none;filter:none;transition:background-color .15s,border-color .15s}
.x-form-checkbox-default,.x-grid-checkcolumn::after{border-radius:4px}
.x-form-radio-default{border-radius:50%}
.x-form-cb-checked .x-form-checkbox-default,.x-keyboard-mode .x-form-cb-checked .x-form-checkbox-focus.x-form-checkbox-default,.x-grid-checkcolumn-checked::after{border-color:#f0690f;background:#f0690f url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23fff'%3E%3Cpath d='M232.49,80.49l-128,128a12,12,0,0,1-17,0l-56-56a12,12,0,1,1,17-17L96,183,215.51,63.51a12,12,0,0,1,17,17Z'/%3E%3C/svg%3E") center/11px no-repeat}
.x-form-cb-checked .x-form-radio-default,.x-keyboard-mode .x-form-cb-checked .x-form-radio-focus.x-form-radio-default{border-color:#f0690f;background:radial-gradient(circle, #f0690f 0 3.5px, #181c25 4px)}
.x-form-checkbox-focus.x-form-checkbox-default,.x-form-radio-focus.x-form-radio-default{border-color:#f0690f}
.x-btn-wrap-default-toolbar-small.x-btn-arrow-right::after,.x-btn-wrap-default-toolbar-small.x-btn-split-right::after{background-image:none;background-color:#8790a1;filter:none;-webkit-mask:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M216.49,104.49l-80,80a12,12,0,0,1-17,0l-80-80a12,12,0,0,1,17-17L128,159l71.51-71.52a12,12,0,0,1,17,17Z'/%3E%3C/svg%3E") center/10px no-repeat;mask:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M216.49,104.49l-80,80a12,12,0,0,1-17,0l-80-80a12,12,0,0,1,17-17L128,159l71.51-71.52a12,12,0,0,1,17,17Z'/%3E%3C/svg%3E") center/10px no-repeat}
.pve-tag-inline-button .fa{padding-left:6px}
.x-border-layout-ct>.x-panel>.x-panel-bodyWrap>.x-tab-bar-default,.x-toolbar-default:has(>.x-box-inner .x-panel-header-text-default),.x-window-header-default,.x-panel-header-default{background-color:#161a22;background-image:linear-gradient(rgba(240, 105, 15, 0.14), rgba(240, 105, 15, 0.14));border-color:rgba(240,105,15,.25)}
.x-tool{isolation:isolate}
.x-tool::before{content:"";position:absolute;inset:-4px;z-index:-1;border-radius:6px;transition:background-color .15s}
.x-tool.x-tool-over::before{background-color:#2a2f3c}
.x-tool-img,.x-tool-tool-el{color:#bec4d0}
.x-tool-disabled{opacity:.45}
.x-tool-disabled .x-mask{background-color:rgba(0,0,0,0)}
.x-tool .x-tool-tool-el:not(.x-tool-img){font-size:0;background-color:currentColor;-webkit-mask:var(--modern-icon) center/contain no-repeat;mask:var(--modern-icon) center/contain no-repeat}
.x-panel-header .x-tool .x-tool-tool-el:not(.x-tool-img){--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M221.66,90.34,192,120,136,64l29.66-29.66a8,8,0,0,1,11.31,0L221.66,79A8,8,0,0,1,221.66,90.34Z' opacity='0.4'/%3E%3Cpath d='M230.15,70.54,185.46,25.86a20,20,0,0,0-28.28,0L33.86,149.17A19.86,19.86,0,0,0,28,163.31V208a20,20,0,0,0,20,20H216a12,12,0,0,0,0-24H125L230.15,98.83A20,20,0,0,0,230.15,70.54ZM91,204H52V165l84-84,39,39ZM192,103,153,64l18.34-18.34,39,39Z'/%3E%3C/svg%3E")}
.x-window-header .x-tool .x-tool-tool-el:not(.x-tool-img){--modern-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='12 12 232 232' fill='%23000'%3E%3Cpath d='M228,128a100,100,0,0,1-98.66,100H128a99.39,99.39,0,0,1-68.62-27.29,12,12,0,0,1,16.48-17.45,76,76,0,1,0-1.57-109c-.13.13-.25.25-.39.37L54.89,92H72a12,12,0,0,1,0,24H24a12,12,0,0,1-12-12V56a12,12,0,0,1,24,0V76.72L57.48,57.06A100,100,0,0,1,228,128Z'/%3E%3C/svg%3E")}
.x-window-header-default .x-title-text,.x-panel-header-default .x-title-text{color:#ffc599}
.x-window-header-default .x-tool-img,.x-window-header-default .x-tool-tool-el,.x-window-header-default .x-component,.x-window-header-default .x-autocontainer-innerCt,.x-panel-header-default .x-tool-img,.x-panel-header-default .x-tool-tool-el,.x-panel-header-default .x-component,.x-panel-header-default .x-autocontainer-innerCt{color:#ffc599}
.x-window-header-default .x-tool.x-tool-over::before,.x-panel-header-default .x-tool.x-tool-over::before{background-color:rgba(240,105,15,.14)}
.x-window-header-default .x-title-text{font-weight:600}
.x-panel-header-default{border-radius:10px 10px 0 0}
.x-window-header-default{border-radius:9px 9px 0 0}
.x-panel-default:has(>.x-panel-header-default){border-radius:10px;clip-path:inset(0 round 10px)}
.x-toolbar-default:has(>.x-box-inner .x-panel-header-text-default){border-radius:10px 10px 0 0}
.x-toolbar-default:has(>.x-box-inner .x-panel-header-text-default) .x-panel-header-text-default{color:#ffc599}
.x-toolbar-default:has(>.x-box-inner .x-panel-header-text-default) .x-btn.x-btn-default-toolbar-small,.x-toolbar-default:has(>.x-box-inner .x-panel-header-text-default) .x-btn.x-btn-default-toolbar-small.x-btn-focus,.x-toolbar-default:has(>.x-box-inner .x-panel-header-text-default) .x-btn.x-btn-default-toolbar-small.x-btn-pressed{background-color:rgba(240,105,15,.1);border-color:rgba(0,0,0,0);box-shadow:none}
.x-toolbar-default:has(>.x-box-inner .x-panel-header-text-default) .x-btn.x-btn-default-toolbar-small.x-btn-over,.x-toolbar-default:has(>.x-box-inner .x-panel-header-text-default) .x-btn.x-btn-default-toolbar-small.x-btn-focus.x-btn-over,.x-toolbar-default:has(>.x-box-inner .x-panel-header-text-default) .x-btn.x-btn-default-toolbar-small.x-btn-menu-active{background-color:rgba(240,105,15,.2)}
.x-toolbar-default:has(>.x-box-inner .x-panel-header-text-default) .x-btn.x-btn-default-toolbar-small .fa-play{color:#22c55e}
.x-toolbar-default:has(>.x-box-inner .x-panel-header-text-default) .x-btn.x-btn-default-toolbar-small .fa-power-off{color:#ef4444}
.x-toolbar-default:has(>.x-box-inner .x-panel-header-text-default) .x-btn.x-btn-default-toolbar-small .fa-undo,.x-toolbar-default:has(>.x-box-inner .x-panel-header-text-default) .x-btn.x-btn-default-toolbar-small .fa-refresh{color:#f59e0b}
.x-toolbar-default:has(>.x-box-inner .x-panel-header-text-default) .x-btn.x-btn-default-toolbar-small .fa-terminal{color:#f0690f}
.x-border-layout-ct>.x-panel>.x-panel-bodyWrap>.x-tab-bar-default{border-radius:10px 10px 0 0}
body:has(.pmt-logs-collapse) .x-splitter .x-collapse-el{display:none}
.x-keyboard-mode .x-splitter-focus::after{border-color:rgba(0,0,0,0)}
PMT_CSS
}

theme_accent_colors() {
    cat <<'PMT_COLORS'
blue	dark	#c65310	#2563eb
blue	dark	#e18484	rgb(234.8039215686, 172.1960784314, 172.1960784314)
blue	dark	#f0690f	#3b82f6
blue	dark	#fa802e	#60a5fa
blue	dark	#ffa35c	#93c5fd
blue	dark	#ffc599	#bfdbfe
blue	dark	#ffcc66	rgb(255, 220.6666666667, 152)
blue	dark	rgb(232.8,101.85,14.55)	rgb(57.23,126.1,238.62)
blue	dark	rgb(37.5,145.5,217.5)	rgb(182.3,125.5,32.7)
blue	dark	rgb(87.4,49.7,28.3)	rgb(33.1,57.2,97.6)
blue	dark	rgba(240, 105, 15, 0.14)	rgba(59, 130, 246, 0.14)
blue	dark	rgba(240,105,15,.1)	rgba(59,130,246,.1)
blue	dark	rgba(240,105,15,.14)	rgba(59,130,246,.14)
blue	dark	rgba(240,105,15,.2)	rgba(59,130,246,.2)
blue	dark	rgba(240,105,15,.25)	rgba(59,130,246,.25)
blue	dark	rgba(240,105,15,.45)	rgba(59,130,246,.45)
blue	dark	rgba(240,105,15,.5)	rgba(59,130,246,.5)
blue	dark	rgba(240,105,15,.55)	rgba(59,130,246,.55)
blue	light	#9a3412	#1e40af
blue	light	#b8470a	#1d4ed8
blue	light	#c2410c	#1d4ed8
blue	light	#e2590b	#2563eb
blue	light	#f06d1d	#3b82f6
blue	light	rgba(226, 89, 11, 0.1)	rgba(37, 99, 235, 0.1)
blue	light	rgba(226,89,11,.06)	rgba(37,99,235,.06)
blue	light	rgba(226,89,11,.1)	rgba(37,99,235,.1)
blue	light	rgba(226,89,11,.2)	rgba(37,99,235,.2)
blue	light	rgba(226,89,11,.25)	rgba(37,99,235,.25)
blue	light	rgba(226,89,11,.45)	rgba(37,99,235,.45)
blue	light	rgba(226,89,11,.5)	rgba(37,99,235,.5)
blue	light	rgba(226,89,11,.55)	rgba(37,99,235,.55)
green	dark	#c65310	#057a55
green	dark	#e18484	rgb(208.9215686275, 66.0784313725, 66.0784313725)
green	dark	#f0690f	#0e9f6e
green	dark	#fa802e	#34d399
green	dark	#ffa35c	#6ee7b7
green	dark	#ffc599	#a7f3d0
green	dark	#ffcc66	rgb(255, 176.6666666667, 20)
green	dark	rgb(232.8,101.85,14.55)	rgb(13.58,154.23,106.7)
green	dark	rgb(37.5,145.5,217.5)	rgb(218.3,102.3,141.5)
green	dark	rgb(87.4,49.7,28.3)	rgb(19.6,65.9,56.8)
green	dark	rgba(240, 105, 15, 0.14)	rgba(14, 159, 110, 0.14)
green	dark	rgba(240,105,15,.1)	rgba(14,159,110,.1)
green	dark	rgba(240,105,15,.14)	rgba(14,159,110,.14)
green	dark	rgba(240,105,15,.2)	rgba(14,159,110,.2)
green	dark	rgba(240,105,15,.25)	rgba(14,159,110,.25)
green	dark	rgba(240,105,15,.45)	rgba(14,159,110,.45)
green	dark	rgba(240,105,15,.5)	rgba(14,159,110,.5)
green	dark	rgba(240,105,15,.55)	rgba(14,159,110,.55)
green	light	#9a3412	#065f46
green	light	#b8470a	#047857
green	light	#c2410c	#047857
green	light	#e2590b	#059669
green	light	#f06d1d	#10b981
green	light	rgba(226, 89, 11, 0.1)	rgba(5, 150, 105, 0.1)
green	light	rgba(226,89,11,.06)	rgba(5,150,105,.06)
green	light	rgba(226,89,11,.1)	rgba(5,150,105,.1)
green	light	rgba(226,89,11,.2)	rgba(5,150,105,.2)
green	light	rgba(226,89,11,.25)	rgba(5,150,105,.25)
green	light	rgba(226,89,11,.45)	rgba(5,150,105,.45)
green	light	rgba(226,89,11,.5)	rgba(5,150,105,.5)
green	light	rgba(226,89,11,.55)	rgba(5,150,105,.55)
pink	dark	#c65310	#db2777
pink	dark	#e18484	rgb(235.3921568627, 174.6078431373, 174.6078431373)
pink	dark	#f0690f	#ec4899
pink	dark	#fa802e	#f472b6
pink	dark	#ffa35c	#f9a8d4
pink	dark	#ffc599	#fbcfe8
pink	dark	#ffcc66	rgb(255, 221.6666666667, 155)
pink	dark	rgb(232.8,101.85,14.55)	rgb(228.92,69.84,148.41)
pink	dark	rgb(37.5,145.5,217.5)	rgb(40.7,171.9,107.1)
pink	dark	rgb(87.4,49.7,28.3)	rgb(86.2,39.8,69.7)
pink	dark	rgba(240, 105, 15, 0.14)	rgba(236, 72, 153, 0.14)
pink	dark	rgba(240,105,15,.1)	rgba(236,72,153,.1)
pink	dark	rgba(240,105,15,.14)	rgba(236,72,153,.14)
pink	dark	rgba(240,105,15,.2)	rgba(236,72,153,.2)
pink	dark	rgba(240,105,15,.25)	rgba(236,72,153,.25)
pink	dark	rgba(240,105,15,.45)	rgba(236,72,153,.45)
pink	dark	rgba(240,105,15,.5)	rgba(236,72,153,.5)
pink	dark	rgba(240,105,15,.55)	rgba(236,72,153,.55)
pink	light	#9a3412	#9d174d
pink	light	#b8470a	#be185d
pink	light	#c2410c	#be185d
pink	light	#e2590b	#db2777
pink	light	#f06d1d	#ec4899
pink	light	rgba(226, 89, 11, 0.1)	rgba(219, 39, 119, 0.1)
pink	light	rgba(226,89,11,.06)	rgba(219,39,119,.06)
pink	light	rgba(226,89,11,.1)	rgba(219,39,119,.1)
pink	light	rgba(226,89,11,.2)	rgba(219,39,119,.2)
pink	light	rgba(226,89,11,.25)	rgba(219,39,119,.25)
pink	light	rgba(226,89,11,.45)	rgba(219,39,119,.45)
pink	light	rgba(226,89,11,.5)	rgba(219,39,119,.5)
pink	light	rgba(226,89,11,.55)	rgba(219,39,119,.55)
violet	dark	#c65310	#7c3aed
violet	dark	#e18484	rgb(241.2745098039, 198.7254901961, 198.7254901961)
violet	dark	#f0690f	#8b5cf6
violet	dark	#fa802e	#a78bfa
violet	dark	#ffa35c	#c4b5fd
violet	dark	#ffc599	#ddd6fe
violet	dark	#ffcc66	rgb(255, 231.6666666667, 185)
violet	dark	rgb(232.8,101.85,14.55)	rgb(134.83,89.24,238.62)
violet	dark	rgb(37.5,145.5,217.5)	rgb(118.3,155.9,32.7)
violet	dark	rgb(87.4,49.7,28.3)	rgb(57.1,45.8,97.6)
violet	dark	rgba(240, 105, 15, 0.14)	rgba(139, 92, 246, 0.14)
violet	dark	rgba(240,105,15,.1)	rgba(139,92,246,.1)
violet	dark	rgba(240,105,15,.14)	rgba(139,92,246,.14)
violet	dark	rgba(240,105,15,.2)	rgba(139,92,246,.2)
violet	dark	rgba(240,105,15,.25)	rgba(139,92,246,.25)
violet	dark	rgba(240,105,15,.45)	rgba(139,92,246,.45)
violet	dark	rgba(240,105,15,.5)	rgba(139,92,246,.5)
violet	dark	rgba(240,105,15,.55)	rgba(139,92,246,.55)
violet	light	#9a3412	#5b21b6
violet	light	#b8470a	#6d28d9
violet	light	#c2410c	#6d28d9
violet	light	#e2590b	#7c3aed
violet	light	#f06d1d	#8b5cf6
violet	light	rgba(226, 89, 11, 0.1)	rgba(124, 58, 237, 0.1)
violet	light	rgba(226,89,11,.06)	rgba(124,58,237,.06)
violet	light	rgba(226,89,11,.1)	rgba(124,58,237,.1)
violet	light	rgba(226,89,11,.2)	rgba(124,58,237,.2)
violet	light	rgba(226,89,11,.25)	rgba(124,58,237,.25)
violet	light	rgba(226,89,11,.45)	rgba(124,58,237,.45)
violet	light	rgba(226,89,11,.5)	rgba(124,58,237,.5)
violet	light	rgba(226,89,11,.55)	rgba(124,58,237,.55)
PMT_COLORS
}

# <<< end of generated part

require_root
require_files
main_menu
