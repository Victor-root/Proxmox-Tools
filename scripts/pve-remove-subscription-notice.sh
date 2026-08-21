#!/usr/bin/env bash
set -euo pipefail

PATCH_PREFIX="/root/pve-subscription-notice-patch"
PX_FILE="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"
API2TOOLS_FILE="/usr/share/perl5/PVE/API2Tools.pm"
MOBILE_GUI_DIR="/usr/share/pve-yew-mobile-gui"
APT_HOOK_FILE="/etc/apt/apt.conf.d/99-pve-remove-subscription-notice"

# Proxmox.Utils.checked_command() asks the API for the subscription status and
# only runs the requested action once the notice has been acknowledged. Running
# the action first and returning keeps every caller working (package versions,
# system report, APT refresh, repository add) while the notice never shows up.
PATCH_SED_EXPR='s/checked_command: function[[:space:]]*(orig_cmd) {/& orig_cmd(); return;/'
PATCH_MARKER='orig_cmd(); return;'
STOCK_MARKER='checked_command: function'

# The mobile interface is a separate application, compiled to WebAssembly, so
# the JavaScript patch above never reaches it. Its dashboard nags when the node
# list comes back without a support level, and that level is filled here, in one
# line of Perl. The per node subscription endpoint is left alone: the
# Subscription panel keeps reporting the truth, and nothing gets unlocked.
MOBILE_SED_EXPR='s/\$entry->{level} = \$d->\[1\];/$entry->{level} = $d->[1] || q{c};/'
MOBILE_REVERT_SED_EXPR='s/\$entry->{level} = \$d->\[1\] || q{c};/$entry->{level} = $d->[1];/'
MOBILE_MARKER='$d->[1] || q{c}'
MOBILE_STOCK_MARKER='$entry->{level} = $d->[1];'

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

        fr:menu_hook_enable) echo "Réappliquer automatiquement après une mise à jour" ;;
        en:menu_hook_enable) echo "Re-apply automatically after an update" ;;

        fr:menu_hook_disable) echo "Ne plus réappliquer automatiquement" ;;
        en:menu_hook_disable) echo "Stop re-applying automatically" ;;

        fr:menu_mobile_apply) echo "Supprimer aussi le popup sur l'interface mobile" ;;
        en:menu_mobile_apply) echo "Remove the popup on the mobile interface too" ;;

        fr:menu_mobile_restore) echo "Remettre l'interface mobile d'origine" ;;
        en:menu_mobile_restore) echo "Put the mobile interface back as it was" ;;

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

        fr:status_notice) echo "Popup d'abonnement" ;;
        en:status_notice) echo "Subscription notice" ;;

        fr:status_removed) echo "supprimé" ;;
        en:status_removed) echo "removed" ;;

        fr:status_present) echo "présent" ;;
        en:status_present) echo "present" ;;

        fr:status_auto_reapply) echo "Réapplication automatique" ;;
        en:status_auto_reapply) echo "Automatic re-apply" ;;

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

        fr:already_patched) echo "Le patch est déjà présent. Aucune modification appliquée." ;;
        en:already_patched) echo "The patch is already present. No changes applied." ;;

        fr:patch_incompatible) echo "Le code attendu n'a pas été trouvé. Cette version de Proxmox VE n'est pas prise en charge par ce patch." ;;
        en:patch_incompatible) echo "The expected code was not found. This Proxmox VE version is not supported by this patch." ;;

        fr:no_file_modified) echo "Aucun fichier n'a été modifié." ;;
        en:no_file_modified) echo "No file has been modified." ;;

        fr:patch_failed) echo "Le patch a échoué." ;;
        en:patch_failed) echo "The patch failed." ;;

        fr:hook_enabled) echo "Le patch sera réappliqué automatiquement après chaque mise à jour." ;;
        en:hook_enabled) echo "The patch will be re-applied automatically after every update." ;;

        fr:hook_disabled) echo "Réapplication automatique désactivée." ;;
        en:hook_disabled) echo "Automatic re-apply disabled." ;;

        fr:hook_already_enabled) echo "La réapplication automatique est déjà active." ;;
        en:hook_already_enabled) echo "Automatic re-apply is already active." ;;

        fr:hook_already_disabled) echo "La réapplication automatique n'est pas active." ;;
        en:hook_already_disabled) echo "Automatic re-apply is not active." ;;

        fr:hook_still_active) echo "La réapplication automatique est toujours active : le patch reviendra à la prochaine mise à jour. Utilisez l'option 7 pour la désactiver." ;;
        en:hook_still_active) echo "Automatic re-apply is still active: the patch will come back on the next update. Use option 7 to disable it." ;;

        fr:hook_file) echo "Fichier de hook APT" ;;
        en:hook_file) echo "APT hook file" ;;

        fr:missing_sed) echo "sed est requis." ;;
        en:missing_sed) echo "sed is required." ;;

        fr:missing_sha256sum) echo "sha256sum est requis." ;;
        en:missing_sha256sum) echo "sha256sum is required." ;;

        fr:warning_title) echo "AVERTISSEMENT" ;;
        en:warning_title) echo "WARNING" ;;

        fr:warning_body_1) echo "Ce script modifie un fichier JavaScript fourni par Proxmox VE." ;;
        en:warning_body_1) echo "This script modifies a JavaScript file provided by Proxmox VE." ;;

        fr:warning_body_2) echo "Ceci est hors support, sera écrasé par les mises à jour du paquet proxmox-widget-toolkit, et toute erreur de patch peut casser l'interface web jusqu'à la restauration du backup." ;;
        en:warning_body_2) echo "This is unsupported, will be overwritten by proxmox-widget-toolkit package updates, and any patching error may break the web UI until you restore the backup." ;;

        fr:warning_body_3) echo "Proxmox VE reste un logiciel libre, mais un abonnement finance son développement et donne accès au dépôt entreprise." ;;
        en:warning_body_3) echo "Proxmox VE stays free software, but a subscription funds its development and gives access to the enterprise repository." ;;

        fr:warning_body_4) echo "Veuillez garder une session SSH root active avant de continuer." ;;
        en:warning_body_4) echo "Please keep an active root SSH session open before continuing." ;;

        fr:type_yes) echo "Tapez 'yes' pour continuer" ;;
        en:type_yes) echo "Type 'yes' to continue" ;;

        fr:version_mismatch_title) echo "VERSIONS DIFFÉRENTES" ;;
        en:version_mismatch_title) echo "VERSION MISMATCH" ;;

        fr:version_mismatch_body) echo "Ce backup a été pris sur une autre version de Proxmox VE. Restaurer ce fichier sur la version actuelle peut casser l'interface web." ;;
        en:version_mismatch_body) echo "This backup was taken on a different Proxmox VE version. Restoring this file on the current version may break the web interface." ;;

        fr:version_in_backup) echo "Dans le backup" ;;
        en:version_in_backup) echo "In the backup" ;;

        fr:version_installed) echo "Installé" ;;
        en:version_installed) echo "Installed" ;;

        fr:mobile_title) echo "INTERFACE MOBILE" ;;
        en:mobile_title) echo "MOBILE INTERFACE" ;;

        fr:mobile_body_1) echo "L'interface mobile de Proxmox VE est une application distincte, compilée, que le patch de l'interface web ne touche pas." ;;
        en:mobile_body_1) echo "The Proxmox VE mobile interface is a separate, compiled application that the web interface patch does not reach." ;;

        fr:mobile_body_2) echo "Son tableau de bord affiche le popup quand la liste des nœuds ne renvoie aucun niveau de support. Ce patch remplit ce champ, en une ligne de Perl." ;;
        en:mobile_body_2) echo "Its dashboard shows the popup when the node list comes back without a support level. This patch fills that field, in one line of Perl." ;;

        fr:mobile_body_3) echo "Différence avec le patch de l'interface web : celui-ci change ce que l'API répond sur le niveau de support des nœuds. Un outil de supervision qui lit cette liste verra donc « community »." ;;
        en:mobile_body_3) echo "Difference with the web interface patch: this one changes what the API answers about the support level of the nodes. A monitoring tool reading that list will therefore see 'community'." ;;

        fr:mobile_body_4) echo "La page Subscription continue d'afficher l'absence d'abonnement, et rien n'est débloqué : le dépôt entreprise demande toujours une vraie clé." ;;
        en:mobile_body_4) echo "The Subscription panel keeps reporting that there is no subscription, and nothing is unlocked: the enterprise repository still needs a real key." ;;

        fr:mobile_applied) echo "Popup supprimé sur l'interface mobile." ;;
        en:mobile_applied) echo "Popup removed on the mobile interface." ;;

        fr:mobile_reverted) echo "Interface mobile remise dans son état d'origine." ;;
        en:mobile_reverted) echo "Mobile interface put back as it was." ;;

        fr:mobile_already_applied) echo "Le patch mobile est déjà présent. Aucune modification appliquée." ;;
        en:mobile_already_applied) echo "The mobile patch is already present. No changes applied." ;;

        fr:mobile_not_applied) echo "Le patch mobile n'est pas présent." ;;
        en:mobile_not_applied) echo "The mobile patch is not present." ;;

        fr:mobile_incompatible) echo "Le code attendu n'a pas été trouvé. Cette version de Proxmox VE n'est pas prise en charge par le patch mobile." ;;
        en:mobile_incompatible) echo "The expected code was not found. This Proxmox VE version is not supported by the mobile patch." ;;

        fr:mobile_gui_missing) echo "L'interface mobile ne semble pas installée sur cet hôte, le patch ne servira à rien ici." ;;
        en:mobile_gui_missing) echo "The mobile interface does not look installed on this host, the patch will not do anything here." ;;

        fr:mobile_reload_hint) echo "Fermez et rouvrez l'interface mobile pour voir le résultat." ;;
        en:mobile_reload_hint) echo "Close and reopen the mobile interface to see the result." ;;

        fr:status_mobile) echo "Popup sur mobile" ;;
        en:status_mobile) echo "Popup on mobile" ;;

        fr:restart_api) echo "Redémarrage de pvedaemon et pveproxy..." ;;
        en:restart_api) echo "Restarting pvedaemon and pveproxy..." ;;

        fr:banner_subtitle) echo "Subscription Notice Remover" ;;
        en:banner_subtitle) echo "Subscription Notice Remover" ;;

        fr:repo_hint) echo "Supprime le popup d'abonnement de l'interface web Proxmox VE" ;;
        en:repo_hint) echo "Removes the subscription notice from the Proxmox VE web interface" ;;

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
    command -v sed >/dev/null 2>&1 || { say_err "$(tr_msg missing_sed)"; exit 1; }
    command -v sha256sum >/dev/null 2>&1 || { say_err "$(tr_msg missing_sha256sum)"; exit 1; }
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

