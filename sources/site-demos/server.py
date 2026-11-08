"""Demo server: the real Proxmox VE web interface files with a fake API.

A cookie PMTVariant=<name> picks the files of work/variants/<name>/ (the files
a script patched, see prepare.py) over the stock ones, so a recording can show
Proxmox VE before and after a script. /__demo/host.html is the browser frame
the recordings run in.
"""
import base64
import hashlib
import json
import math
import re
import struct
import sys
import time
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlparse, parse_qs

HERE = Path(__file__).resolve().parent
WORK = HERE / "work"
PORT = int(sys.argv[1])
S = WORK / "root/usr/share"
XTERM = S / "pve-xtermjs"
DIRS = {
    "/pve2/css/": S / "pve-manager/css",
    "/pve2/ext6/": S / "javascript/extjs",
    "/pve2/fa/": S / "fonts-font-awesome",
    "/pve2/font-logos/": S / "fonts-font-logos",
    "/pve2/images/": S / "pve-manager/images",
    "/pve2/js/": S / "pve-manager/js",
    "/pve2/locale/": S / "pve-i18n",
    "/pwt/css/": S / "javascript/proxmox-widget-toolkit/css",
    "/pwt/images/": S / "javascript/proxmox-widget-toolkit/images",
    "/pwt/themes/": S / "javascript/proxmox-widget-toolkit/themes",
    "/xtermjs/": XTERM,
    "/__demo/": HERE / "static",
}
CTYPES = {".css": "text/css", ".js": "application/javascript", ".png": "image/png", ".svg": "image/svg+xml",
          ".woff": "font/woff", ".woff2": "font/woff2", ".ttf": "font/ttf", ".gif": "image/gif",
          ".ico": "image/x-icon", ".html": "text/html; charset=utf-8", ".eot": "application/octet-stream"}
# files a script can patch, by URL, and their name inside a variant directory
PATCHABLE = {"/pve2/js/pvemanagerlib.js": "pvemanagerlib.js", "/proxmoxlib.js": "proxmoxlib.js",
             "/xtermjs/main.js": "main.js", "/xtermjs/util.js": "util.js", "/xtermjs/style.css": "style.css"}

NODES = ["pve01", "pve02", "pve03"]
NOW = int(time.time())
GUESTS = [
    # vmid, type, name, node, status, cpu, maxmem GiB, mem ratio, tags
    (100, "qemu", "home-assistant", "pve01", "running", 0.06, 4, 0.55, "domotique"),
    (101, "qemu", "truenas", "pve01", "running", 0.12, 16, 0.81, "nas;storage"),
    (102, "qemu", "windows-11", "pve02", "stopped", 0, 8, 0, ""),
    (103, "qemu", "opnsense", "pve02", "running", 0.03, 4, 0.32, "network"),
    (200, "lxc", "pihole", "pve01", "running", 0.01, 1, 0.21, "network"),
    (201, "lxc", "jellyfin", "pve03", "running", 0.22, 4, 0.47, "media"),
    (202, "lxc", "nextcloud", "pve03", "running", 0.04, 4, 0.62, ""),
    (203, "lxc", "wireguard", "pve01", "running", 0.0, 1, 0.08, "network"),
    (204, "lxc", "debian-template", "pve02", "stopped", 0, 1, 0, ""),
]
GiB = 1024 ** 3


