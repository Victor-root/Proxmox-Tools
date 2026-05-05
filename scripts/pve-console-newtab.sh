#!/usr/bin/env bash
set -euo pipefail

PATCH_PREFIX="/root/pve-console-newtab-patch"
PM_FILE="/usr/share/pve-manager/js/pvemanagerlib.js"
PX_FILE="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"

require_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        echo "[ERROR] This script must be run as root."
        exit 1
    fi
}

require_files() {
    [[ -f "$PM_FILE" ]] || { echo "[ERROR] File not found: $PM_FILE"; exit 1; }
    [[ -f "$PX_FILE" ]] || { echo "[ERROR] File not found: $PX_FILE"; exit 1; }
    command -v python3 >/dev/null 2>&1 || { echo "[ERROR] python3 is required."; exit 1; }
    command -v sha256sum >/dev/null 2>&1 || { echo "[ERROR] sha256sum is required."; exit 1; }
}

pause() {
    echo
    read -r -p "Press Enter to continue..."
}

show_warning_and_confirm() {
    cat <<'WARN'

WARNING:
This script modifies JavaScript files provided by Proxmox VE.

This is unsupported, may be overwritten by future updates, and any patching error may break the web UI until you restore the backup.

Please make sure you keep an active root SSH session open before continuing.

WARN
    read -r -p "Type 'yes' to continue: " answer
    if [[ "$answer" != "yes" ]]; then
        echo "[INFO] Operation cancelled."
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
    "pm_spice_menu": "itemId: 'spicemenu'",
    "pm_spice_middleclick": "view.openConsole(item.type);",
    "px_xterm_opts": "openXtermJsViewer: function (vmtype, vmid, nodename, vmname, cmd, opts)",
}

for key, needle in checks.items():
    haystack = px if key.startswith("px_") else pm
    print(f"{key}: {'OK' if needle in haystack else 'MISSING'}")

patched = (
    checks["pm_openDefault_opts"] in pm and
    checks["pm_openConsole_opts"] in pm and
    checks["pm_openVNC_opts"] in pm and
    checks["pm_newtab_method_default"] in pm and
    checks["pm_newtab_method_menu"] in pm and
    checks["pm_novnc_menu_middleclick"] in pm and
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
    echo "[INFO] Backup created: $backup_dir"

    PM_FILE="$PM_FILE" PX_FILE="$PX_FILE" python3 <<'PY'
from pathlib import Path
import os
import re
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
        "openXtermJsViewer: function (vmtype, vmid, nodename, vmname, cmd, opts)" in px_text and
        "opts && opts.newTab" in pm_text and
        "opts && opts.newTab" in px_text
    )

if already_patched(pm, px):
    print("[INFO] The patch already appears to be present. No changes applied.")
    sys.exit(0)

def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f"[ERROR] Block not found for: {label}")
    return text.replace(old, new, 1)

def regex_replace_once(text, pattern, repl, label, flags=re.S):
    new_text, count = re.subn(pattern, repl, text, count=1, flags=flags)
    if count != 1:
        raise SystemExit(f"[ERROR] Replacement failed for: {label} (matches={count})")
    return new_text

def replace_spice_menu(text):
    anchor = "itemId: 'spicemenu'"
    idx = text.find(anchor)
    if idx == -1:
        raise SystemExit("[ERROR] SPICE menu anchor not found")

    start = text.rfind("        {", 0, idx)
    if start == -1:
        raise SystemExit("[ERROR] Could not locate start of SPICE menu block")

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

                    replacement = """        {
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
        },"""

                    return text[:start] + replacement + text[end:]
        i += 1

    raise SystemExit("[ERROR] Could not locate end of SPICE menu block")

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

pm = replace_once(
    pm,
"""    handler: function () {
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
""",
"""    handler: function () {
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
""",
    "ConsoleButton methods",
)

pm = replace_once(
    pm,
"""        {
            xtype: 'menuitem',
            text: 'noVNC',
            iconCls: 'pve-itype-icon-novnc',
            type: 'html5',
            handler: function (button) {
                let view = this.up('button');
                view.openConsole(button.type);
            },
        },
""",
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
        },
""",
    "noVNC menu item",
)

pm = replace_once(
    pm,
"""        {
            text: 'xterm.js',
            itemId: 'xtermjs',
            iconCls: 'pve-itype-icon-xtermjs',
            type: 'xtermjs',
            handler: function (button) {
                let view = this.up('button');
                view.openConsole(button.type);
            },
        },
""",
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
        },
""",
    "xterm.js menu item",
)

pm = replace_spice_menu(pm)

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
print("[OK] Patch applied to pvemanagerlib.js and proxmoxlib.js")
PY

    echo "[INFO] Restarting pveproxy..."
    systemctl restart pveproxy
    echo
    echo "[OK] Patch applied successfully."
    echo "[INFO] A hard refresh in your browser is recommended."
    echo "[INFO] Backup used: $backup_dir"
}

restore_latest() {
    local dir
    dir="$(latest_backup_dir)"
    if [[ -z "$dir" ]]; then
        echo "[ERROR] No backup found."
        return 1
    fi
    restore_specific "$dir"
}

restore_specific() {
    local dir="$1"

    [[ -d "$dir" ]] || { echo "[ERROR] Backup directory not found: $dir"; return 1; }
    [[ -f "$dir/$(basename "$PM_FILE")" ]] || { echo "[ERROR] Missing backup file: $(basename "$PM_FILE")"; return 1; }
    [[ -f "$dir/$(basename "$PX_FILE")" ]] || { echo "[ERROR] Missing backup file: $(basename "$PX_FILE")"; return 1; }

    cp -av "$dir/$(basename "$PM_FILE")" "$PM_FILE"
    cp -av "$dir/$(basename "$PX_FILE")" "$PX_FILE"

    echo "[INFO] Restarting pveproxy..."
    systemctl restart pveproxy
    echo "[OK] Restore completed from: $dir"
}

interactive_restore_menu() {
    mapfile -t backups < <(list_backups_raw)

    if [[ "${#backups[@]}" -eq 0 ]]; then
        echo "[ERROR] No backups found."
        pause
        return
    fi

    echo
    echo "Available backups:"
    local i=1
    for b in "${backups[@]}"; do
        echo "  $i) $b"
        ((i++))
    done
    echo "  q) Cancel"
    echo

    read -r -p "Choose a backup number to restore: " choice

    if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
        echo "[INFO] Restore cancelled."
        pause
        return
    fi

    if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
        echo "[ERROR] Invalid selection."
        pause
        return
    fi

    if (( choice < 1 || choice > ${#backups[@]} )); then
        echo "[ERROR] Selection out of range."
        pause
        return
    fi

    restore_specific "${backups[$((choice-1))]}"
    pause
}

show_backups() {
    echo
    list_backups_raw || true
    pause
}

show_banner() {
    clear || true
    cat <<'BANNER'
===========================================
 Proxmox VE Console New Tab Patch Utility
===========================================
BANNER
    echo
    hostname || true
    echo
}

main_menu() {
    while true; do
        show_banner
        cat <<'MENU'
1) Apply patch
2) Restore latest backup
3) Restore from selected backup
4) Show patch status
5) List backups
6) Quit

MENU

        read -r -p "Choose an option [1-6]: " choice
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
                echo "[INFO] Bye."
                exit 0
                ;;
            *)
                echo "[ERROR] Invalid choice."
                pause
                ;;
        esac
    done
}

require_root
require_files
main_menu
