#!/usr/bin/env bash
set -euo pipefail

PATCH_PREFIX="/root/pve-expand-node-tree-patch"
PM_FILE="/usr/share/pve-manager/js/pvemanagerlib.js"
HELPER_DIR="/usr/local/lib/pve-expand-node-tree"
APT_HOOK_FILE="/etc/apt/apt.conf.d/99-pve-expand-node-tree"

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

        fr:menu_logs_apply) echo "Replier le panneau Logs par défaut" ;;
        en:menu_logs_apply) echo "Collapse the Logs panel by default" ;;

        fr:menu_logs_remove) echo "Garder le panneau Logs déplié par défaut" ;;
        en:menu_logs_remove) echo "Keep the Logs panel expanded by default" ;;

        fr:menu_hook_enable) echo "Réappliquer automatiquement après une mise à jour" ;;
        en:menu_hook_enable) echo "Re-apply automatically after an update" ;;

        fr:menu_hook_disable) echo "Ne plus réappliquer automatiquement" ;;
        en:menu_hook_disable) echo "Stop re-applying automatically" ;;

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

        fr:restart_proxy) echo "Redémarrage de pveproxy..." ;;
        en:restart_proxy) echo "Restarting pveproxy..." ;;

        fr:restart_proxy_wait) echo "Cela peut prendre jusqu'à une minute, l'interface web reste injoignable pendant ce temps. C'est normal, ne coupez pas le script." ;;
        en:restart_proxy_wait) echo "This can take up to a minute, the web interface stays unreachable meanwhile. This is expected, do not interrupt the script." ;;

        fr:patch_applied) echo "Patch appliqué avec succès." ;;
        en:patch_applied) echo "Patch applied successfully." ;;

        fr:hard_refresh) echo "Un hard refresh du navigateur est recommandé (Ctrl+Shift+R)." ;;
        en:hard_refresh) echo "A hard refresh in your browser is recommended (Ctrl+Shift+R)." ;;

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

        fr:status_tree) echo "Nœuds dépliés par défaut" ;;
        en:status_tree) echo "Nodes expanded by default" ;;

        fr:status_active) echo "actif" ;;
        en:status_active) echo "active" ;;

        fr:status_inactive) echo "inactif" ;;
        en:status_inactive) echo "inactive" ;;

        fr:state_unknown) echo "structure du fichier inattendue" ;;
        en:state_unknown) echo "unexpected file structure" ;;

        fr:status_auto_reapply) echo "Réapplication automatique" ;;
        en:status_auto_reapply) echo "Automatic re-apply" ;;

        fr:status_enabled) echo "activée" ;;
        en:status_enabled) echo "enabled" ;;

        fr:status_disabled) echo "désactivée" ;;
        en:status_disabled) echo "disabled" ;;

        fr:hook_enabled) echo "Les patchs en place seront réappliqués automatiquement après chaque mise à jour de pve-manager." ;;
        en:hook_enabled) echo "The patches in place will be re-applied automatically after every pve-manager update." ;;

        fr:hook_disabled) echo "Réapplication automatique désactivée." ;;
        en:hook_disabled) echo "Automatic re-apply disabled." ;;

        fr:hook_already_enabled) echo "La réapplication automatique est déjà active." ;;
        en:hook_already_enabled) echo "Automatic re-apply is already active." ;;

        fr:hook_already_disabled) echo "La réapplication automatique n'est pas active." ;;
        en:hook_already_disabled) echo "Automatic re-apply is not active." ;;

        fr:hook_nothing) echo "Aucun patch n'est en place, il n'y a rien à réappliquer. Appliquez d'abord un patch." ;;
        en:hook_nothing) echo "No patch is in place, there is nothing to re-apply. Apply a patch first." ;;

        fr:hook_removed) echo "Plus aucun patch n'est en place : la réapplication automatique est désactivée." ;;
        en:hook_removed) echo "No patch is in place any more: automatic re-apply is disabled." ;;

        fr:hook_file) echo "Fichier de hook APT" ;;
        en:hook_file) echo "APT hook file" ;;

        fr:status_logs) echo "Panneau Logs replié par défaut" ;;
        en:status_logs) echo "Logs panel collapsed by default" ;;

        fr:logs_title) echo "PANNEAU LOGS" ;;
        en:logs_title) echo "LOGS PANEL" ;;

        fr:logs_body_1) echo "Replie par défaut le panneau du bas (onglet Tâches et journal de la grappe), à chaque chargement de la page, exactement comme cliquer le chevron soi-même." ;;
        en:logs_body_1) echo "Collapses the bottom panel (Tasks tab and cluster log) by default, on every page load, exactly like clicking its chevron by hand." ;;

        fr:logs_body_2) echo "Seul l'état de départ change : vous pouvez toujours le déplier en cliquant dessus, il se replie simplement à nouveau au prochain chargement." ;;
        en:logs_body_2) echo "Only the starting state changes: you can still expand it by clicking it, it just folds back on the next page load." ;;

        fr:logs_applied) echo "Panneau Logs replié par défaut." ;;
        en:logs_applied) echo "Logs panel collapsed by default." ;;

        fr:logs_removed) echo "Panneau Logs à nouveau déplié par défaut." ;;
        en:logs_removed) echo "Logs panel expanded by default again." ;;

        fr:logs_already_applied) echo "Déjà appliqué. Aucune modification." ;;
        en:logs_already_applied) echo "Already applied. No changes made." ;;

        fr:logs_not_applied) echo "Pas appliqué." ;;
        en:logs_not_applied) echo "Not applied." ;;

        fr:available_backups) echo "Backups disponibles" ;;
        en:available_backups) echo "Available backups" ;;

        fr:choose_backup_number) echo "Choisissez le numéro du backup à restaurer" ;;
        en:choose_backup_number) echo "Choose a backup number to restore" ;;

        fr:bye) echo "À bientôt." ;;
        en:bye) echo "Bye." ;;

        fr:already_patched) echo "Le patch est déjà présent. Aucune modification appliquée." ;;
        en:already_patched) echo "The patch is already present. No changes applied." ;;

        fr:patch_incompatible) echo "Le code attendu n'a pas été trouvé. Cette version de Proxmox VE n'est pas prise en charge par ce patch." ;;
        en:patch_incompatible) echo "The expected code was not found. This Proxmox VE version is not supported by this patch." ;;

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

        fr:warning_body_1) echo "Ce script modifie un fichier JavaScript fourni par Proxmox VE." ;;
        en:warning_body_1) echo "This script modifies a JavaScript file provided by Proxmox VE." ;;

        fr:warning_body_2) echo "Ceci est hors support, sera écrasé par les mises à jour du paquet pve-manager (sauf si la réapplication automatique est activée), et toute erreur de patch peut casser l'interface web jusqu'à la restauration du backup." ;;
        en:warning_body_2) echo "This is unsupported, will be overwritten by pve-manager package updates (unless automatic re-apply is enabled), and any patching error may break the web UI until you restore the backup." ;;

        fr:warning_body_3) echo "Veuillez garder une session SSH root active avant de continuer." ;;
        en:warning_body_3) echo "Please keep an active root SSH session open before continuing." ;;

        fr:type_yes) echo "Tapez 'yes' pour continuer" ;;
        en:type_yes) echo "Type 'yes' to continue" ;;

        fr:version_mismatch_title) echo "VERSION DIFFÉRENTE" ;;
        en:version_mismatch_title) echo "VERSION MISMATCH" ;;

        fr:version_mismatch_body) echo "Ce backup a été pris sur une autre version de Proxmox VE. Restaurer ce fichier sur la version actuelle peut casser l'interface web." ;;
        en:version_mismatch_body) echo "This backup was taken on a different Proxmox VE version. Restoring this file on the current version may break the web interface." ;;

        fr:version_in_backup) echo "Dans le backup" ;;
        en:version_in_backup) echo "In the backup" ;;

        fr:version_installed) echo "Installé" ;;
        en:version_installed) echo "Installed" ;;

        fr:banner_subtitle) echo "Default Panel Layout" ;;
        en:banner_subtitle) echo "Default Panel Layout" ;;

        fr:repo_hint) echo "Déplie l'arborescence et replie le panneau Logs par défaut dans l'interface web Proxmox VE" ;;
        en:repo_hint) echo "Expands the resource tree and collapses the Logs panel by default in the Proxmox VE web interface" ;;

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
    [[ -f "$PM_FILE" ]] || { say_err "$(tr_msg file_not_found): $PM_FILE"; exit 1; }
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
# Patch engine, also run by the APT hook after a package update
# ------------------------------------------------------------