def resources():
    out = []
    for i, n in enumerate(NODES):
        out.append({"id": f"node/{n}", "type": "node", "node": n, "status": "online", "cpu": 0.08 + 0.07 * i,
                    "maxcpu": 16, "mem": int((22 + 9 * i) * GiB), "maxmem": 64 * GiB, "disk": int(18 * GiB),
                    "maxdisk": 94 * GiB, "uptime": 864000 + i * 3600, "level": "", "cgroup-mode": 2})
        for st, plugin, used, total in (("local", "dir", 18, 94), ("local-lvm", "lvmthin", 210, 800)):
            out.append({"id": f"storage/{n}/{st}", "type": "storage", "storage": st, "node": n, "status": "available",
                        "plugintype": plugin, "disk": used * GiB, "maxdisk": total * GiB, "shared": 0,
                        "content": "iso,vztmpl,backup" if st == "local" else "images,rootdir"})
        out.append({"id": f"sdn/{n}/localnetwork", "type": "sdn", "sdn": "localnetwork", "node": n, "status": "ok"})
    for vmid, t, name, node, status, cpu, maxmem, ratio, tags in GUESTS:
        out.append({"id": f"{t}/{vmid}", "type": t, "vmid": vmid, "name": name, "node": node, "status": status,
                    "cpu": cpu, "maxcpu": 4, "mem": int(maxmem * ratio * GiB), "maxmem": maxmem * GiB,
                    "disk": 0, "maxdisk": 32 * GiB, "uptime": 300000 if status == "running" else 0,
                    "template": 0, "tags": tags, "netin": 123456789, "netout": 98765432,
                    "diskread": 0, "diskwrite": 0, "hastate": None})
    out.append({"id": "storage/pve01/nas-backup", "type": "storage", "storage": "nas-backup", "node": "pve01",
                "status": "available", "plugintype": "pbs", "disk": 1200 * GiB, "maxdisk": 4000 * GiB,
                "shared": 1, "content": "backup"})
    out.append({"id": "pool/production", "type": "pool", "pool": "production"})
    return out


def rrd(points=70, step=60):
    data = []
    for k in range(points):
        t = NOW - (points - k) * step
        w = math.sin(k / 6.0)
        data.append({"time": t, "cpu": 0.12 + 0.06 * w + 0.03 * math.sin(k * 1.7), "maxcpu": 16,
                     "iowait": 0.004 + 0.002 * w, "loadavg": 1.4 + 0.6 * w,
                     "memused": (24 + 2 * w) * GiB, "memtotal": 64 * GiB, "mem": (24 + 2 * w) * GiB,
                     "maxmem": 64 * GiB, "memavailable": (40 - 2 * w) * GiB,
                     "netin": 2.4e6 + 1.1e6 * math.sin(k / 4.0), "netout": 9e5 + 4e5 * math.cos(k / 5.0),
                     "swapused": 0.3 * GiB, "swaptotal": 8 * GiB, "rootused": 18 * GiB, "roottotal": 94 * GiB,
                     "pressurecpusome": 0.02, "pressureiosome": 0.01, "pressurememorysome": 0,
                     "pressurecpufull": 0, "pressureiofull": 0, "pressurememoryfull": 0,
                     "diskread": 3e6 + 2e6 * w, "diskwrite": 1.5e6, "arcsize": 6 * GiB})
    return data


def node_status(node):
    return {"cpu": 0.11, "wait": 0.004, "loadavg": ["1.42", "1.31", "1.18"], "uptime": 864000,
            "kversion": "Linux 6.17.2-1-pve #1 SMP PREEMPT_DYNAMIC PMX 6.17.2-1 (2026-10-01T09:00Z)",
            "pveversion": "pve-manager/9.2.24/0123456789abcdef", "current-kernel": {"release": "6.17.2-1-pve",
            "sysname": "Linux", "machine": "x86_64", "version": "#1 SMP PREEMPT_DYNAMIC PMX 6.17.2-1"},
            "boot-info": {"mode": "efi", "secureboot": 0},
            "cpuinfo": {"model": "AMD Ryzen 7 5700G with Radeon Graphics", "cpus": 16, "sockets": 1, "cores": 8,
                        "mhz": "3800.000", "hvm": "1", "flags": "", "user_hz": 100},
            "memory": {"used": 24 * GiB, "total": 64 * GiB, "free": 40 * GiB, "available": 40 * GiB},
            "swap": {"used": int(0.3 * GiB), "total": 8 * GiB, "free": int(7.7 * GiB)},
            "rootfs": {"used": 18 * GiB, "total": 94 * GiB, "avail": 76 * GiB, "free": 76 * GiB},
            "ksm": {"shared": 0}, "idle": 0, "pressure": {}}


