#!/usr/bin/env bash
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/Victor-root/Proxmox-Tools"
# The scripts are downloaded from main on every start, so the dashboard always
# runs their latest version. PVE_TOOLS_REF names another branch, to try one
# before it is merged.
REPO_REF="${PVE_TOOLS_REF:-main}"

# id|file, in the order of the menu. Every script answers "state" with one
# line, "<applied|outdated|stock|unknown> <on|off|none>", and runs the actions
# given as arguments without asking for confirmations (see run_actions in each
# of them).
TOOLS=(
    "language|pve-default-language-i18n"
    "subscription|pve-remove-subscription-notice.sh"
    "newtab|pve-console-newtab.sh"
    "layout|pve-expand-node-tree.sh"
    "scrollback|pve-xtermjs-scrollback.sh"
    "tabtitle|pve-xterm-tab-title.sh"
    "theme|pve-modern-theme.sh"
    "fastfetch|pve-fastfetch-motd.sh"
)

# label key|tool id|actions, the "Recommended by Victor-root" set.
RECOMMENDED=(
    "step_language|language|apply"
    "step_language_mobile|language|mobile"
    "step_subscription|subscription|apply"
    "step_subscription_mobile|subscription|mobile"
    "step_newtab|newtab|apply"
    "step_newtab_tree|newtab|tree"
    "step_layout|layout|apply"
    "step_layout_logs|layout|logs"
    "step_scrollback|scrollback|apply=100000"
    "step_tabtitle|tabtitle|apply"
    "step_theme|theme|install"
    "step_theme_options|theme|storage-on console-on"
    "step_theme_default|theme|default"
)