PATCH_PY="$(cat <<'PY'
from pathlib import Path
import os
import sys

# ResourceTree.addChildSorted() creates every node of the left tree, including
# each PVE node's own entry (info.type === 'node'), right before this line.
# ExtJS tree nodes default to collapsed, so each node starts folded on every
# fresh page load. Inserting an expanded flag for that one type opens it by
# default, without touching pools, storages, guests or the datacenter root,
# which the stock code already expands.
TREE_STOCK = "        let child = Ext.create('PVETree', info);\n"
TREE_PATCHED = (
    "        if (info.type === 'node') {\n"
    "            info.expanded = true;\n"
    "        }\n"
    + TREE_STOCK
)

# Workspace.js's south region, the "Logs" panel that holds the Tasks tab and
# the cluster log, has no initial collapsed state either, so it always opens
# expanded and covers the bottom of the screen until folded back by hand.
# "collapsible: true," on its own is NOT unique once every manager6 file is
# assembled into pvemanagerlib.js (a datacenter panel and an unrelated
# fieldset also have it at the same indentation), and "collapsed: true," is
# already in two stock fieldsets, so both applying the patch and detecting it
# match the full block down from its "stateId: 'pvesouth'", which only exists
# once.
LOGS_STOCK = (
    "                    stateId: 'pvesouth',\n"
    "                    itemId: 'south',\n"
    "                    region: 'south',\n"
    "                    margin: '0 5 5 5',\n"
    "                    title: gettext('Logs'),\n"
    "                    collapsible: true,\n"
)
LOGS_PATCHED = LOGS_STOCK + "                    collapsed: true,\n"