# ------------------------------------------------------------
# Patch state
# ------------------------------------------------------------

restart_pveproxy() {
    say_info "$(tr_msg restart_proxy)"
    printf "  %b%s%b\n" "${PMX_GREY}" "$(tr_msg restart_proxy_wait)" "${RESET}"
    systemctl restart pveproxy.service
}

restart_api_services() {
    say_info "$(tr_msg restart_api)"
    printf "  %b%s%b\n" "${PMX_GREY}" "$(tr_msg restart_proxy_wait)" "${RESET}"
    systemctl restart pvedaemon.service pveproxy.service
}

is_patched() {
    grep -qF "$PATCH_MARKER" "$PX_FILE"
}

is_patchable() {
    grep -qF "$STOCK_MARKER" "$PX_FILE"
}

apply_sed_patch() {
    sed -i "$PATCH_SED_EXPR" "$PX_FILE"
}

mobile_file_exists() {
    [[ -f "$API2TOOLS_FILE" ]]
}

mobile_is_patched() {
    mobile_file_exists && grep -qF "$MOBILE_MARKER" "$API2TOOLS_FILE"
}

mobile_is_patchable() {
    mobile_file_exists && grep -qF "$MOBILE_STOCK_MARKER" "$API2TOOLS_FILE"
}

apply_mobile_sed_patch() {
    sed -i "$MOBILE_SED_EXPR" "$API2TOOLS_FILE"
}

