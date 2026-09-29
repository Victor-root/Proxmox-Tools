#!/usr/bin/env bash
set -euo pipefail

PATCH_PREFIX="/root/pve-xtermjs-scrollback-patch"
UTIL_FILE="/usr/share/pve-xtermjs/util.js"
SCROLLBACK_LINES=100000
SCROLLBACK_RECOMMENDED=100000
SCROLLBACK_MIN=1000
SCROLLBACK_MAX=1000000
SCROLLBACK_PRESETS=(10000 25000 50000 100000 250000)

# getTerminalSettings() in util.js builds the options given to every xterm.js
# console (host shell, containers, VMs). It starts from an empty object, so
# xterm.js falls back to its own default of 1000 lines. Starting from
# { scrollback: N } instead sets the default for all consoles, while a
# pve-xterm-scrollback value saved in the browser, read further down by
# recent versions, still wins.
# The patch and the state detection both match this whole two line block, with
# either the stock {} or an already patched { scrollback: N }, so a file that
# no longer looks like this is reported instead of patched blindly.
BLOCK_HEAD="function getTerminalSettings() {
    var res = "

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
        fr:menu_apply) echo "Appliquer le patch ou changer le nombre de lignes (backup automatique inclus)" ;;
        en:menu_apply) echo "Apply patch or change the number of lines (automatic backup included)" ;;

        fr:menu_restore_latest) echo "Restaurer le dernier backup" ;;
        en:menu_restore_latest) echo "Restore latest backup" ;;

        fr:menu_restore_select) echo "Restaurer depuis un backup choisi" ;;
        en:menu_restore_select) echo "Restore from selected backup" ;;

        fr:menu_status) echo "Afficher l'état du patch" ;;
        en:menu_status) echo "Show patch status" ;;

        fr:menu_backups) echo "Lister les backups" ;;
        en:menu_backups) echo "List backups" ;;

        fr:menu_test) echo "Générer des lignes de test (vérifier l'historique de la console)" ;;
        en:menu_test) echo "Generate test lines (check the console history)" ;;

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

        fr:reopen_console) echo "Aucun redémarrage n'est nécessaire : rouvrez la console. Si l'ancienne valeur persiste, faites un hard refresh du navigateur (Ctrl+Shift+R)." ;;
        en:reopen_console) echo "No restart is needed: reopen the console. If the old value persists, hard refresh your browser (Ctrl+Shift+R)." ;;

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

        fr:status_scrollback) echo "Historique des consoles" ;;
        en:status_scrollback) echo "Console scrollback" ;;

        fr:state_patched) echo "${SCROLLBACK_LINES} lignes (patch actif)" ;;
        en:state_patched) echo "${SCROLLBACK_LINES} lines (patch active)" ;;

        fr:state_stock) echo "1000 lignes (valeur par défaut de Proxmox)" ;;
        en:state_stock) echo "1000 lines (Proxmox default)" ;;

        fr:state_unknown) echo "structure du fichier inattendue" ;;
        en:state_unknown) echo "unexpected file structure" ;;

        fr:lines_title) echo "NOMBRE DE LIGNES" ;;
        en:lines_title) echo "NUMBER OF LINES" ;;

        fr:lines_word) echo "lignes" ;;
        en:lines_word) echo "lines" ;;

        fr:lines_memory) echo "environ $(mem_mb "$2" 80) Mo par onglet en 80 colonnes" ;;
        en:lines_memory) echo "about $(mem_mb "$2" 80) MB per tab at 80 columns" ;;

        fr:lines_recommended) echo "recommandé" ;;
        en:lines_recommended) echo "recommended" ;;

        fr:lines_current) echo "valeur actuelle" ;;
        en:lines_current) echo "current value" ;;

        fr:lines_custom) echo "Personnalisé" ;;
        en:lines_custom) echo "Custom" ;;

        fr:lines_custom_prompt) echo "Nombre de lignes (entre ${SCROLLBACK_MIN} et ${SCROLLBACK_MAX})" ;;
        en:lines_custom_prompt) echo "Number of lines (between ${SCROLLBACK_MIN} and ${SCROLLBACK_MAX})" ;;

        fr:lines_invalid) echo "Nombre invalide : entrez un entier entre ${SCROLLBACK_MIN} et ${SCROLLBACK_MAX}." ;;
        en:lines_invalid) echo "Invalid number: enter a whole number between ${SCROLLBACK_MIN} and ${SCROLLBACK_MAX}." ;;

        fr:lines_choose) echo "Choisissez le nombre de lignes" ;;
        en:lines_choose) echo "Choose the number of lines" ;;

        fr:test_needs_patch) echo "Appliquez d'abord le patch (option 1)." ;;
        en:test_needs_patch) echo "Apply the patch first (option 1)." ;;

        fr:test_title) echo "TEST DE L'HISTORIQUE" ;;
        en:test_title) echo "SCROLLBACK TEST" ;;

        fr:test_body_1) echo "Affiche ${TEST_LINES} lignes numérotées, soit 500 de plus que la limite du patch, pour voir jusqu'où on peut remonter." ;;
        en:test_body_1) echo "Prints ${TEST_LINES} numbered lines, 500 more than the patch limit, to see how far up you can scroll." ;;

        fr:test_body_2) echo "À lancer dans la console web de Proxmox, ouverte APRÈS le patch (une console déjà ouverte garde l'ancienne limite). Dans un terminal SSH, c'est celui de votre logiciel qui décide." ;;
        en:test_body_2) echo "Run it in the Proxmox web console, opened AFTER the patch (a console already open keeps the old limit). In an SSH terminal, your terminal software decides." ;;

        fr:test_body_3) echo "Le script se ferme ensuite, car son menu effacerait l'historique que vous voulez examiner." ;;
        en:test_body_3) echo "The script then exits, because its menu would clear the history you want to inspect." ;;

        fr:test_start) echo "Appuyez sur Entrée pour lancer le test..." ;;
        en:test_start) echo "Press Enter to start the test..." ;;

        fr:test_line) echo "Ligne de test" ;;
        en:test_line) echo "Test line" ;;

        fr:test_result_title) echo "RÉSULTAT" ;;
        en:test_result_title) echo "RESULT" ;;

        fr:test_result_1) echo "Remontez tout en haut de la console avec la molette ou Maj+PgHaut." ;;
        en:test_result_1) echo "Scroll all the way up in the console with the mouse wheel or Shift+PageUp." ;;

        fr:test_result_2) echo "Patch actif : la plus ancienne ligne visible est proche de 500." ;;
        en:test_result_2) echo "Patch active: the oldest visible line is close to 500." ;;

        fr:test_result_3) echo "Limite par défaut : elle est proche de $((TEST_LINES - 1000)), vous ne pouvez remonter que d'environ 1000 lignes." ;;
        en:test_result_3) echo "Default limit: it is close to $((TEST_LINES - 1000)), you can only go back about 1000 lines." ;;

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

        fr:warning_body_1) echo "Ce script modifie un fichier JavaScript du paquet pve-xtermjs, qui affiche les consoles xterm.js (shell de l'hôte, conteneurs, VM)." ;;
        en:warning_body_1) echo "This script modifies a JavaScript file of the pve-xtermjs package, which draws the xterm.js consoles (host shell, containers, VMs)." ;;

        fr:warning_body_2) echo "Ceci est hors support et sera écrasé par les mises à jour du paquet pve-xtermjs, il faudra alors relancer le script." ;;
        en:warning_body_2) echo "This is unsupported and will be overwritten by pve-xtermjs package updates, in which case you need to run the script again." ;;

        fr:warning_body_3) echo "Une console pleine à ${SCROLLBACK_LINES} lignes occupe jusqu'à environ $(mem_mb "$SCROLLBACK_LINES" 80) Mo dans le navigateur en 80 colonnes, $(mem_mb "$SCROLLBACK_LINES" 200) Mo en 200 colonnes (contre 1 à 2,5 Mo par défaut), par onglet ouvert." ;;
        en:warning_body_3) echo "A console filled to ${SCROLLBACK_LINES} lines uses up to about $(mem_mb "$SCROLLBACK_LINES" 80) MB in the browser at 80 columns, $(mem_mb "$SCROLLBACK_LINES" 200) MB at 200 columns (against 1 to 2.5 MB by default), per open tab." ;;

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

        fr:banner_subtitle) echo "Console Scrollback" ;;
        en:banner_subtitle) echo "Console Scrollback" ;;

        fr:repo_hint) echo "Augmente durablement l'historique des consoles xterm.js de Proxmox VE (1000 lignes par défaut)" ;;
        en:repo_hint) echo "Permanently raises the scrollback of the Proxmox VE xterm.js consoles (1000 lines by default)" ;;

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
    [[ -f "$UTIL_FILE" ]] || { say_err "$(tr_msg file_not_found): $UTIL_FILE"; exit 1; }
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

