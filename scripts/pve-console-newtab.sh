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

        fr:overall_patched) echo "PATCHED" ;;
        en:overall_patched) echo "PATCHED" ;;

        fr:overall_partial) echo "STOCK_OR_PARTIAL" ;;
        en:overall_partial) echo "STOCK_OR_PARTIAL" ;;

        fr:available_backups) echo "Backups disponibles" ;;
        en:available_backups) echo "Available backups" ;;

        fr:choose_backup_number) echo "Choisissez le numéro du backup à restaurer" ;;
        en:choose_backup_number) echo "Choose a backup number to restore" ;;

        fr:bye) echo "À bientôt." ;;
        en:bye) echo "Bye." ;;

        fr:already_patched) echo "Le patch semble déjà présent. Aucune modification appliquée." ;;
        en:already_patched) echo "The patch already appears to be present. No changes applied." ;;

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

# ------------------------------------------------------------
# Colors (Proxmox-inspired)
# ------------------------------------------------------------

if [[ -t 1 ]]; then
    RESET='\033[0m'
    BOLD='\033[1m'
    DIM='\033[2m'

    PMX_ORANGE='\033[38;2;230;106;0m'
    PMX_ORANGE_SOFT='\033[38;2;255;167;79m'
    PMX_RED='\033[38;2;181;56;44m'
    PMX_GREEN='\033[38;2;78;154;6m'
    PMX_BLUE='\033[38;2;52;101;164m'
    PMX_GREY='\033[38;2;120;120;120m'
    PMX_WHITE='\033[38;2;245;245;245m'
else
    RESET=''
    BOLD=''
    DIM=''

    PMX_ORANGE=''
    PMX_ORANGE_SOFT=''
    PMX_RED=''
    PMX_GREEN=''
    PMX_BLUE=''
    PMX_GREY=''
    PMX_WHITE=''
fi

icon_info()  { printf "%bℹ%b"  "$PMX_BLUE" "$RESET"; }
icon_ok()    { printf "%b✔%b"  "$PMX_GREEN" "$RESET"; }
icon_warn()  { printf "%b⚠%b"  "$PMX_ORANGE" "$RESET"; }
icon_err()   { printf "%b✖%b"  "$PMX_RED" "$RESET"; }
icon_arrow() { printf "%b➜%b"  "$PMX_ORANGE_SOFT" "$RESET"; }

say_info() { echo -e "$(icon_info) ${PMX_WHITE}$*${RESET}"; }
say_ok()   { echo -e "$(icon_ok) ${PMX_WHITE}$*${RESET}"; }
say_warn() { echo -e "$(icon_warn) ${PMX_WHITE}$*${RESET}"; }
say_err()  { echo -e "$(icon_err) ${PMX_WHITE}$*${RESET}"; }

rule() {
    printf "%b" "$PMX_GREY"
    printf '─%.0s' {1..58}
    printf "%b\n" "$RESET"
}