PATCHES = {"tree": (TREE_STOCK, TREE_PATCHED), "logs": (LOGS_STOCK, LOGS_PATCHED)}


def state(text, name):
    stock, patched = PATCHES[name]
    applied = text.count(patched)
    # a patched block still contains the stock one
    pristine = text.count(stock) - applied * patched.count(stock)
    if applied == 1 and pristine == 0:
        return "patched"
    if applied == 0 and pristine == 1:
        return "stock"
    return "unknown"


def main(args):
    if len(args) < 2 or any(name not in PATCHES for name in args[1:]):
        return 2
    path = Path(os.environ["PM_FILE"])
    text = path.read_text(encoding="utf-8")
    command = args[0]
    if command == "state":
        print(state(text, args[1]))
        return 0
    # reapply runs after every package operation: it puts back the patches it
    # carries on a stock file and leaves anything else alone
    if command == "reapply":
        for name in args[1:]:
            if state(text, name) == "stock":
                text = text.replace(*PATCHES[name], 1)
        path.write_text(text, encoding="utf-8")
        return 0
    if command not in ("apply", "revert"):
        return 2
    name = args[1]
    expected = "stock" if command == "apply" else "patched"
    if state(text, name) != expected:
        return 1
    stock, patched = PATCHES[name]
    before, after = (stock, patched) if command == "apply" else (patched, stock)
    path.write_text(text.replace(before, after, 1), encoding="utf-8")
    return 0


sys.exit(main(sys.argv[1:]))
PY
)"

patch_engine() {
    PM_FILE="$PM_FILE" python3 -c "$PATCH_PY" "$@"
}

# Prints stock, patched or unknown for the tree or the logs patch.
patch_state() {
    patch_engine state "$1"
}

restart_pveproxy() {
    say_info "$(tr_msg restart_proxy)"
    printf "  %b%s%b\n" "${PMX_GREY}" "$(tr_msg restart_proxy_wait)" "${RESET}"
    systemctl restart pveproxy.service
}

# ------------------------------------------------------------
# Backups
# ------------------------------------------------------------

latest_backup_dir() {
    find /root -maxdepth 1 -type d -name 'pve-expand-node-tree-patch-*' | sort | tail -n1
}