# Prints stock, patched:N or unknown. Only a file holding exactly one copy of
# the block, in one of its two known forms, is recognised.
get_state() {
    UTIL_FILE="$UTIL_FILE" BLOCK_HEAD="$BLOCK_HEAD" python3 <<'PY'
from pathlib import Path
import os
import re

text = Path(os.environ["UTIL_FILE"]).read_text(encoding="utf-8")
head = os.environ["BLOCK_HEAD"]

stock = text.count(head + "{};\n")
patched = re.findall(re.escape(head) + r"\{ scrollback: (\d+) \};\n", text)

if stock == 1 and not patched:
    print("stock")
elif stock == 0 and len(patched) == 1:
    print("patched:" + patched[0])
else:
    print("unknown")
PY
}

apply_python_patch() {
    UTIL_FILE="$UTIL_FILE" BLOCK_HEAD="$BLOCK_HEAD" SCROLLBACK_LINES="$SCROLLBACK_LINES" python3 <<'PY'
from pathlib import Path
import os
import re
import sys

util_path = Path(os.environ["UTIL_FILE"])
text = util_path.read_text(encoding="utf-8")
head = os.environ["BLOCK_HEAD"]

block = re.compile(re.escape(head) + r"(?:\{\}|\{ scrollback: \d+ \});\n")
if len(block.findall(text)) != 1:
    sys.exit(1)

new_block = head + "{ scrollback: " + os.environ["SCROLLBACK_LINES"] + " };\n"
util_path.write_text(block.sub(lambda _: new_block, text, count=1), encoding="utf-8")
PY
}