def tasks():
    types = [("vzdump", "", "OK"), ("qmstart", "101", "OK"), ("vzstart", "201", "OK"),
             ("aptupdate", "", "OK"), ("qmshutdown", "102", "OK"), ("vzdump", "", "WARNINGS: 1")]
    out = []
    for i, (t, vid, st) in enumerate(types):
        s = NOW - 900 * (i + 1)
        out.append({"upid": f"UPID:pve01:0000{i}:00:{s:X}:{t}:{vid}:root@pam:", "node": NODES[i % 3], "type": t,
                    "id": vid, "user": "root@pam", "starttime": s, "endtime": s + 42, "status": st})
    return out


def api(path, qs):
    p = path
    if p.endswith("/cluster/resources"):
        t = qs.get("type", [None])[0]
        r = resources()
        if t == "vm":
            return [x for x in r if x["type"] in ("qemu", "lxc")]
        if t:
            return [x for x in r if x["type"] == t]
        return r
    if p.endswith("/cluster/status"):
        return [{"type": "cluster", "id": "cluster", "name": "homelab", "nodes": 3, "quorate": 1, "version": 3}] + [
            {"type": "node", "id": f"node/{n}", "name": n, "online": 1, "local": int(i == 0), "nodeid": i + 1,
             "ip": f"192.0.2.{11 + i}", "level": ""} for i, n in enumerate(NODES)]
    if p.endswith("/cluster/tasks"):
        return tasks()
    if p.endswith("/cluster/log"):
        return [{"n": i, "t": NOW - 60 * i, "node": NODES[i % 3], "user": "root@pam", "tag": "pvedaemon", "pri": 6,
                 "pid": 100 + i, "uid": "x", "msg": "successful auth for user 'root@pam'"} for i in range(8)]
    if p.endswith("/cluster/options"):
        return {"keyboard": "fr", "console": "xtermjs", "tag-style": {"shape": "full", "ordering": "config"}, "allowed-tags": []}
    if p.endswith("/cluster/nextid"):
        return 105
    if re.search(r"/nodes/[^/]+/subscription$", p):
        return {"status": "notfound"}
    if re.search(r"/nodes/[^/]+/status$", p):
        return node_status(p.split("/")[-2])
    if re.search(r"/rrddata$", p):
        return rrd()
    if p.endswith("/nodes"):
        return [{"node": n, "status": "online", "cpu": 0.1, "maxcpu": 16, "mem": 24 * GiB, "maxmem": 64 * GiB,
                 "uptime": 864000, "ssl_fingerprint": "AA:BB", "level": ""} for n in NODES]
    if p.endswith("/version"):
        return {"version": "9.2.24", "release": "9.2", "repoid": "0123456789abcdef", "console": "xtermjs"}
    if re.search(r"/access/permissions$", p):
        return {"/": {k: 1 for k in ("Sys.Audit", "Sys.Modify", "Sys.Console", "VM.Allocate", "Datastore.Audit",
                                     "Datastore.Allocate", "Permissions.Modify", "SDN.Audit", "Pool.Audit",
                                     "Sys.PowerMgmt", "VM.PowerMgmt", "VM.Console", "VM.Audit")}}
    if re.search(r"/(qemu|lxc)/\d+/status/current$", p):
        vmid = int(p.split("/")[-3])
        g = next((x for x in GUESTS if x[0] == vmid), GUESTS[0])
        return {"vmid": vmid, "name": g[2], "status": g[4], "cpu": g[5], "cpus": 4, "maxmem": g[6] * GiB,
                "mem": int(g[6] * g[7] * GiB), "maxdisk": 32 * GiB, "disk": 9 * GiB, "uptime": 300000,
                "netin": 1, "netout": 1, "diskread": 1, "diskwrite": 1, "ha": {"managed": 0}, "qmpstatus": g[4],
                "running-machine": "pc-q35-10.0+pve1", "running-qemu": "10.0.2", "tags": g[8]}
    if re.search(r"/(qemu|lxc)/\d+/config$", p):
        vmid = int(p.split("/")[-2])
        g = next((x for x in GUESTS if x[0] == vmid), GUESTS[0])
        return {"name": g[2], "hostname": g[2], "memory": g[6] * 1024, "cores": 4, "sockets": 1, "ostype": "l26",
                "net0": "virtio=BC:24:11:00:00:01,bridge=vmbr0", "scsi0": "local-lvm:vm-%d-disk-0,size=32G" % vmid,
                "boot": "order=scsi0", "tags": g[8], "digest": "x",
                "description": "Pi-hole, DNS of the home network\n\nAdmin page: http://192.168.1.60/admin" if vmid == 200 else ""}
    if re.search(r"/sdn/zones/[^/]+/content$", p):
        return [{"vnet": "vmbr0", "status": "available"}, {"vnet": "vmbr1", "status": "available"}]
    if p.endswith("/apt/repositories"):
        return {"files": [], "errors": [], "infos": [], "standard-repos": [], "digest": "x"}
    if p.endswith("/access/domains"):
        return [{"realm": "pam", "type": "pam", "comment": "Linux PAM standard authentication"},
                {"realm": "pve", "type": "pve", "comment": "Proxmox VE authentication server", "default": 1}]
    if re.search(r"/(qemu|lxc)/\d+/snapshot$", p):
        return [{"name": "before-upgrade", "description": "Before the upgrade", "snaptime": NOW - 86400},
                {"name": "current", "description": "You are here!", "parent": "before-upgrade", "running": 1, "digest": "x"}]
    if re.search(r"/(qemu|lxc)/\d+/feature$", p):
        return {"hasFeature": 1, "nodes": ["pve01"]}
    if re.search(r"/lxc/\d+/interfaces$", p):
        return [{"name": "lo", "hardware-address": "00:00:00:00:00:00", "ip-addresses": [{"ip-address": "127.0.0.1", "prefix": 8, "ip-address-type": "ipv4"}]},
                {"name": "eth0", "hardware-address": "bc:24:11:fe:bb:d6", "ip-addresses": [
                    {"ip-address": "192.168.1.60", "prefix": 24, "ip-address-type": "ipv4"},
                    {"ip-address": "2a01:cb15:85c4:a600:be24:11ff:febb:d6b2", "prefix": 64, "ip-address-type": "ipv6"}]}]
    if re.search(r"/storage/[^/]+/status$", p):
        return {"total": 3940 * 10**9, "used": 3902 * 10**9, "avail": 38 * 10**9, "enabled": 1, "active": 1,
                "content": "images", "type": "dir", "shared": 0}
    if re.search(r"/pending$", p):
        return []
    return None



