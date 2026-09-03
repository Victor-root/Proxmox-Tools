#!/usr/bin/env bash
set -euo pipefail

PATCH_PREFIX="/root/pve-console-newtab-patch"
PM_FILE="/usr/share/pve-manager/js/pvemanagerlib.js"
PX_FILE="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"

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

        fr:menu_tree) echo "Ajouter le clic molette sur les VM/LXC de l'arborescence" ;;
        en:menu_tree) echo "Add the middle click on the VM/LXC of the resource tree" ;;

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

        fr:hard_refresh) echo "Un hard refresh du navigateur est recommandé." ;;
        en:hard_refresh) echo "A hard refresh in your browser is recommended." ;;

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

        fr:available_backups) echo "Backups disponibles" ;;
        en:available_backups) echo "Available backups" ;;

        fr:choose_backup_number) echo "Choisissez le numéro du backup à restaurer" ;;
        en:choose_backup_number) echo "Choose a backup number to restore" ;;

        fr:bye) echo "À bientôt." ;;
        en:bye) echo "Bye." ;;

        fr:already_patched) echo "Le patch est déjà présent sur les deux fichiers. Aucune modification appliquée." ;;
        en:already_patched) echo "The patch is already present in both files. No changes applied." ;;

        fr:patch_incompatible) echo "Les blocs de code attendus n'ont pas été trouvés. Cette version de Proxmox VE n'est pas prise en charge par ce patch." ;;
        en:patch_incompatible) echo "The expected code blocks were not found. This Proxmox VE version is not supported by this patch." ;;

        fr:no_file_modified) echo "Aucun fichier n'a été modifié." ;;
        en:no_file_modified) echo "No file has been modified." ;;

        fr:patch_failed) echo "Le patch a échoué." ;;
        en:patch_failed) echo "The patch failed." ;;

        fr:tree_title) echo "CLIC MOLETTE DANS L'ARBORESCENCE" ;;
        en:tree_title) echo "MIDDLE CLICK IN THE RESOURCE TREE" ;;

        fr:tree_body_1) echo "Ajoute le clic molette sur une VM ou un conteneur de la liste de gauche : la console s'ouvre dans un nouvel onglet." ;;
        en:tree_body_1) echo "Adds the middle click on a VM or a container of the left list: its console opens in a new tab." ;;

        fr:tree_body_2) echo "C'est la console que Proxmox VE ouvre déjà sur un double clic, avec le même choix de visualiseur, mais dans un onglet plutôt que dans une fenêtre." ;;
        en:tree_body_2) echo "This is the console Proxmox VE already opens on a double click, with the same viewer choice, but in a tab instead of a window." ;;

        fr:tree_body_3) echo "Le clic molette ne fait rien aujourd'hui dans cette liste, et la sélection en cours n'est pas modifiée. Les modèles, les nœuds et les stockages restent sans effet." ;;
        en:tree_body_3) echo "The middle click does nothing in that list today, and the current selection is left alone. Templates, nodes and storages stay without effect." ;;

        fr:tree_needs_console) echo "Ce patch a besoin du patch principal, qui apporte l'ouverture en onglet. Utilisez l'option 1 d'abord." ;;
        en:tree_needs_console) echo "This patch needs the main patch, which brings the opening in a tab. Use option 1 first." ;;

        fr:tree_already_patched) echo "Le clic molette dans l'arborescence est déjà en place. Aucune modification appliquée." ;;
        en:tree_already_patched) echo "The middle click in the resource tree is already in place. No changes applied." ;;

        fr:tree_applied) echo "Clic molette ajouté dans l'arborescence." ;;
        en:tree_applied) echo "Middle click added in the resource tree." ;;

        fr:detected_version) echo "Version détectée" ;;
        en:detected_version) echo "Detected version" ;;

        fr:version_mismatch_title) echo "VERSIONS DIFFÉRENTES" ;;
        en:version_mismatch_title) echo "VERSION MISMATCH" ;;

        fr:version_mismatch_body) echo "Ce backup a été pris sur une autre version de Proxmox VE. Restaurer ces fichiers sur la version actuelle peut casser l'interface web." ;;
        en:version_mismatch_body) echo "This backup was taken on a different Proxmox VE version. Restoring these files on the current version may break the web interface." ;;

        fr:version_in_backup) echo "Dans le backup" ;;
        en:version_in_backup) echo "In the backup" ;;

        fr:version_installed) echo "Installé" ;;
        en:version_installed) echo "Installed" ;;

        fr:missing_python) echo "python3 est requis." ;;
        en:missing_python) echo "python3 is required." ;;

        fr:missing_sha256sum) echo "sha256sum est requis." ;;
        en:missing_sha256sum) echo "sha256sum is required." ;;

        fr:warning_title) echo "AVERTISSEMENT" ;;
        en:warning_title) echo "WARNING" ;;

        fr:warning_body_1) echo "Ce script modifie des fichiers JavaScript fournis par Proxmox VE." ;;
        en:warning_body_1) echo "This script modifies JavaScript files provided by Proxmox VE." ;;

        fr:warning_body_2) echo "Ceci est hors support, peut être écrasé par de futures mises à jour, et toute erreur de patch peut casser l'interface web jusqu'à la restauration du backup." ;;
        en:warning_body_2) echo "This is unsupported, may be overwritten by future updates, and any patching error may break the web UI until you restore the backup." ;;

        fr:warning_body_3) echo "Veuillez garder une session SSH root active avant de continuer." ;;
        en:warning_body_3) echo "Please keep an active root SSH session open before continuing." ;;

        fr:type_yes) echo "Tapez 'yes' pour continuer" ;;
        en:type_yes) echo "Type 'yes' to continue" ;;

        fr:banner_subtitle) echo "Console New Tab Patch Utility" ;;
        en:banner_subtitle) echo "Console New Tab Patch Utility" ;;

        fr:repo_hint) echo "Patch interactif pour l'interface web Proxmox VE" ;;
        en:repo_hint) echo "Interactive patch utility for the Proxmox VE web interface" ;;

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
    DIM='\033[2m'

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
    DIM=''

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