revert_mobile_sed_patch() {
    sed -i "$MOBILE_REVERT_SED_EXPR" "$API2TOOLS_FILE"
}

# ------------------------------------------------------------
# Backups
# ------------------------------------------------------------

latest_backup_dir() {
    find /root -maxdepth 1 -type d -name 'pve-subscription-notice-patch-*' | sort | tail -n1
}

list_backups_raw() {
    find /root -maxdepth 1 -type d -name 'pve-subscription-notice-patch-*' | sort
}

create_backup() {
    local ts dir
    ts="$(date +%F-%H%M%S)"
    dir="${PATCH_PREFIX}-${ts}"
    mkdir -p "$dir"

    cp -av "$PX_FILE" "$dir/" >/dev/null
    if mobile_file_exists; then
        cp -av "$API2TOOLS_FILE" "$dir/" >/dev/null
    fi

    {
        echo "created_at=$(date --iso-8601=seconds)"
        echo "hostname=$(hostname)"
        echo "px_file=$PX_FILE"
        if mobile_file_exists; then
            echo "api2tools_file=$API2TOOLS_FILE"
        fi
        echo
        pveversion -v 2>/dev/null || true
    } >"$dir/INFO.txt"

    sha256sum "$dir/$(basename "$PX_FILE")" >"$dir/SHA256SUMS.txt"
    if mobile_file_exists; then
        sha256sum "$dir/$(basename "$API2TOOLS_FILE")" >>"$dir/SHA256SUMS.txt"
    fi
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
# APT hook, so a package update does not silently bring the notice back
# ------------------------------------------------------------

hook_is_enabled() {
    [[ -f "$APT_HOOK_FILE" ]]
}

# The hook only carries the patches that are applied when it is written, so a
# user who never asked for the mobile one never gets it back after an update.
write_hook_file() {
    cat >"$APT_HOOK_FILE" <<EOF_HOOK
// Managed by Proxmox-Tools pve-remove-subscription-notice.sh
// Re-applies the patch when a package update restores the stock file.
DPkg::Post-Invoke {"if [ -s ${PX_FILE} ] && ! grep -q '${PATCH_MARKER}' ${PX_FILE}; then sed -i '${PATCH_SED_EXPR}' ${PX_FILE}; systemctl restart pveproxy.service >/dev/null 2>&1 || true; fi || true"; };
EOF_HOOK

    if mobile_is_patched; then
        cat >>"$APT_HOOK_FILE" <<EOF_HOOK
// Same for the mobile interface, as long as that patch stays applied.
DPkg::Post-Invoke {"if [ -s ${API2TOOLS_FILE} ] && ! grep -qF '${MOBILE_MARKER}' ${API2TOOLS_FILE}; then sed -i '${MOBILE_SED_EXPR}' ${API2TOOLS_FILE}; systemctl restart pvedaemon.service pveproxy.service >/dev/null 2>&1 || true; fi || true"; };
EOF_HOOK
    fi

    chmod 0644 "$APT_HOOK_FILE"
}

# Keep the hook in step with the patches that are actually applied.
refresh_hook_file() {
    hook_is_enabled || return 0
    write_hook_file
}

enable_hook() {
    if hook_is_enabled; then
        say_info "$(tr_msg hook_already_enabled)"
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

    rm -f "$APT_HOOK_FILE"
    say_ok "$(tr_msg hook_disabled)"
}

# ------------------------------------------------------------
# Actions
# ------------------------------------------------------------

apply_mobile_patch() {
    if mobile_is_patched; then
        say_ok "$(tr_msg mobile_already_applied)"
        return 0
    fi

    if ! mobile_is_patchable; then
        say_err "$(tr_msg mobile_incompatible)"
        say_info "$(tr_msg no_file_modified)"
        return 1
    fi

    panel "$PMX_AMBER" "$(tr_msg mobile_title)" \
        "$(tr_msg mobile_body_1)" \
        "$(tr_msg mobile_body_2)" \
        "$(tr_msg mobile_body_3)" \
        "$(tr_msg mobile_body_4)"

    [[ -d "$MOBILE_GUI_DIR" ]] || say_warn "$(tr_msg mobile_gui_missing)"

    if ! confirm_yes; then
        say_info "$(tr_msg cancelled)"
        return 0
    fi

    local backup_dir
    backup_dir="$(create_backup)"
    say_info "$(tr_msg backup_created): ${PMX_CYAN}${backup_dir}${RESET}"

    apply_mobile_sed_patch

    if ! mobile_is_patched; then
        say_err "$(tr_msg patch_failed)"
        return 1
    fi

    refresh_hook_file
    restart_api_services
    echo
    say_ok "$(tr_msg mobile_applied)"
    say_info "$(tr_msg mobile_reload_hint)"
    say_info "$(tr_msg backup_used): ${PMX_CYAN}${backup_dir}${RESET}"
}

revert_mobile_patch() {
    if ! mobile_is_patched; then
        say_info "$(tr_msg mobile_not_applied)"
        return 0
    fi

    local backup_dir
    backup_dir="$(create_backup)"
    say_info "$(tr_msg backup_created): ${PMX_CYAN}${backup_dir}${RESET}"

    revert_mobile_sed_patch

    if mobile_is_patched; then
        say_err "$(tr_msg patch_failed)"
        return 1
    fi

    refresh_hook_file
    restart_api_services
    echo
    say_ok "$(tr_msg mobile_reverted)"
    say_info "$(tr_msg mobile_reload_hint)"
}

show_status() {
    local px_version notice_state hook_state mobile_state

    px_version="$(installed_pkg_version proxmox-widget-toolkit)"

    if is_patched; then
        notice_state="${PMX_GREEN}$(tr_msg status_removed)${RESET}"
    elif is_patchable; then
        notice_state="${PMX_AMBER}$(tr_msg status_present)${RESET}"
    else
        notice_state="${PMX_RED}$(tr_msg patch_incompatible)${RESET}"
    fi

    if hook_is_enabled; then
        hook_state="${PMX_GREEN}$(tr_msg status_enabled)${RESET}"
    else
        hook_state="${PMX_GREY}$(tr_msg status_disabled)${RESET}"
    fi

    if mobile_is_patched; then
        mobile_state="${PMX_GREEN}$(tr_msg status_removed)${RESET}"
    elif mobile_is_patchable; then
        mobile_state="${PMX_AMBER}$(tr_msg status_present)${RESET}"
    else
        mobile_state="${PMX_RED}$(tr_msg mobile_incompatible)${RESET}"
    fi

    panel "$PMX_ORANGE" "$(tr_msg status_title)" \
        "$(tr_msg detected_version): proxmox-widget-toolkit ${BOLD}${px_version:-?}${RESET}" \
        "$(tr_msg status_notice): ${BOLD}${notice_state}" \
        "$(tr_msg status_mobile): ${BOLD}${mobile_state}" \
        "$(tr_msg status_auto_reapply): ${BOLD}${hook_state}"
}

apply_patch() {
    local backup_dir

    if is_patched; then
        say_ok "$(tr_msg already_patched)"
        return 0
    fi

    if ! is_patchable; then
        say_err "$(tr_msg patch_incompatible)"
        say_info "$(tr_msg no_file_modified)"
        return 1
    fi

    show_warning_and_confirm || return 0

    backup_dir="$(create_backup)"
    say_info "$(tr_msg backup_created): ${PMX_CYAN}${backup_dir}${RESET}"

    apply_sed_patch

    if ! is_patched; then
        say_err "$(tr_msg patch_failed)"
        return 1
    fi

    restart_pveproxy
    echo
    say_ok "$(tr_msg patch_applied)"
    say_info "$(tr_msg hard_refresh)"
    say_info "$(tr_msg backup_used): ${PMX_CYAN}${backup_dir}${RESET}"
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
    local saved_api2tools
    [[ -d "$dir" ]] || { say_err "$(tr_msg file_not_found): $dir"; return 1; }
    [[ -f "$dir/$(basename "$PX_FILE")" ]] || { say_err "$(tr_msg file_not_found): $dir/$(basename "$PX_FILE")"; return 1; }

    confirm_backup_versions "$dir" || return 0

    cp -av "$dir/$(basename "$PX_FILE")" "$PX_FILE"

    # Backups taken before the mobile patch existed only hold the JavaScript
    # file, so the Perl one is restored only when the backup carries it.
    saved_api2tools="$dir/$(basename "$API2TOOLS_FILE")"
    if [[ -f "$saved_api2tools" ]] && mobile_file_exists; then
        cp -av "$saved_api2tools" "$API2TOOLS_FILE"
        refresh_hook_file
        restart_api_services
    else
        restart_pveproxy
    fi

    say_ok "$(tr_msg restore_done): ${PMX_CYAN}${dir}${RESET}"

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
        printf " %b6)%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$(tr_msg menu_hook_enable)"
        printf " %b7)%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$(tr_msg menu_hook_disable)"
        printf " %b8)%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$(tr_msg menu_mobile_apply)"
        printf " %b9)%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$(tr_msg menu_mobile_restore)"
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
                menu_action enable_hook
                pause
                ;;
            7)
                menu_action disable_hook
                pause
                ;;
            8)
                menu_action apply_mobile_patch
                pause
                ;;
            9)
                menu_action revert_mobile_patch
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