WORK_DIR=""
cleanup() {
    if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
        rm -rf "$WORK_DIR"
    fi
}
trap cleanup EXIT

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
        fr:menu_recommended) echo "Recommandé par Victor-root (tout configurer d'un coup)" ;;
        en:menu_recommended) echo "Recommended by Victor-root (set everything up at once)" ;;

        fr:menu_hooks_on) echo "Réappliquer automatiquement tout ce qui est en place après une mise à jour" ;;
        en:menu_hooks_on) echo "Re-apply everything in place automatically after an update" ;;

        fr:menu_hooks_off) echo "Ne plus rien réappliquer automatiquement" ;;
        en:menu_hooks_off) echo "Stop re-applying anything automatically" ;;

        fr:menu_quit) echo "Quitter" ;;
        en:menu_quit) echo "Quit" ;;

        fr:menu_scripts) echo "Scripts (ouvre leur menu habituel)" ;;
        en:menu_scripts) echo "Scripts (opens their usual menu)" ;;

        fr:tool_language) echo "Langue par défaut" ;;
        en:tool_language) echo "Default language" ;;

        fr:tool_subscription) echo "Popup d'abonnement" ;;
        en:tool_subscription) echo "Subscription notice" ;;

        fr:tool_newtab) echo "Console en nouvel onglet" ;;
        en:tool_newtab) echo "Console in a new tab" ;;

        fr:tool_layout) echo "Disposition des panneaux" ;;
        en:tool_layout) echo "Panel layout" ;;

        fr:tool_scrollback) echo "Historique des consoles" ;;
        en:tool_scrollback) echo "Console scrollback" ;;

        fr:tool_tabtitle) echo "Titre des onglets de console" ;;
        en:tool_tabtitle) echo "Console tab title" ;;

        fr:tool_theme) echo "Thème moderne" ;;
        en:tool_theme) echo "Modern theme" ;;

        fr:tool_fastfetch) echo "Fastfetch à la connexion" ;;
        en:tool_fastfetch) echo "Fastfetch at login" ;;

        fr:state_applied) echo "en place" ;;
        en:state_applied) echo "in place" ;;

        fr:state_outdated) echo "mise à jour disponible" ;;
        en:state_outdated) echo "update available" ;;

        fr:state_stock) echo "pas en place" ;;
        en:state_stock) echo "not in place" ;;

        fr:state_unknown) echo "non pris en charge ici" ;;
        en:state_unknown) echo "not supported here" ;;

        fr:hook_on) echo "réappliqué après les mises à jour" ;;
        en:hook_on) echo "re-applied after updates" ;;

        fr:hook_off) echo "pas réappliqué après les mises à jour" ;;
        en:hook_off) echo "not re-applied after updates" ;;

        fr:step_language) echo "Langue par défaut du serveur" ;;
        en:step_language) echo "Default language of the server" ;;

        fr:step_language_mobile) echo "Langue par défaut de l'interface mobile" ;;
        en:step_language_mobile) echo "Default language of the mobile interface" ;;

        fr:step_subscription) echo "Popup d'abonnement supprimé sur ordinateur" ;;
        en:step_subscription) echo "Subscription notice removed on desktop" ;;

        fr:step_subscription_mobile) echo "Popup d'abonnement supprimé sur mobile" ;;
        en:step_subscription_mobile) echo "Subscription notice removed on mobile" ;;

        fr:step_newtab) echo "Console en nouvel onglet" ;;
        en:step_newtab) echo "Console in a new tab" ;;

        fr:step_newtab_tree) echo "Clic molette dans l'arbre des ressources" ;;
        en:step_newtab_tree) echo "Middle click in the resource tree" ;;

        fr:step_layout) echo "Nœuds ouverts dans l'arbre des ressources" ;;
        en:step_layout) echo "Nodes opened in the resource tree" ;;

        fr:step_layout_logs) echo "Panneau Logs replié" ;;
        en:step_layout_logs) echo "Logs panel collapsed" ;;

        fr:step_scrollback) echo "Historique des consoles à 100000 lignes" ;;
        en:step_scrollback) echo "Console scrollback of 100000 lines" ;;

        fr:step_tabtitle) echo "Titre des onglets de console" ;;
        en:step_tabtitle) echo "Console tab title" ;;

        fr:step_theme) echo "Thèmes modernes" ;;
        en:step_theme) echo "Modern themes" ;;

        fr:step_theme_options) echo "Options du thème : tailles en Tio, bouton Démarrer dans la console" ;;
        en:step_theme_options) echo "Theme options: sizes in TiB, Start button in the console" ;;

        fr:step_theme_default) echo "Thème par défaut (vous le choisissez)" ;;
        en:step_theme_default) echo "Default theme (you choose it)" ;;

        fr:step_hooks) echo "Réapplication automatique après les mises à jour" ;;
        en:step_hooks) echo "Automatic re-apply after updates" ;;

        fr:recommended_title) echo "Recommandé par Victor-root" ;;
        en:recommended_title) echo "Recommended by Victor-root" ;;

        fr:recommended_intro) echo "Applique ces réglages l'un après l'autre :" ;;
        en:recommended_intro) echo "Applies these settings one after the other:" ;;

        fr:recommended_asks) echo "Vous choisirez la langue, la locale et le fuseau horaire, puis le thème par défaut." ;;
        en:recommended_asks) echo "You will choose the language, the locale and the time zone, then the default theme." ;;

        fr:warning_title) echo "Avertissement" ;;
        en:warning_title) echo "Warning" ;;

        fr:warning_body_1) echo "Chaque script fait sa propre sauvegarde avant de modifier un fichier, et garde ses options de restauration." ;;
        en:warning_body_1) echo "Each script makes its own backup before changing a file, and keeps its restore options." ;;

        fr:warning_body_2) echo "Ces modifications sont hors support Proxmox. Gardez une session SSH root ouverte pendant l'opération." ;;
        en:warning_body_2) echo "These changes are not supported by Proxmox. Keep a root SSH session open during the operation." ;;

        fr:hooks_question) echo "Réappliquer automatiquement tout cela après chaque mise à jour ? [yes/no]" ;;
        en:hooks_question) echo "Re-apply all of this automatically after every update? [yes/no]" ;;

        fr:hooks_answer_invalid) echo "Répondez yes ou no." ;;
        en:hooks_answer_invalid) echo "Answer yes or no." ;;

        fr:type_yes) echo "Tapez 'yes' pour lancer" ;;
        en:type_yes) echo "Type 'yes' to start" ;;

        fr:cancelled) echo "Opération annulée." ;;
        en:cancelled) echo "Operation cancelled." ;;

        fr:restart_services) echo "Redémarrage des services" ;;
        en:restart_services) echo "Restarting the services" ;;

        fr:restart_wait) echo "Cela peut prendre jusqu'à une minute, l'interface web reste injoignable pendant ce temps. C'est normal, ne coupez pas le script." ;;
        en:restart_wait) echo "This can take up to a minute, the web interface stays unreachable meanwhile. This is expected, do not interrupt the script." ;;

        fr:restart_failed) echo "Le redémarrage a échoué, relancez-le à la main" ;;
        en:restart_failed) echo "The restart failed, run it by hand" ;;

        fr:summary_title) echo "Résumé" ;;
        en:summary_title) echo "Summary" ;;

        fr:summary_ok) echo "fait" ;;
        en:summary_ok) echo "done" ;;

        fr:summary_failed) echo "échec, voir les messages plus haut" ;;
        en:summary_failed) echo "failed, see the messages above" ;;

        fr:summary_hooks_failed) echo "échec pour" ;;
        en:summary_hooks_failed) echo "failed for" ;;

        fr:reload_hint) echo "Rechargez la page de l'interface web sans le cache (Ctrl+F5) pour voir les changements." ;;
        en:reload_hint) echo "Reload the web interface page without the cache (Ctrl+F5) to see the changes." ;;

        fr:hooks_none_on) echo "Aucun script en place n'est à réactiver : rien à faire." ;;
        en:hooks_none_on) echo "No script in place needs turning on: nothing to do." ;;

        fr:hooks_none_off) echo "Aucune réapplication automatique n'est active : rien à faire." ;;
        en:hooks_none_off) echo "No automatic re-apply is active: nothing to do." ;;

        fr:downloading) echo "Téléchargement des scripts depuis" ;;
        en:downloading) echo "Downloading the scripts from" ;;

        fr:download_failed) echo "Téléchargement impossible" ;;
        en:download_failed) echo "Download failed" ;;

        fr:invalid_ref) echo "Nom de branche invalide dans PVE_TOOLS_REF" ;;
        en:invalid_ref) echo "Invalid branch name in PVE_TOOLS_REF" ;;

        fr:not_proxmox) echo "Ce script doit être lancé sur un hôte Proxmox VE." ;;
        en:not_proxmox) echo "This script must be run on a Proxmox VE host." ;;

        fr:missing_curl) echo "curl est requis." ;;
        en:missing_curl) echo "curl is required." ;;

        fr:choose_option) echo "Choisissez une option" ;;
        en:choose_option) echo "Choose an option" ;;

        fr:press_enter) echo "Appuyez sur Entrée pour continuer..." ;;
        en:press_enter) echo "Press Enter to continue..." ;;

        fr:running_as_root) echo "Ce script doit être lancé en root." ;;
        en:running_as_root) echo "This script must be run as root." ;;

        fr:invalid_choice) echo "Choix invalide." ;;
        en:invalid_choice) echo "Invalid choice." ;;

        fr:detected_language) echo "Langue détectée" ;;
        en:detected_language) echo "Detected language" ;;

        fr:lang_fr) echo "Français" ;;
        en:lang_fr) echo "French" ;;

        fr:lang_en) echo "Anglais" ;;
        en:lang_en) echo "English" ;;

        fr:bye) echo "À bientôt." ;;
        en:bye) echo "Bye." ;;

        fr:banner_subtitle) echo "Proxmox-Tools Dashboard" ;;
        en:banner_subtitle) echo "Proxmox-Tools Dashboard" ;;

        fr:repo_hint) echo "Tous les scripts Proxmox-Tools au même endroit" ;;
        en:repo_hint) echo "Every Proxmox-Tools script in one place" ;;

        * ) echo "$key" ;;
    esac
}