show_banner() {
    clear || true
    local title="Proxmox-Tools by VROOT"
    local script_title="Console New Tab Utility"
    local width=58
    local pad_total
    local pad_left
    local pad_right

    printf "%b" "${PMX_ORANGE}${BOLD}"
    printf '┌'
    printf '─%.0s' $(seq 1 "$width")
    printf '┐
'

    pad_total=$((width - ${#title}))
    if (( pad_total < 0 )); then
        pad_total=0
    fi
    pad_left=$((pad_total / 2))
    pad_right=$((pad_total - pad_left))
    printf '│'
    printf '%*s' "$pad_left" ''
    printf "%b%s%b" "${PMX_WHITE}${BOLD}" "$title" "${PMX_ORANGE}${BOLD}"
    printf '%*s' "$pad_right" ''
    printf '│
'

    printf '│'
    printf '%*s' "$width" ''
    printf '│
'

    pad_total=$((width - ${#script_title}))
    if (( pad_total < 0 )); then
        pad_total=0
    fi
    pad_left=$((pad_total / 2))
    pad_right=$((pad_total - pad_left))
    printf '│'
    printf '%*s' "$pad_left" ''
    printf "%b%s%b" "${PMX_ORANGE_SOFT}${BOLD}" "$script_title" "${PMX_ORANGE}${BOLD}"
    printf '%*s' "$pad_right" ''
    printf '│
'

    printf '└'
    printf '─%.0s' $(seq 1 "$width")
    printf '┘
'
    printf "%b" "$RESET"

    echo -e "${PMX_ORANGE_SOFT}${BOLD}$(tr_msg repo_hint)${RESET}"
    echo

    local lang_label
    if [[ "$APP_LANG" == "fr" ]]; then
        lang_label="$(tr_msg lang_fr)"
    else
        lang_label="$(tr_msg lang_en)"
    fi

    echo -e "${PMX_GREY}Host:${RESET} ${PMX_WHITE}$(hostname)${RESET}    ${PMX_GREY}$(tr_msg detected_language):${RESET} ${PMX_WHITE}${lang_label}${RESET}"
    echo
}

pause() {
    echo
    read -r -p "$(tr_msg press_enter)" _
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

show_warning_and_confirm() {
    echo
    rule
    echo -e "${PMX_ORANGE}${BOLD}$(tr_msg warning_title)${RESET}"
    echo
    echo -e "${PMX_WHITE}• $(tr_msg warning_body_1)${RESET}"
    echo -e "${PMX_WHITE}• $(tr_msg warning_body_2)${RESET}"
    echo -e "${PMX_WHITE}• $(tr_msg warning_body_3)${RESET}"
    rule
    echo
    read -r -p "$(tr_msg type_yes): " answer
    if [[ "$answer" != "yes" ]]; then
        say_info "$(tr_msg cancelled)"
        return 1
    fi
    return 0
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

show_status() {
    echo -e "${PMX_ORANGE}${BOLD}$(tr_msg status_title)${RESET}"
    echo
    PM_FILE="$PM_FILE" PX_FILE="$PX_FILE" python3 <<'PY'
from pathlib import Path
import os

pm = Path(os.environ["PM_FILE"]).read_text(encoding="utf-8")
px = Path(os.environ["PX_FILE"]).read_text(encoding="utf-8")

checks = {
    "pm_openDefault_opts": "openDefaultConsoleWindow: function (consoles, consoleType, vmid, nodename, vmname, cmd, opts)",
    "pm_openConsole_opts": "openConsoleWindow: function (viewer, consoleType, vmid, nodename, vmname, cmd, opts)",
    "pm_openVNC_opts": "openVNCViewer: function (vmtype, vmid, nodename, vmname, cmd, opts)",
    "pm_newtab_method_default": "openDefaultConsoleNewTab: function ()",
    "pm_newtab_method_menu": "openConsoleNewTab: function (types)",
    "pm_novnc_menu_middleclick": "view.openConsoleNewTab(item.type);",
    "pm_xterm_menu_middleclick": "itemId: 'xtermjs'",
    "pm_spice_menu": "itemId: 'spicemenu'",
    "pm_spice_middleclick": "view.openConsole(item.type);",
    "px_xterm_opts": "openXtermJsViewer: function (vmtype, vmid, nodename, vmname, cmd, opts)",
}

for key, needle in checks.items():
    haystack = px if key.startswith("px_") else pm
    print(f" - {key}: {'OK' if needle in haystack else 'MISSING'}")

patched = (
    checks["pm_openDefault_opts"] in pm and
    checks["pm_openConsole_opts"] in pm and
    checks["pm_openVNC_opts"] in pm and
    checks["pm_newtab_method_default"] in pm and
    checks["pm_newtab_method_menu"] in pm and
    checks["pm_novnc_menu_middleclick"] in pm and
    checks["pm_xterm_menu_middleclick"] in pm and
    checks["pm_spice_menu"] in pm and
    checks["pm_spice_middleclick"] in pm and
    checks["px_xterm_opts"] in px and
    "opts && opts.newTab" in pm and
    "opts && opts.newTab" in px
)

print()
print(f"overall: {'PATCHED' if patched else 'STOCK_OR_PARTIAL'}")
PY
}

apply_patch() {
    local backup_dir

    show_warning_and_confirm || return 0

    backup_dir="$(create_backup)"
    say_info "$(tr_msg backup_created): $backup_dir"

    PM_FILE="$PM_FILE" PX_FILE="$PX_FILE" python3 <<'PY'
from pathlib import Path
import os
import sys

pm_path = Path(os.environ["PM_FILE"])
px_path = Path(os.environ["PX_FILE"])

pm = pm_path.read_text(encoding="utf-8")
px = px_path.read_text(encoding="utf-8")

def already_patched(pm_text, px_text):
    return (
        "openDefaultConsoleWindow: function (consoles, consoleType, vmid, nodename, vmname, cmd, opts)" in pm_text and
        "openConsoleWindow: function (viewer, consoleType, vmid, nodename, vmname, cmd, opts)" in pm_text and
        "openVNCViewer: function (vmtype, vmid, nodename, vmname, cmd, opts)" in pm_text and
        "openDefaultConsoleNewTab: function ()" in pm_text and
        "openConsoleNewTab: function (types)" in pm_text and
        "view.openConsoleNewTab(item.type);" in pm_text and
        "itemId: 'spicemenu'" in pm_text and
        "openXtermJsViewer: function (vmtype, vmid, nodename, vmname, cmd, opts)" in px_text and
        "opts && opts.newTab" in pm_text and
        "opts && opts.newTab" in px_text
    )

if already_patched(pm, px):
    print("[INFO] already_patched")
    sys.exit(0)

def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f"[ERROR] Block not found for: {label}")
    return text.replace(old, new, 1)

def replace_object_by_anchor(text, anchor, replacement):
    idx = text.find(anchor)
    if idx == -1:
        raise SystemExit(f"[ERROR] Anchor not found: {anchor}")

    start = text.rfind("        {", 0, idx)
    if start == -1:
        raise SystemExit(f"[ERROR] Could not locate object start for anchor: {anchor}")

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

    raise SystemExit(f"[ERROR] Could not locate object end for anchor: {anchor}")

def replace_consolebutton_methods(text):
    class_anchor = "Ext.define('PVE.button.ConsoleButton', {"
    start_anchor = "    handler: function () {"
    end_anchor = "    menu: ["

    class_pos = text.find(class_anchor)
    if class_pos == -1:
        raise SystemExit("[ERROR] ConsoleButton class not found")

    start = text.find(start_anchor, class_pos)
    if start == -1:
        raise SystemExit("[ERROR] ConsoleButton handler block not found")

    end = text.find(end_anchor, start)
    if end == -1:
        raise SystemExit("[ERROR] ConsoleButton menu block not found")

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

pm = replace_once(
    pm,
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
)

pm = replace_once(
    pm,
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
)

pm = replace_once(
    pm,
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
)

pm = replace_consolebutton_methods(pm)

pm = replace_object_by_anchor(
    pm,
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

pm = replace_object_by_anchor(
    pm,
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

pm = replace_object_by_anchor(
    pm,
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

px = replace_once(
    px,
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
)

pm_path.write_text(pm, encoding="utf-8")
px_path.write_text(px, encoding="utf-8")
print("[OK] patch_applied")
PY

    say_info "$(tr_msg restart_proxy)"
    systemctl restart pveproxy
    echo
    say_ok "$(tr_msg patch_applied)"
    say_info "$(tr_msg hard_refresh)"
    say_info "$(tr_msg backup_used): $backup_dir"
}

restore_specific() {
    local dir="$1"
    [[ -d "$dir" ]] || { say_err "$(tr_msg file_not_found): $dir"; return 1; }
    [[ -f "$dir/$(basename "$PM_FILE")" ]] || { say_err "$(tr_msg file_not_found): $dir/$(basename "$PM_FILE")"; return 1; }
    [[ -f "$dir/$(basename "$PX_FILE")" ]] || { say_err "$(tr_msg file_not_found): $dir/$(basename "$PX_FILE")"; return 1; }

    cp -av "$dir/$(basename "$PM_FILE")" "$PM_FILE"
    cp -av "$dir/$(basename "$PX_FILE")" "$PX_FILE"

    say_info "$(tr_msg restart_proxy)"
    systemctl restart pveproxy
    say_ok "$(tr_msg restore_done): $dir"
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

    echo -e "${PMX_ORANGE}${BOLD}$(tr_msg available_backups)${RESET}"
    echo
    local i=1
    for b in "${backups[@]}"; do
        echo -e "  ${PMX_ORANGE_SOFT}${i})${RESET} ${PMX_WHITE}${b}${RESET}"
        ((i++))
    done
    echo -e "  ${PMX_GREY}q) $(tr_msg cancelled)${RESET}"
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
    echo -e "${PMX_ORANGE}${BOLD}$(tr_msg available_backups)${RESET}"
    echo
    list_backups_raw || true
    pause
}

main_menu() {
    while true; do
        show_banner
        echo -e " ${PMX_ORANGE_SOFT}1)${RESET} ${PMX_WHITE}$(tr_msg menu_apply)${RESET}"
        echo -e " ${PMX_ORANGE_SOFT}2)${RESET} ${PMX_WHITE}$(tr_msg menu_restore_latest)${RESET}"
        echo -e " ${PMX_ORANGE_SOFT}3)${RESET} ${PMX_WHITE}$(tr_msg menu_restore_select)${RESET}"
        echo -e " ${PMX_ORANGE_SOFT}4)${RESET} ${PMX_WHITE}$(tr_msg menu_status)${RESET}"
        echo -e " ${PMX_ORANGE_SOFT}5)${RESET} ${PMX_WHITE}$(tr_msg menu_backups)${RESET}"
        echo -e " ${PMX_ORANGE_SOFT}6)${RESET} ${PMX_WHITE}$(tr_msg menu_quit)${RESET}"
        echo

        read -r -p "$(tr_msg choose_option) [1-6]: " choice
        echo

        case "$choice" in
            1)
                apply_patch
                pause
                ;;
            2)
                restore_latest
                pause
                ;;
            3)
                interactive_restore_menu
                ;;
            4)
                show_status
                pause
                ;;
            5)
                show_backups
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