list_backups_raw() {
    find /root -maxdepth 1 -type d -name 'pve-expand-node-tree-patch-*' | sort
}

create_backup() {
    local ts dir
    ts="$(date +%F-%H%M%S)"
    dir="${PATCH_PREFIX}-${ts}"
    mkdir -p "$dir"

    cp -av "$PM_FILE" "$dir/" >/dev/null

    {
        echo "created_at=$(date --iso-8601=seconds)"
        echo "hostname=$(hostname)"
        echo "pm_file=$PM_FILE"
        echo
        pveversion -v 2>/dev/null || true
    } >"$dir/INFO.txt"

    sha256sum "$dir/$(basename "$PM_FILE")" >"$dir/SHA256SUMS.txt"
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
# APT hook, so a package update does not silently drop the patches
# ------------------------------------------------------------

hook_is_enabled() {
    [[ -f "$APT_HOOK_FILE" ]]
}

applied_patches() {
    local name
    for name in tree logs; do
        if [[ "$(patch_state "$name")" == "patched" ]]; then
            echo "$name"
        fi
    done
}

# pveproxy reads pvemanagerlib.js from disk on every request, and an update of
# pve-manager restarts it anyway, so the hook restarts nothing. It only carries
# the patches in place when it is written, so a patch the user never applied,
# or took out since, never comes back after an update.
write_hook_file() {
    local patches
    patches="$(applied_patches | tr '\n' ' ')"

    mkdir -p "$HELPER_DIR"
    printf '%s\n' "$PATCH_PY" >"$HELPER_DIR/patch.py"
    chmod 0644 "$HELPER_DIR/patch.py"

    cat >"$APT_HOOK_FILE" <<EOF_HOOK
// Managed by Proxmox-Tools pve-expand-node-tree.sh
// Re-applies the patches when a pve-manager update restores the stock file.
DPkg::Post-Invoke {"if [ -f ${HELPER_DIR}/patch.py ] && [ -f ${PM_FILE} ]; then PM_FILE=${PM_FILE} python3 ${HELPER_DIR}/patch.py reapply ${patches}|| true; fi"; };
EOF_HOOK
    chmod 0644 "$APT_HOOK_FILE"
}

remove_hook_files() {
    rm -f "$APT_HOOK_FILE"
    rm -rf "$HELPER_DIR"
}

# Keep the hook in step with the patches that are actually in place.
refresh_hook_file() {
    hook_is_enabled || return 0
    if [[ -n "$(applied_patches)" ]]; then
        write_hook_file
    else
        remove_hook_files
        say_info "$(tr_msg hook_removed)"
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

state_label() {
    case "$1" in
        patched) echo "${PMX_GREEN}$(tr_msg status_active)${RESET}" ;;
        stock) echo "${PMX_GREY}$(tr_msg status_inactive)${RESET}" ;;
        *) echo "${PMX_AMBER}$(tr_msg state_unknown)${RESET}" ;;
    esac
}

show_status() {
    local pm_version hook_state

    pm_version="$(installed_pkg_version pve-manager)"

    if hook_is_enabled; then
        hook_state="${PMX_GREEN}$(tr_msg status_enabled)${RESET}"
    else
        hook_state="${PMX_GREY}$(tr_msg status_disabled)${RESET}"
    fi

    panel "$PMX_ORANGE" "$(tr_msg status_title)" \
        "$(tr_msg detected_version): pve-manager ${BOLD}${pm_version:-?}${RESET}" \
        "$(tr_msg status_tree): ${BOLD}$(state_label "$(patch_state tree)")" \
        "$(tr_msg status_logs): ${BOLD}$(state_label "$(patch_state logs)")" \
        "$(tr_msg status_auto_reapply): ${BOLD}${hook_state}"
}

apply_patch() {
    local backup_dir

    case "$(patch_state tree)" in
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

    if ! patch_engine apply tree || [[ "$(patch_state tree)" != "patched" ]]; then
        say_err "$(tr_msg patch_failed)"
        return 1
    fi

    refresh_hook_file
    restart_pveproxy
    echo
    say_ok "$(tr_msg patch_applied)"
    say_info "$(tr_msg hard_refresh)"
    say_info "$(tr_msg backup_used): ${PMX_CYAN}${backup_dir}${RESET}"
}