APP_NAME="$(tr_msg banner_subtitle)"

# ------------------------------------------------------------
# Colors (Proxmox-inspired), same visual engine as
# lxc-wireguard-server-install.sh, orange as the accent color.
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
    command -v curl >/dev/null 2>&1 || { say_err "$(tr_msg missing_curl)"; exit 1; }
}

# ------------------------------------------------------------
# Scripts
# ------------------------------------------------------------

download_tools() {
    local entry file

    if ! [[ "$REPO_REF" =~ ^[A-Za-z0-9._/-]+$ ]]; then
        say_err "$(tr_msg invalid_ref): ${REPO_REF}"
        exit 1
    fi

    WORK_DIR="$(mktemp -d)"
    say_info "$(tr_msg downloading) ${PMX_CYAN}${REPO_RAW}/${REPO_REF}${RESET}"
    for entry in "${TOOLS[@]}"; do
        file="${entry#*|}"
        if ! curl -fsSL --retry 2 -o "${WORK_DIR}/${file}" "${REPO_RAW}/${REPO_REF}/scripts/${file}"; then
            say_err "$(tr_msg download_failed): ${file}"
            exit 1
        fi
    done
}

tool_file() {
    local entry
    for entry in "${TOOLS[@]}"; do
        if [[ "${entry%%|*}" == "$1" ]]; then
            echo "${WORK_DIR}/${entry#*|}"
            return 0
        fi
    done
    return 1
}