rule() { hr; }

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

require_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        say_err "$(tr_msg running_as_root)"
        exit 1
    fi
}

require_files() {
    [[ -f "$PM_FILE" ]] || { say_err "$(tr_msg file_not_found): $PM_FILE"; exit 1; }
    [[ -f "$PX_FILE" ]] || { say_err "$(tr_msg file_not_found): $PX_FILE"; exit 1; }
    command -v python3 >/dev/null 2>&1 || { say_err "$(tr_msg missing_python)"; exit 1; }
    command -v sha256sum >/dev/null 2>&1 || { say_err "$(tr_msg missing_sha256sum)"; exit 1; }
}

confirm_yes() {
    echo
    printf "%b?%b %b%s%b : " "${PMX_AMBER}" "${RESET}" "${BOLD}" "$(tr_msg type_yes)" "${RESET}"
    read -r answer
    [[ "$answer" == "yes" ]]
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

restart_pveproxy() {
    say_info "$(tr_msg restart_proxy)"
    printf "  %b%s%b\n" "${PMX_GREY}" "$(tr_msg restart_proxy_wait)" "${RESET}"
    systemctl restart pveproxy.service
}

latest_backup_dir() {
    find /root -maxdepth 1 -type d -name 'pve-console-newtab-patch-*' | sort | tail -n1
}

list_backups_raw() {
    find /root -maxdepth 1 -type d -name 'pve-console-newtab-patch-*' | sort
}

create_backup() {
    local ts dir
    ts="$(date +%F-%H%M%S)"
    dir="${PATCH_PREFIX}-${ts}"
    mkdir -p "$dir"

    cp -av "$PM_FILE" "$dir/" >/dev/null
    cp -av "$PX_FILE" "$dir/" >/dev/null

    {
        echo "created_at=$(date --iso-8601=seconds)"
        echo "hostname=$(hostname)"
        echo "pm_file=$PM_FILE"
        echo "px_file=$PX_FILE"
        echo
        pveversion -v 2>/dev/null || true
    } >"$dir/INFO.txt"

    sha256sum "$dir/$(basename "$PM_FILE")" "$dir/$(basename "$PX_FILE")" >"$dir/SHA256SUMS.txt"
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

# Single patch engine shared by the status view, the pre-flight check and the
# patch itself. Modes: status (report only), check (dry run), apply (write).
# Each file is inspected and patched on its own, so a Proxmox update that only
# refreshes one of the two packages can still be re-patched.
# Exit codes: 0 work to do or done, 10 nothing to do, 11 needs the main patch
# first, 1 unsupported layout.
run_patch_tool() {
    local mode="$1"
    local target="${2:-console}"
    PM_FILE="$PM_FILE" PX_FILE="$PX_FILE" PATCH_MODE="$mode" PATCH_TARGET="$target" python3 <<'PY'
from pathlib import Path
import os
import sys

MODE = os.environ["PATCH_MODE"]
TARGET = os.environ.get("PATCH_TARGET", "console")

pm_path = Path(os.environ["PM_FILE"])
px_path = Path(os.environ["PX_FILE"])

pm = pm_path.read_text(encoding="utf-8")
px = px_path.read_text(encoding="utf-8")

NEWTAB_OPT = "opts && opts.newTab"
PM_SIG_DEFAULT = "openDefaultConsoleWindow: function (consoles, consoleType, vmid, nodename, vmname, cmd, opts)"
PM_SIG_CONSOLE = "openConsoleWindow: function (viewer, consoleType, vmid, nodename, vmname, cmd, opts)"
PM_SIG_VNC = "openVNCViewer: function (vmtype, vmid, nodename, vmname, cmd, opts)"
PX_SIG_XTERM = "openXtermJsViewer: function (vmtype, vmid, nodename, vmname, cmd, opts)"
PM_SIG_TREE = "openTreeConsole: function (tree, record, item, index, e, consoleOpts)"
TREE_CALL = "PVE.Utils.openTreeConsole(tree, record, td, rowIndex, ev, { newTab: true });"


def pm_markers(text):
    return [
        ("PVE.Utils.openDefaultConsoleWindow(opts)", PM_SIG_DEFAULT in text),
        ("PVE.Utils.openConsoleWindow(opts)", PM_SIG_CONSOLE in text),
        ("PVE.Utils.openVNCViewer(opts)", PM_SIG_VNC in text),
        ("ConsoleButton middle click", "openDefaultConsoleNewTab: function ()" in text),
        ("ConsoleButton menu new tab", "openConsoleNewTab: function (types)" in text),
        ("noVNC and xterm.js middle click", text.count("view.openConsoleNewTab(item.type);") == 2),
        ("SPICE middle click", "view.openConsole(item.type);" in text),
        ("new tab option", NEWTAB_OPT in text),
    ]


def px_markers(text):
    return [
        ("Proxmox.Utils.openXtermJsViewer(opts)", PX_SIG_XTERM in text),
        ("new tab option", NEWTAB_OPT in text),
    ]


def tree_markers(text):
    return [
        ("PVE.Utils.openTreeConsole(consoleOpts)", PM_SIG_TREE in text),
        ("resource tree middle click", TREE_CALL in text),
    ]


def is_patched(markers):
    return all(ok for _, ok in markers)


if MODE == "status":
    for path, markers in ((pm_path, pm_markers(pm)), (px_path, px_markers(px))):
        print(f" {path.name}: {'PATCHED' if is_patched(markers) else 'STOCK_OR_PARTIAL'}")
        for label, ok in markers:
            print(f"   - {label}: {'OK' if ok else 'MISSING'}")
        print()

    markers = tree_markers(pm)
    print(f" resource tree: {'PATCHED' if is_patched(markers) else 'STOCK_OR_PARTIAL'}")
    for label, ok in markers:
        print(f"   - {label}: {'OK' if ok else 'MISSING'}")
    print()
    sys.exit(0)


def replace_once(text, old, new, label, filename):
    if old not in text:
        raise SystemExit(f"[ERROR] {filename}: code block not found for {label}")
    return text.replace(old, new, 1)

def replace_object_by_anchor(text, anchor, replacement):
    idx = text.find(anchor)
    if idx == -1:
        raise SystemExit(f"[ERROR] {pm_path.name}: anchor not found: {anchor}")

    start = text.rfind("        {", 0, idx)
    if start == -1:
        raise SystemExit(f"[ERROR] {pm_path.name}: object start not found for anchor: {anchor}")

    i = start
    depth = 0
    in_quote = None
    escaped = False

    while i < len(text):
        ch = text[i]
        if in_quote is not None:
            if escaped:
                escaped = False
            elif ch == '\\':
                escaped = True
            elif ch == in_quote:
                in_quote = None
        else:
            if ch in ('"', "'"):
                in_quote = ch
            elif ch == '{':
                depth += 1
            elif ch == '}':
                depth -= 1
                if depth == 0:
                    end = i + 1
                    if end < len(text) and text[end] == ',':
                        end += 1
                    return text[:start] + replacement + text[end:]
        i += 1

    raise SystemExit(f"[ERROR] {pm_path.name}: object end not found for anchor: {anchor}")

def replace_consolebutton_methods(text):
    class_anchor = "Ext.define('PVE.button.ConsoleButton', {"
    start_anchor = "    handler: function () {"
    end_anchor = "    menu: ["

    class_pos = text.find(class_anchor)
    if class_pos == -1:
        raise SystemExit(f"[ERROR] {pm_path.name}: ConsoleButton class not found")

    start = text.find(start_anchor, class_pos)
    if start == -1:
        raise SystemExit(f"[ERROR] {pm_path.name}: ConsoleButton handler block not found")

    end = text.find(end_anchor, start)
    if end == -1:
        raise SystemExit(f"[ERROR] {pm_path.name}: ConsoleButton menu block not found")

    replacement = """    handler: function () {
        // main, general, handler
        let me = this;
        PVE.Utils.openDefaultConsoleWindow(
            {
                spice: me.enableSpice,
                xtermjs: me.enableXtermjs,
            },
            me.consoleType,
            me.vmid,
            me.nodename,
            me.consoleName,
            me.cmd,
        );
    },

    listeners: {
        afterrender: function (btn) {
            btn.getEl().on('mousedown', function (e) {
                let mouseButton = (e.browserEvent && e.browserEvent.button !== undefined)
                    ? e.browserEvent.button
                    : e.button;

                if (mouseButton !== 1) {
                    return;
                }

                e.stopEvent();
                btn.openDefaultConsoleNewTab();
            });
        },
    },

    openDefaultConsoleNewTab: function () {
        let me = this;
        PVE.Utils.openDefaultConsoleWindow(
            {
                spice: me.enableSpice,
                xtermjs: me.enableXtermjs,
            },
            me.consoleType,
            me.vmid,
            me.nodename,
            me.consoleName,
            me.cmd,
            { newTab: true },
        );
    },

    openConsole: function (types) {
        // used by split-menu buttons
        let me = this;
        PVE.Utils.openConsoleWindow(
            types,
            me.consoleType,
            me.vmid,
            me.nodename,
            me.consoleName,
            me.cmd,
        );
    },

    openConsoleNewTab: function (types) {
        let me = this;
        PVE.Utils.openConsoleWindow(
            types,
            me.consoleType,
            me.vmid,
            me.nodename,
            me.consoleName,
            me.cmd,
            { newTab: true },
        );
    },

"""
    return text[:start] + replacement + text[end:]

def patch_pm(text):
    text = replace_once(
        text,
"""        openDefaultConsoleWindow: function (consoles, consoleType, vmid, nodename, vmname, cmd) {
            var dv = PVE.Utils.defaultViewer(consoles, consoleType);
            PVE.Utils.openConsoleWindow(dv, consoleType, vmid, nodename, vmname, cmd);
        },
""",
"""        openDefaultConsoleWindow: function (consoles, consoleType, vmid, nodename, vmname, cmd, opts) {
            var dv = PVE.Utils.defaultViewer(consoles, consoleType);
            PVE.Utils.openConsoleWindow(dv, consoleType, vmid, nodename, vmname, cmd, opts);
        },
""",
        "openDefaultConsoleWindow",
        pm_path.name,
    )

    text = replace_once(
        text,
"""        openConsoleWindow: function (viewer, consoleType, vmid, nodename, vmname, cmd) {
            if (vmid === undefined && (consoleType === 'kvm' || consoleType === 'lxc')) {
                throw 'missing vmid';
            }
            if (!nodename) {
                throw 'no nodename specified';
            }

            if (viewer === 'html5') {
                PVE.Utils.openVNCViewer(consoleType, vmid, nodename, vmname, cmd);
            } else if (viewer === 'xtermjs') {
                Proxmox.Utils.openXtermJsViewer(consoleType, vmid, nodename, vmname, cmd);
            } else if (viewer === 'vv') {
                let url = '/nodes/' + nodename + '/spiceshell';
                let params = {
                    proxy: PVE.Utils.windowHostname(),
                };
                if (consoleType === 'kvm') {
                    url = '/nodes/' + nodename + '/qemu/' + vmid.toString() + '/spiceproxy';
                } else if (consoleType === 'lxc') {
                    url = '/nodes/' + nodename + '/lxc/' + vmid.toString() + '/spiceproxy';
                } else if (consoleType === 'upgrade') {
                    params.cmd = 'upgrade';
                } else if (consoleType === 'cmd') {
                    params.cmd = cmd;
                } else if (consoleType !== 'shell') {
                    throw `unknown spice viewer type '${consoleType}'`;
                }
                PVE.Utils.openSpiceViewer(url, params);
            } else {
                throw `unknown viewer type '${viewer}'`;
            }
        },
""",
"""        openConsoleWindow: function (viewer, consoleType, vmid, nodename, vmname, cmd, opts) {
            if (vmid === undefined && (consoleType === 'kvm' || consoleType === 'lxc')) {
                throw 'missing vmid';
            }
            if (!nodename) {
                throw 'no nodename specified';
            }

            if (viewer === 'html5') {
                PVE.Utils.openVNCViewer(consoleType, vmid, nodename, vmname, cmd, opts);
            } else if (viewer === 'xtermjs') {
                Proxmox.Utils.openXtermJsViewer(consoleType, vmid, nodename, vmname, cmd, opts);
            } else if (viewer === 'vv') {
                let url = '/nodes/' + nodename + '/spiceshell';
                let params = {
                    proxy: PVE.Utils.windowHostname(),
                };
                if (consoleType === 'kvm') {
                    url = '/nodes/' + nodename + '/qemu/' + vmid.toString() + '/spiceproxy';
                } else if (consoleType === 'lxc') {
                    url = '/nodes/' + nodename + '/lxc/' + vmid.toString() + '/spiceproxy';
                } else if (consoleType === 'upgrade') {
                    params.cmd = 'upgrade';
                } else if (consoleType === 'cmd') {
                    params.cmd = cmd;
                } else if (consoleType !== 'shell') {
                    throw `unknown spice viewer type '${consoleType}'`;
                }
                PVE.Utils.openSpiceViewer(url, params);
            } else {
                throw `unknown viewer type '${viewer}'`;
            }
        },
""",
        "openConsoleWindow",
        pm_path.name,
    )

    text = replace_once(
        text,
"""        openVNCViewer: function (vmtype, vmid, nodename, vmname, cmd) {
            let scaling = 'off';
            if (Proxmox.Utils.toolkit !== 'touch') {
                let sp = Ext.state.Manager.getProvider();
                scaling = sp.get('novnc-scaling', 'off');
            }
            var url = Ext.Object.toQueryString({
                console: vmtype, // kvm, lxc, upgrade or shell
                novnc: 1,
                vmid: vmid,
                vmname: vmname,
                node: nodename,
                resize: scaling,
                cmd: cmd,
            });
            var nw = window.open('?' + url, '_blank', 'innerWidth=745,innerheight=427');
            if (nw) {
                nw.focus();
            }
        },
""",
"""        openVNCViewer: function (vmtype, vmid, nodename, vmname, cmd, opts) {
            let scaling = 'off';
            if (Proxmox.Utils.toolkit !== 'touch') {
                let sp = Ext.state.Manager.getProvider();
                scaling = sp.get('novnc-scaling', 'off');
            }
            var url = Ext.Object.toQueryString({
                console: vmtype, // kvm, lxc, upgrade or shell
                novnc: 1,
                vmid: vmid,
                vmname: vmname,
                node: nodename,
                resize: scaling,
                cmd: cmd,
            });
            var nw;
            if (opts && opts.newTab) {
                nw = window.open('?' + url, '_blank');
            } else {
                nw = window.open('?' + url, '_blank', 'innerWidth=745,innerheight=427');
            }
            if (nw) {
                nw.focus();
            }
        },
""",
        "openVNCViewer",
        pm_path.name,
    )

    text = replace_consolebutton_methods(text)

    text = replace_object_by_anchor(
        text,
        "iconCls: 'pve-itype-icon-novnc'",
        """        {
            xtype: 'menuitem',
            text: 'noVNC',
            iconCls: 'pve-itype-icon-novnc',
            type: 'html5',
            handler: function (button) {
                let view = this.up('button');
                view.openConsole(button.type);
            },
            listeners: {
                afterrender: function (item) {
                    item.getEl().on('mousedown', function (e) {
                        let mouseButton = (e.browserEvent && e.browserEvent.button !== undefined)
                            ? e.browserEvent.button
                            : e.button;

                        if (mouseButton !== 1) {
                            return;
                        }

                        let view = item.up('button');
                        if (!view) {
                            return;
                        }

                        let menu = item.up('menu');
                        if (menu) {
                            menu.hide();
                        }

                        e.stopEvent();
                        view.openConsoleNewTab(item.type);
                    });
                },
            },
        },""",
    )

    text = replace_object_by_anchor(
        text,
        "itemId: 'xtermjs'",
        """        {
            text: 'xterm.js',
            itemId: 'xtermjs',
            iconCls: 'pve-itype-icon-xtermjs',
            type: 'xtermjs',
            handler: function (button) {
                let view = this.up('button');
                view.openConsole(button.type);
            },
            listeners: {
                afterrender: function (item) {
                    item.getEl().on('mousedown', function (e) {
                        let mouseButton = (e.browserEvent && e.browserEvent.button !== undefined)
                            ? e.browserEvent.button
                            : e.button;

                        if (mouseButton !== 1) {
                            return;
                        }

                        let view = item.up('button');
                        if (!view) {
                            return;
                        }

                        let menu = item.up('menu');
                        if (menu) {
                            menu.hide();
                        }

                        e.stopEvent();
                        view.openConsoleNewTab(item.type);
                    });
                },
            },
        },""",
    )

    text = replace_object_by_anchor(
        text,
        "itemId: 'spicemenu'",
        """        {
            xtype: 'menuitem',
            itemId: 'spicemenu',
            text: 'SPICE',
            type: 'vv',
            iconCls: 'pve-itype-icon-virt-viewer',
            handler: function (button) {
                let view = this.up('button');
                view.openConsole(button.type);
            },
            listeners: {
                afterrender: function (item) {
                    item.getEl().on('mousedown', function (e) {
                        let mouseButton = (e.browserEvent && e.browserEvent.button !== undefined)
                            ? e.browserEvent.button
                            : e.button;

                        if (mouseButton !== 1) {
                            return;
                        }

                        let view = item.up('button');
                        if (!view) {
                            return;
                        }

                        let menu = item.up('menu');
                        if (menu) {
                            menu.hide();
                        }

                        e.stopEvent();
                        view.openConsole(item.type);
                    });
                },
            },
        },""",
    )

    return text


def patch_px(text):
    return replace_once(
        text,
"""        openXtermJsViewer: function (vmtype, vmid, nodename, vmname, cmd) {
            let url = Ext.Object.toQueryString({
                console: vmtype, // kvm, lxc, upgrade or shell
                xtermjs: 1,
                vmid: vmid,
                vmname: vmname,
                node: nodename,
                cmd: cmd,
            });
            let nw = window.open(
                '?' + url,
                '_blank',
                'toolbar=no,location=no,status=no,menubar=no,resizable=yes,width=800,height=420',
            );
            if (nw) {
                nw.focus();
            }
        },
""",
"""        openXtermJsViewer: function (vmtype, vmid, nodename, vmname, cmd, opts) {
            let url = Ext.Object.toQueryString({
                console: vmtype, // kvm, lxc, upgrade or shell
                xtermjs: 1,
                vmid: vmid,
                vmname: vmname,
                node: nodename,
                cmd: cmd,
            });
            let nw;
            if (opts && opts.newTab) {
                nw = window.open('?' + url, '_blank');
            } else {
                nw = window.open(
                    '?' + url,
                    '_blank',
                    'toolbar=no,location=no,status=no,menubar=no,resizable=yes,width=800,height=420',
                );
            }
            if (nw) {
                nw.focus();
            }
        },
""",
        "openXtermJsViewer",
        px_path.name,
    )


def patch_tree(text):
    text = replace_once(
        text,
"""        openTreeConsole: function (tree, record, item, index, e) {
            e.stopEvent();
            let nodename = record.data.node;
            let vmid = record.data.vmid;
            let vmname = record.data.name;
            if (record.data.type === 'qemu' && !record.data.template) {
                Proxmox.Utils.API2Request({
                    url: `/nodes/${nodename}/qemu/${vmid}/status/current`,
                    failure: (response) => Ext.Msg.alert('Error', response.htmlStatus),
                    success: function (response, opts) {
                        let conf = response.result.data;
                        let consoles = {
                            spice: !!conf.spice,
                            xtermjs: !!conf.serial,
                        };
                        PVE.Utils.openDefaultConsoleWindow(consoles, 'kvm', vmid, nodename, vmname);
                    },
                });
            } else if (record.data.type === 'lxc' && !record.data.template) {
                PVE.Utils.openDefaultConsoleWindow(true, 'lxc', vmid, nodename, vmname);
            }
        },
""",
"""        openTreeConsole: function (tree, record, item, index, e, consoleOpts) {
            e.stopEvent();
            let nodename = record.data.node;
            let vmid = record.data.vmid;
            let vmname = record.data.name;
            if (record.data.type === 'qemu' && !record.data.template) {
                Proxmox.Utils.API2Request({
                    url: `/nodes/${nodename}/qemu/${vmid}/status/current`,
                    failure: (response) => Ext.Msg.alert('Error', response.htmlStatus),
                    success: function (response, opts) {
                        let conf = response.result.data;
                        let consoles = {
                            spice: !!conf.spice,
                            xtermjs: !!conf.serial,
                        };
                        PVE.Utils.openDefaultConsoleWindow(
                            consoles,
                            'kvm',
                            vmid,
                            nodename,
                            vmname,
                            undefined,
                            consoleOpts,
                        );
                    },
                });
            } else if (record.data.type === 'lxc' && !record.data.template) {
                PVE.Utils.openDefaultConsoleWindow(
                    true,
                    'lxc',
                    vmid,
                    nodename,
                    vmname,
                    undefined,
                    consoleOpts,
                );
            }
        },
""",
        "openTreeConsole",
        pm_path.name,
    )

    return replace_once(
        text,
"""                beforecellmousedown: function (tree, td, cellIndex, record, tr, rowIndex, ev) {
                    let sm = me.getSelectionModel();
                    // disable selection when right clicking except if the record is already selected
                    me.allowSelection = ev.button !== 2 || sm.isSelected(record);
                },
""",
"""                beforecellmousedown: function (tree, td, cellIndex, record, tr, rowIndex, ev) {
                    let sm = me.getSelectionModel();
                    // disable selection when right clicking except if the record is already selected
                    me.allowSelection = ev.button !== 2 || sm.isSelected(record);

                    // middle click opens the console of a guest in a new tab, the
                    // same way a double click opens it in a window, and leaves the
                    // current selection alone
                    if (ev.button === 1 && record) {
                        PVE.Utils.openTreeConsole(tree, record, td, rowIndex, ev, { newTab: true });
                        return false;
                    }
                },
""",
        "resource tree middle click",
        pm_path.name,
    )


if TARGET == "tree":
    if is_patched(tree_markers(pm)):
        sys.exit(10)

    # The new tab itself comes from the console patch, which adds the option to
    # openDefaultConsoleWindow and to everything it calls.
    if not is_patched(pm_markers(pm)) or not is_patched(px_markers(px)):
        sys.exit(11)

    pm = patch_tree(pm)

    if MODE == "apply":
        pm_path.write_text(pm, encoding="utf-8")
        print(f"[OK] patched: {pm_path}")

    sys.exit(0)


pm_done = is_patched(pm_markers(pm))
px_done = is_patched(px_markers(px))

if pm_done and px_done:
    sys.exit(10)

if not pm_done:
    pm = patch_pm(pm)
if not px_done:
    px = patch_px(px)

if MODE == "apply":
    for path, text, done in ((pm_path, pm, pm_done), (px_path, px, px_done)):
        if not done:
            path.write_text(text, encoding="utf-8")
            print(f"[OK] patched: {path}")
PY
}

show_status() {
    local pm_version px_version
    pm_version="$(installed_pkg_version pve-manager)"
    px_version="$(installed_pkg_version proxmox-widget-toolkit)"

    panel "$PMX_ORANGE" "$(tr_msg status_title)" \
        "$(tr_msg detected_version): pve-manager ${BOLD}${pm_version:-?}${RESET} · proxmox-widget-toolkit ${BOLD}${px_version:-?}${RESET}"
    echo
    run_patch_tool status
}

apply_patch() {
    local backup_dir rc=0

    run_patch_tool check || rc=$?

    if [[ "$rc" -eq 10 ]]; then
        say_ok "$(tr_msg already_patched)"
        return 0
    fi

    if [[ "$rc" -ne 0 ]]; then
        say_err "$(tr_msg patch_incompatible)"
        say_info "$(tr_msg no_file_modified)"
        return 1
    fi

    show_warning_and_confirm || return 0

    backup_dir="$(create_backup)"
    say_info "$(tr_msg backup_created): ${PMX_CYAN}${backup_dir}${RESET}"

    rc=0
    run_patch_tool apply || rc=$?

    if [[ "$rc" -ne 0 ]]; then
        say_err "$(tr_msg patch_failed)"
        say_info "$(tr_msg no_file_modified)"
        return 1
    fi

    restart_pveproxy
    echo
    say_ok "$(tr_msg patch_applied)"
    say_info "$(tr_msg hard_refresh)"
    say_info "$(tr_msg backup_used): ${PMX_CYAN}${backup_dir}${RESET}"
}

apply_tree_patch() {
    local backup_dir rc=0

    run_patch_tool check tree || rc=$?

    if [[ "$rc" -eq 10 ]]; then
        say_ok "$(tr_msg tree_already_patched)"
        return 0
    fi

    if [[ "$rc" -eq 11 ]]; then
        say_err "$(tr_msg tree_needs_console)"
        say_info "$(tr_msg no_file_modified)"
        return 1
    fi

    if [[ "$rc" -ne 0 ]]; then
        say_err "$(tr_msg patch_incompatible)"
        say_info "$(tr_msg no_file_modified)"
        return 1
    fi

    panel "$PMX_BLUE" "$(tr_msg tree_title)" \
        "$(tr_msg tree_body_1)" \
        "$(tr_msg tree_body_2)" \
        "$(tr_msg tree_body_3)"

    if ! confirm_yes; then
        say_info "$(tr_msg cancelled)"
        return 0
    fi

    backup_dir="$(create_backup)"
    say_info "$(tr_msg backup_created): ${PMX_CYAN}${backup_dir}${RESET}"

    rc=0
    run_patch_tool apply tree || rc=$?

    if [[ "$rc" -ne 0 ]]; then
        say_err "$(tr_msg patch_failed)"
        say_info "$(tr_msg no_file_modified)"
        return 1
    fi

    restart_pveproxy
    echo
    say_ok "$(tr_msg tree_applied)"
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
    [[ -d "$dir" ]] || { say_err "$(tr_msg file_not_found): $dir"; return 1; }
    [[ -f "$dir/$(basename "$PM_FILE")" ]] || { say_err "$(tr_msg file_not_found): $dir/$(basename "$PM_FILE")"; return 1; }
    [[ -f "$dir/$(basename "$PX_FILE")" ]] || { say_err "$(tr_msg file_not_found): $dir/$(basename "$PX_FILE")"; return 1; }

    confirm_backup_versions "$dir" || return 0

    cp -av "$dir/$(basename "$PM_FILE")" "$PM_FILE"
    cp -av "$dir/$(basename "$PX_FILE")" "$PX_FILE"

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
        printf " %b6)%b %s\n" "${PMX_ORANGE_SOFT}" "${RESET}" "$(tr_msg menu_tree)"
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
                menu_action apply_tree_patch
                pause
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