apply_logs_patch() {
    local backup_dir

    case "$(patch_state logs)" in
        stock) ;;
        patched)
            say_ok "$(tr_msg logs_already_applied)"
            return 0
            ;;
        *)
            say_err "$(tr_msg patch_incompatible)"
            say_info "$(tr_msg no_file_modified)"
            return 1
            ;;
    esac

    panel "$PMX_BLUE" "$(tr_msg logs_title)" \
        "$(tr_msg logs_body_1)" \
        "$(tr_msg logs_body_2)"

    if ! confirm_yes; then
        say_info "$(tr_msg cancelled)"
        return 0
    fi

    backup_dir="$(create_backup)"
    say_info "$(tr_msg backup_created): ${PMX_CYAN}${backup_dir}${RESET}"

    if ! patch_engine apply logs || [[ "$(patch_state logs)" != "patched" ]]; then
        say_err "$(tr_msg patch_failed)"
        return 1
    fi

    refresh_hook_file
    restart_pveproxy
    echo
    say_ok "$(tr_msg logs_applied)"
    say_info "$(tr_msg hard_refresh)"
    say_info "$(tr_msg backup_used): ${PMX_CYAN}${backup_dir}${RESET}"
}

remove_logs_patch() {
    local backup_dir

    case "$(patch_state logs)" in
        patched) ;;
        stock)
            say_info "$(tr_msg logs_not_applied)"
            return 0
            ;;
        *)
            say_err "$(tr_msg patch_incompatible)"
            say_info "$(tr_msg no_file_modified)"
            return 1
            ;;
    esac

    backup_dir="$(create_backup)"
    say_info "$(tr_msg backup_created): ${PMX_CYAN}${backup_dir}${RESET}"

    if ! patch_engine revert logs || [[ "$(patch_state logs)" != "stock" ]]; then
        say_err "$(tr_msg patch_failed)"
        return 1
    fi

    refresh_hook_file
    restart_pveproxy
    echo
    say_ok "$(tr_msg logs_removed)"
    say_info "$(tr_msg hard_refresh)"
    say_info "$(tr_msg backup_used): ${PMX_CYAN}${backup_dir}${RESET}"
}

confirm_backup_versions() {
    local dir="$1"
    local backup_version installed_version

    backup_version="$(pkg_version_from_backup "$dir" pve-manager)"
    installed_version="$(installed_pkg_version pve-manager)"

    [[ -n "$backup_version" && -n "$installed_version" ]] || return 0
    [[ "$backup_version" != "$installed_version" ]] || return 0

    panel "$PMX_AMBER" "$(tr_msg version_mismatch_title)" \
        "$(tr_msg version_mismatch_body)" \
        "pve-manager · $(tr_msg version_in_backup) ${BOLD}${backup_version}${RESET} · $(tr_msg version_installed) ${BOLD}${installed_version}${RESET}"

    if ! confirm_yes; then
        say_info "$(tr_msg restore_cancelled)"
        return 1
    fi
    return 0
}

restore_specific() {
    local dir="$1"
    [[ -d "$dir" ]] || { say_err "$(tr_msg file_not_found): $dir"; return 1; }
    [[ -f "$dir/$(basename "$PM_FILE")" ]] || { say_err "$(tr_msg file_not_found): $dir/$(basename "$PM_FILE")"; return 1; }

    confirm_backup_versions "$dir" || return 0

    cp -av "$dir/$(basename "$PM_FILE")" "$PM_FILE"

    refresh_hook_file
    restart_pveproxy
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
        printf " %b6)%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$(tr_msg menu_logs_apply)"
        printf " %b7)%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$(tr_msg menu_logs_remove)"
        printf " %b8)%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$(tr_msg menu_hook_enable)"
        printf " %b9)%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$(tr_msg menu_hook_disable)"
        printf " %b10)%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$(tr_msg menu_quit)"
        echo

        read -r -p "$(tr_msg choose_option) [1-10]: " choice
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
                menu_action apply_logs_patch
                pause
                ;;
            7)
                menu_action remove_logs_patch
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