run_tool() {
    local file
    file="$(tool_file "$1")"
    shift
    bash "$file" "$@"
}

# Prints "<state> <hook>", "unknown none" when the script stops before
# answering, for example because the files it patches are missing.
tool_state() {
    local line
    line="$(run_tool "$1" state 2>/dev/null)" || line=""
    if [[ "$line" =~ ^(applied|outdated|stock|unknown)\ (on|off|none)$ ]]; then
        echo "$line"
    else
        echo "unknown none"
    fi
}

state_text() {
    local state="${1% *}" hook="${1#* }" text
    case "$state" in
        applied) text="${PMX_GREEN}$(tr_msg state_applied)${RESET}" ;;
        outdated) text="${PMX_AMBER}$(tr_msg state_outdated)${RESET}" ;;
        stock) text="${PMX_GREY}$(tr_msg state_stock)${RESET}" ;;
        *) text="${PMX_RED}$(tr_msg state_unknown)${RESET}" ;;
    esac
    if [[ "$state" == "applied" || "$state" == "outdated" ]]; then
        case "$hook" in
            on) text+=" ${PMX_GREY}·${RESET} ${PMX_GREEN}$(tr_msg hook_on)${RESET}" ;;
            off) text+=" ${PMX_GREY}· $(tr_msg hook_off)${RESET}" ;;
        esac
    fi
    echo "$text"
}

# Pads by characters, not bytes, so accented labels stay aligned.
pad() {
    local text="$1" width="$2"
    printf "%s%*s" "$text" "$(( width > ${#text} ? width - ${#text} : 0 ))" ""
}

# ------------------------------------------------------------
# Actions
# ------------------------------------------------------------

ask_hooks() {
    local answer
    while true; do
        printf "%b?%b %b%s%b : " "${PMX_AMBER}" "${RESET}" "${BOLD}" "$(tr_msg hooks_question)" "${RESET}"
        read -r answer
        case "${answer,,}" in
            yes) return 0 ;;
            no) return 1 ;;
            *) say_err "$(tr_msg hooks_answer_invalid)" ;;
        esac
    done
}