def guest_name(path):
    m = re.search(r"/(qemu|lxc)/(\d+)/", path)
    if not m:
        return "pve01"
    return next((g[2] for g in GUESTS if g[0] == int(m.group(2))), "guest")


def shell_reply(line):
    """What the fake shell prints for a command typed in a console."""
    m = re.fullmatch(r'seq -f "([^"]*)%g" 1 (\d+)', line.strip())
    if m:
        return "".join(f"{m.group(1)}{i}\r\n" for i in range(1, int(m.group(2)) + 1))
    if line.strip() == "uptime":
        return " 19:42:07 up 3 days, 11:20,  1 user,  load average: 0.08, 0.05, 0.01\r\n"
    return ""


def cookie(headers, name):
    m = re.search(rf"(?:^|;\s*){name}=([^;]*)", headers.get("Cookie", ""))
    return m.group(1) if m else ""


class H(BaseHTTPRequestHandler):
    def log_message(self, fmt, *a):
        pass

    def send(self, code, body, ctype):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def variant_dir(self):
        name = cookie(self.headers, "PMTVariant")
        return WORK / "variants" / name if re.fullmatch(r"[a-z0-9-]+", name) else None

    # termproxy's websocket: "OK" once the ticket line arrives, then a shell
    def websocket(self, path):
        key = self.headers["Sec-WebSocket-Key"]
        accept = base64.b64encode(hashlib.sha1((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()).digest())
        self.send_response(101)
        self.send_header("Upgrade", "websocket")
        self.send_header("Connection", "Upgrade")
        self.send_header("Sec-WebSocket-Accept", accept.decode())
        self.send_header("Sec-WebSocket-Protocol", "binary")
        self.end_headers()
        self.wfile.flush()

        def send(data):
            data = data.encode() if isinstance(data, str) else data
            n = len(data)
            head = bytes([0x82, n]) if n < 126 else (bytes([0x82, 126]) + struct.pack(">H", n) if n < 65536
                                                     else bytes([0x82, 127]) + struct.pack(">Q", n))
            self.wfile.write(head + data)
            self.wfile.flush()

        def receive():
            b1, b2 = self.rfile.read(2)
            n = b2 & 0x7F
            if n == 126:
                n = struct.unpack(">H", self.rfile.read(2))[0]
            elif n == 127:
                n = struct.unpack(">Q", self.rfile.read(8))[0]
            mask = self.rfile.read(4) if b2 & 0x80 else b"\0\0\0\0"
            data = bytes(c ^ mask[i % 4] for i, c in enumerate(self.rfile.read(n)))
            return b1 & 0x0F, data

        prompt = f"root@{guest_name(path)}:~# "
        line = ""
        try:
            while True:
                op, data = receive()
                if op == 8:
                    return
                text = data.decode(errors="replace")
                if not line and text.endswith("\n") and ":" in text and not text.startswith(("0:", "1:", "2")):
                    send("OK" + f"Linux {guest_name(path)} 6.17.2-1-pve x86_64\r\n\r\n" + prompt)
                    continue
                if not text.startswith("0:"):
                    continue
                for ch in text.split(":", 2)[2]:
                    if ch == "\r":
                        send("\r\n" + shell_reply(line) + prompt)
                        line = ""
                    elif ch == "\x7f":
                        if line:
                            line = line[:-1]
                            send("\b \b")
                    else:
                        line += ch
                        send(ch)
        except (ValueError, ConnectionError, OSError):
            return

    def do_GET(self):
        u = urlparse(self.path)
        p, qs = u.path, parse_qs(u.query)
        if p.endswith("/vncwebsocket") and self.headers.get("Upgrade", "").lower() == "websocket":
            self.websocket(p)
            return
        if p.startswith("/api2/"):
            data = api(p, qs)
            vd = self.variant_dir()
            # a variant can stand for a host with a subscription
            if re.search(r"/subscription$", p) and vd and (vd / "subscription-active").is_file():
                data = {"status": "active", "level": "c", "productname": "Proxmox VE Community Subscription"}
            if data is None:
                sys.stderr.write(f"UNMOCKED {p}\n"); sys.stderr.flush()
                data = []
            self.send(200, json.dumps({"data": data, "success": 1}).encode(), "application/json;charset=UTF-8")
            return
        if p == "/":
            page = self.xterm_index() if "xtermjs" in qs else self.index()
            self.send(200, page.encode(), "text/html; charset=utf-8")
            return
        f = None
        vd = self.variant_dir()
        if p in PATCHABLE and vd and (vd / PATCHABLE[p]).is_file():
            f = vd / PATCHABLE[p]
        elif p == "/proxmoxlib.js":
            f = S / "javascript/proxmox-widget-toolkit/proxmoxlib.js"
        elif p.startswith("/pwt/themes/") and vd and (vd / "themes" / p.rsplit("/", 1)[1]).is_file():
            f = vd / "themes" / p.rsplit("/", 1)[1]
        else:
            for pre, d in DIRS.items():
                if p.startswith(pre):
                    f = d / p[len(pre):]
                    break
        if f is None or not f.is_file():
            if p not in ("/qrcode.min.js", "/favicon.ico"):
                sys.stderr.write(f"MISSING {p}\n")
            self.send(404, b"", "text/plain")
            return
        self.send(200, f.read_bytes(), CTYPES.get(f.suffix, "application/octet-stream"))

    def do_POST(self):
        data = None
        if self.path.endswith("/termproxy"):
            data = {"port": 5900, "ticket": "PVEVNC:DEMO", "user": "root@pam", "upid": "UPID:pve01:demo"}
        elif self.path.endswith("/access/ticket"):
            yes = lambda *ks: {k: 1 for k in ks}
            data = {"username": "root@pam", "ticket": "PVE:root@pam:FAKE", "CSRFPreventionToken": "fake",
                    "clustername": "homelab", "cap": {
                        "vms": yes("VM.Allocate", "VM.Audit", "VM.Console", "VM.PowerMgmt", "VM.Config.Options",
                                   "VM.Snapshot", "VM.Backup", "VM.Clone", "VM.Migrate"),
                        "storage": yes("Datastore.Audit", "Datastore.Allocate", "Datastore.AllocateSpace"),
                        "access": yes("User.Modify", "Permissions.Modify", "Group.Allocate"),
                        "nodes": yes("Sys.Audit", "Sys.Modify", "Sys.Console", "Sys.PowerMgmt", "Sys.Syslog"),
                        "dc": yes("Sys.Audit", "Sys.Modify", "SDN.Audit"),
                        "sdn": yes("SDN.Audit", "SDN.Allocate"), "mapping": yes("Mapping.Audit", "Mapping.Modify")}}
        self.send(200, json.dumps({"data": data, "success": 1}).encode(), "application/json;charset=UTF-8")

    do_PUT = do_POST

    # pveproxy's get_index(): theme from PVEThemeCookie, language from PVELangCookie
    def index(self):
        theme = cookie(self.headers, "PVEThemeCookie")
        if not re.fullmatch(r"[a-z]{1,10}(-[a-z]{1,10}){0,5}", theme):
            theme = "auto"
        # like pveproxy: the browser cookie, else the language of datacenter.cfg
        lang = cookie(self.headers, "PVELangCookie")
        vd = self.variant_dir()
        if not lang and vd and (vd / "datacenter.cfg").is_file():
            m = re.search(r"^language:\s*(\S+)", (vd / "datacenter.cfg").read_text(), re.M)
            lang = m.group(1) if m else ""
        lang = lang or "en"
        tpl = (S / "pve-manager/index.html.tpl").read_text()
        if theme == "crisp":
            themelink = ""
        elif theme != "auto":
            themelink = f'<link rel="stylesheet" type="text/css" href="/pwt/themes/theme-{theme}.css" />'
        else:
            themelink = ('<link rel="stylesheet" type="text/css" media="(prefers-color-scheme: dark)" '
                         'href="/pwt/themes/theme-proxmox-dark.css" />')
        tpl = re.sub(r"\[%- IF theme != 'crisp' %\].*?\[%- END -%\]\s*\[%- END -%\]", themelink, tpl, flags=re.S)
        if lang != "en":
            tpl = re.sub(r"\[% IF langfile %\](.*?)\[%- ELSE %\].*?\[% END %\]", r"\1", tpl, flags=re.S)
        else:
            tpl = re.sub(r"\[% IF langfile %\].*?\[%- ELSE %\](.*?)\[% END %\]", r"\1", tpl, flags=re.S)
        tpl = re.sub(r"\[%- IF debug %\].*?\[%- ELSE %\](.*?)\[% END %\]", r"\1", tpl, flags=re.S)
        user = "root@pam" if cookie(self.headers, "PVEAuthCookie") else ""
        repl = {"nodename": "pve01", "lang": lang, "arch": "x86_64", "username": user, "token": "fake",
                "consenttext.squote": "", "version": "9.2.24", "wtversion": "5.2.10", "i18n_js_mtime": "1"}
        return re.sub(r"\[%\s*([a-z_.]+)\s*%\]", lambda mm: repl.get(mm.group(1), ""), tpl)

    def xterm_index(self):
        tpl = (XTERM / "index.html.tpl").read_text()
        repl = {"nodename": "pve01", "username": "root@pam", "token": "fake"}
        return re.sub(r"\[%\s*([a-z_.]+)\s*%\]", lambda mm: repl.get(mm.group(1), ""), tpl)


ThreadingHTTPServer(("127.0.0.1", PORT), H).serve_forever()