# Upper bound of the browser memory used by one full console, 12 bytes a cell.
mem_mb() {
    echo $(( $1 * $2 * 12 / 1000000 ))
}

# ------------------------------------------------------------
# Backups
# ------------------------------------------------------------

latest_backup_dir() {
    find /root -maxdepth 1 -type d -name 'pve-xtermjs-scrollback-patch-*' | sort | tail -n1
}

list_backups_raw() {
    find /root -maxdepth 1 -type d -name 'pve-xtermjs-scrollback-patch-*' | sort
}

create_backup() {
    local ts dir
    ts="$(date +%F-%H%M%S)"
    dir="${PATCH_PREFIX}-${ts}"
    mkdir -p "$dir"

    cp -av "$UTIL_FILE" "$dir/" >/dev/null

    {
        echo "created_at=$(date --iso-8601=seconds)"
        echo "hostname=$(hostname)"
        echo "util_file=$UTIL_FILE"
        echo
        pveversion -v 2>/dev/null || true
    } >"$dir/INFO.txt"

    sha256sum "$dir/$(basename "$UTIL_FILE")" >"$dir/SHA256SUMS.txt"
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
        patched:*)
            SCROLLBACK_LINES="${state#patched:}"
            state_label="${PMX_GREEN}$(tr_msg state_patched)${RESET}"
            ;;
        stock) state_label="${PMX_GREY}$(tr_msg state_stock)${RESET}" ;;
        *) state_label="${PMX_AMBER}$(tr_msg state_unknown)${RESET}" ;;
    esac

    panel "$PMX_ORANGE" "$(tr_msg status_title)" \
        "$(tr_msg detected_version): pve-xtermjs ${BOLD}${xt_version:-?}${RESET}" \
        "$(tr_msg status_scrollback): ${BOLD}${state_label}"
}