restart_collected() {
    local restart_file="$1" units=()
    mapfile -t units < <(sort -u "$restart_file")
    ((${#units[@]})) || return 0

    echo
    say_info "$(tr_msg restart_services): ${units[*]}"
    printf "  %b%s%b\n" "${PMX_GREY}" "$(tr_msg restart_wait)" "${RESET}"
    if ! systemctl restart "${units[@]}"; then
        say_err "$(tr_msg restart_failed): systemctl restart ${units[*]}"
    fi
}

run_recommended() {
    local entry key tool actions with_hooks=0 restart_file failed_hooks=() lines=() bullets=()
    local -a action_list

    for entry in "${RECOMMENDED[@]}"; do
        bullets+=("  • $(tr_msg "${entry%%|*}")")
    done

    panel "$PMX_ORANGE" "$(tr_msg recommended_title)" \
        "$(tr_msg recommended_intro)" \
        "${bullets[@]}" \
        "" \
        "$(tr_msg recommended_asks)"
    panel "$PMX_AMBER" "$(tr_msg warning_title)" \
        "$(tr_msg warning_body_1)" \
        "$(tr_msg warning_body_2)"
    echo

    if ask_hooks; then
        with_hooks=1
    fi

    if ! confirm_yes; then
        say_info "$(tr_msg cancelled)"
        return 0
    fi

    restart_file="${WORK_DIR}/restart"
    : >"$restart_file"

    for entry in "${RECOMMENDED[@]}"; do
        key="${entry%%|*}"
        tool="${entry#*|}"
        actions="${tool#*|}"
        tool="${tool%%|*}"
        read -r -a action_list <<<"$actions"

        echo
        hr
        printf "%b%s%b\n" "${BOLD}${PMX_ORANGE_SOFT}" "$(tr_msg "$key")" "${RESET}"
        if run_tool "$tool" --restart-file "$restart_file" "${action_list[@]}"; then
            lines+=("${PMX_GREEN}✓${RESET} $(tr_msg "$key")")
        else
            lines+=("${PMX_RED}✗${RESET} $(tr_msg "$key"): ${PMX_RED}$(tr_msg summary_failed)${RESET}")
        fi
    done

    if [[ "$with_hooks" -eq 1 ]]; then
        echo
        hr
        printf "%b%s%b\n" "${BOLD}${PMX_ORANGE_SOFT}" "$(tr_msg step_hooks)" "${RESET}"
        for entry in "${TOOLS[@]}"; do
            tool="${entry%%|*}"
            if [[ "$(tool_state "$tool")" == *" none" ]]; then
                continue
            fi
            if ! run_tool "$tool" hook-on; then
                failed_hooks+=("$(tr_msg "tool_${tool}")")
            fi
        done
        if ((${#failed_hooks[@]})); then
            lines+=("${PMX_RED}✗${RESET} $(tr_msg step_hooks): ${PMX_RED}$(tr_msg summary_hooks_failed) ${failed_hooks[*]}${RESET}")
        else
            lines+=("${PMX_GREEN}✓${RESET} $(tr_msg step_hooks)")
        fi
    fi

    restart_collected "$restart_file"

    panel "$PMX_ORANGE" "$(tr_msg summary_title)" "${lines[@]}"
    echo
    say_info "$(tr_msg reload_hint)"
}

# Turns the automatic re-apply on for every script in place, or off for
# every script where it is on.
set_all_hooks() {
    local wanted="$1" entry tool state did=0

    for entry in "${TOOLS[@]}"; do
        tool="${entry%%|*}"
        state="$(tool_state "$tool")"
        if [[ "$wanted" == "on" && "$state" =~ ^(applied|outdated)\ off$ ]] ||
            [[ "$wanted" == "off" && "$state" == *" on" ]]; then
            echo
            printf "%b%s%b\n" "${BOLD}${PMX_ORANGE_SOFT}" "$(tr_msg "tool_${tool}")" "${RESET}"
            run_tool "$tool" "hook-${wanted}" || true
            did=1
        fi
    done

    if [[ "$did" -eq 0 ]]; then
        say_info "$(tr_msg "hooks_none_${wanted}")"
    fi
}

main_menu() {
    local entry tool i choice states=() count="${#TOOLS[@]}"
    local hooks_on=$((count + 2)) hooks_off=$((count + 3)) quit=$((count + 4))

    while true; do
        states=()
        for entry in "${TOOLS[@]}"; do
            states+=("$(tool_state "${entry%%|*}")")
        done

        show_banner
        printf " %b%2d)%b %b%s%b\n" "${PMX_ORANGE_SOFT}" 1 "${RESET}" "${BOLD}" "$(tr_msg menu_recommended)" "${RESET}"
        echo
        printf "    %b%s%b\n" "${PMX_GREY}" "$(tr_msg menu_scripts)" "${RESET}"
        i=2
        for entry in "${TOOLS[@]}"; do
            tool="${entry%%|*}"
            printf " %b%2d)%b %s %b\n" "${PMX_ORANGE_SOFT}" "$i" "${RESET}" \
                "$(pad "$(tr_msg "tool_${tool}")" 30)" "$(state_text "${states[$((i - 2))]}")"
            ((i++))
        done
        echo
        printf " %b%2d)%b %s\n" "${PMX_ORANGE_SOFT}" "$hooks_on" "${RESET}" "$(tr_msg menu_hooks_on)"
        printf " %b%2d)%b %s\n" "${PMX_ORANGE_SOFT}" "$hooks_off" "${RESET}" "$(tr_msg menu_hooks_off)"
        printf " %b%2d)%b %s\n" "${PMX_ORANGE_SOFT}" "$quit" "${RESET}" "$(tr_msg menu_quit)"
        echo

        read -r -p "$(tr_msg choose_option) [1-${quit}]: " choice
        echo

        if ! [[ "$choice" =~ ^[0-9]{1,2}$ ]]; then
            say_err "$(tr_msg invalid_choice)"
            pause
            continue
        fi
        choice=$((10#$choice))

        if ((choice == 1)); then
            run_recommended
            pause
        elif ((choice >= 2 && choice <= count + 1)); then
            entry="${TOOLS[$((choice - 2))]}"
            run_tool "${entry%%|*}" || true
        elif ((choice == hooks_on)); then
            set_all_hooks on
            pause
        elif ((choice == hooks_off)); then
            set_all_hooks off
            pause
        elif ((choice == quit)); then
            say_info "$(tr_msg bye)"
            exit 0
        else
            say_err "$(tr_msg invalid_choice)"
            pause
        fi
    done
}

require_root
require_pve
download_tools
main_menu