# Sets SCROLLBACK_LINES from a preset or a custom number. Returns 1 when the
# user cancels or enters something invalid, after saying why.
choose_lines() {
    local current="$1"
    local rows=() i=1 preset row choice custom

    for preset in "${SCROLLBACK_PRESETS[@]}"; do
        row="${PMX_ORANGE_SOFT}${i})${RESET} ${preset} $(tr_msg lines_word) ${PMX_GREY}($(tr_msg lines_memory "$preset"))${RESET}"
        [[ "$preset" -eq "$SCROLLBACK_RECOMMENDED" ]] && row+=" ${PMX_GREEN}$(tr_msg lines_recommended)${RESET}"
        [[ "$preset" == "$current" ]] && row+=" ${PMX_AMBER}$(tr_msg lines_current)${RESET}"
        rows+=("$row")
        ((i++))
    done
    rows+=("${PMX_ORANGE_SOFT}${i})${RESET} $(tr_msg lines_custom)")
    rows+=("${PMX_GREY}q) $(tr_msg cancelled)${RESET}")

    panel "$PMX_BLUE" "$(tr_msg lines_title)" "${rows[@]}"
    echo
    read -r -p "$(tr_msg lines_choose): " choice

    if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
        say_info "$(tr_msg cancelled)"
        return 1
    fi

    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#SCROLLBACK_PRESETS[@]} )); then
        SCROLLBACK_LINES="${SCROLLBACK_PRESETS[$((choice-1))]}"
        return 0
    fi

    if [[ "$choice" == "$i" ]]; then
        read -r -p "$(tr_msg lines_custom_prompt): " custom
        if [[ "$custom" =~ ^[0-9]{1,7}$ ]] && (( 10#$custom >= SCROLLBACK_MIN && 10#$custom <= SCROLLBACK_MAX )); then
            SCROLLBACK_LINES=$((10#$custom))
            return 0
        fi
        say_err "$(tr_msg lines_invalid)"
        return 1
    fi

    say_err "$(tr_msg invalid_choice)"
    return 1
}

apply_patch() {
    local backup_dir state current=""

    state="$(get_state)"
    case "$state" in
        stock) ;;
        patched:*) current="${state#patched:}" ;;
        *)
            say_err "$(tr_msg patch_incompatible)"
            say_info "$(tr_msg no_file_modified)"
            return 1
            ;;
    esac

    choose_lines "$current" || return 0

    if [[ "$SCROLLBACK_LINES" == "$current" ]]; then
        say_ok "$(tr_msg already_patched)"
        return 0
    fi

    show_warning_and_confirm || return 0

    backup_dir="$(create_backup)"
    say_info "$(tr_msg backup_created): ${PMX_CYAN}${backup_dir}${RESET}"

    if ! apply_python_patch || [[ "$(get_state)" != "patched:${SCROLLBACK_LINES}" ]]; then
        say_err "$(tr_msg patch_failed)"
        return 1
    fi

    echo
    say_ok "$(tr_msg patch_applied)"
    say_info "$(tr_msg reopen_console)"
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
    [[ -f "$dir/$(basename "$UTIL_FILE")" ]] || { say_err "$(tr_msg file_not_found): $dir/$(basename "$UTIL_FILE")"; return 1; }

    confirm_backup_versions "$dir" || return 0

    cp -av "$dir/$(basename "$UTIL_FILE")" "$UTIL_FILE"

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

generate_test_lines() {
    local state
    state="$(get_state)"

    if [[ "$state" != patched:* ]]; then
        say_err "$(tr_msg test_needs_patch)"
        return 1
    fi

    TEST_LINES=$(( ${state#patched:} + 500 ))

    panel "$PMX_BLUE" "$(tr_msg test_title)" \
        "$(tr_msg test_body_1)" \
        "$(tr_msg test_body_2)" \
        "$(tr_msg test_body_3)"

    echo
    read -r -p "$(tr_msg test_start)" _ || true

    seq -f "$(tr_msg test_line) %g" 1 "$TEST_LINES"

    panel "$PMX_GREEN" "$(tr_msg test_result_title)" \
        "$(tr_msg test_result_1)" \
        "$(tr_msg test_result_2)" \
        "$(tr_msg test_result_3)"
    exit 0
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
        printf " %b6)%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$(tr_msg menu_test)"
        printf " %b7)%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$(tr_msg menu_quit)"
        echo

        read -r -p "$(tr_msg choose_option) [1-7]: " choice
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
                generate_test_lines
                ;;
            7)
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
