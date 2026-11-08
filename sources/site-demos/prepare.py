"""Gets everything the recordings need into work/.

work/root: the Proxmox VE web interface files, from the official packages,
downloaded once and checked against the SHA256 pinned below.
work/variants: the files the scripts of this repository patch, patched by
those scripts' own code, one directory per state a recording shows.
"""
import os
import re
import shutil
import subprocess
import urllib.request
from hashlib import sha256
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
WORK = HERE / "work"
SHARE = WORK / "root/usr/share"
PVE = "http://download.proxmox.com/debian/pve/dists/trixie/pve-no-subscription/binary-amd64/"
DEBIAN = "http://deb.debian.org/debian/pool/main/f/fonts-font-awesome/"
# Proxmox serves its packages over plain HTTP, like its APT repositories: the
# pinned hashes are what makes a download trusted.
PACKAGES = [
    (PVE + "pve-manager_9.2.24_all.deb", "76572fb7dc7ef317f59b373bddf751f37bd2d371da1524ec705cde33010577cc"),
    (PVE + "proxmox-widget-toolkit_5.2.10_all.deb", "50250a235ecbe10638067574c5dd4bf56b24f19f2d22050b976f5a2ad422ae6e"),
    (PVE + "libjs-extjs_7.0.0-9_all.deb", "fbedb5765a53b84dc32acfd200bb76bebc79b54aa2bd0f7aeef61cbb0cd62eb8"),
    (PVE + "fonts-font-logos_1.0.1-3_all.deb", "f689581c311a4f2316a57796f246b1f3612ba4893b6c8ffd7d47a14f1605e175"),
    (PVE + "pve-i18n_3.9.0_all.deb", "68155bfdf1ae99ea0c55690a541085ed1f35eabdfb83d9677307dda0bc6c5ef1"),
    (PVE + "pve-xtermjs_6.0.0-3_all.deb", "1989efdca9dcafeb53345833d8ed9e3a2ef7742770cd0223b8e5b9d7c5da95c4"),
    ("https://github.com/fastfetch-cli/fastfetch/releases/download/2.71.0/fastfetch-linux-amd64.deb",
     "6dc0b71c03e58f9f981a6b3c62b4fa3fb30b9d5ee9fa783302c91ea4c2a3600e"),
    (DEBIAN + "fonts-font-awesome_5.0.10+really4.7.0~dfsg-4.1_all.deb",
     "5f09e1adce26d59628a239c538882d53e58978b958233864fc617be9a510018e"),
]
STOCK = {
    "pvemanagerlib.js": SHARE / "pve-manager/js/pvemanagerlib.js",
    "proxmoxlib.js": SHARE / "javascript/proxmox-widget-toolkit/proxmoxlib.js",
    "main.js": SHARE / "pve-xtermjs/main.js",
    "util.js": SHARE / "pve-xtermjs/util.js",
}


def fetch():
    debs = WORK / "debs"
    debs.mkdir(parents=True, exist_ok=True)
    shutil.rmtree(WORK / "root", ignore_errors=True)
    for url, digest in PACKAGES:
        deb = debs / url.rsplit("/", 1)[1]
        if not deb.is_file() or sha256(deb.read_bytes()).hexdigest() != digest:
            with urllib.request.urlopen(url) as answer:
                data = answer.read()
            if sha256(data).hexdigest() != digest:
                raise SystemExit(f"{deb.name}: unexpected SHA256, not used")
            deb.write_bytes(data)
        subprocess.run(["dpkg-deb", "-x", str(deb), str(WORK / "root")], check=True)


def script(name):
    return str(REPO / "scripts" / name)


def shell_value(path, var):
    """A variable of a script: a one line assignment, or a $(cat <<'PY' ...) block."""
    pick = f"sed -n '/^{var}=\"\\$(cat/,/^)\"$/p'" if var.endswith("_PY") else f"grep '^{var}='"
    return subprocess.run(["bash", "-c", f'source <({pick} "$0"); printf "%s" "${var}"', path],
                          check=True, capture_output=True, text=True).stdout


def engine(path, var, env, *args):
    subprocess.run(["python3", "-c", shell_value(path, var), *args], env={**os.environ, **env}, check=True,
                   stdout=subprocess.DEVNULL)


def script_functions(path, names):
    """Functions of a script, whole even when a heredoc in them holds a closing brace."""
    text = Path(path).read_text(encoding="utf-8")
    out = []
    for name in names:
        start = text.index(f"\n{name}() {{\n") + 1
        heredoc = re.search(r"<<'(EOF_[A-Z]+)'", text[start:text.index("\n}\n", start)])
        end_mark = f"\n{heredoc.group(1)}\n}}\n" if heredoc else "\n}\n"
        out.append(text[start:text.index(end_mark, start) + len(end_mark)])
    return "\n".join(out)


def variant(name, *files):
    out = WORK / "variants" / name
    out.mkdir(parents=True)
    for f in files:
        shutil.copy(STOCK[f], out / f)
    return out


def build_variants():
    shutil.rmtree(WORK / "variants", ignore_errors=True)
    variant("stock")
    # a host with a subscription, where Proxmox shows no subscription window
    (variant("stock-sub") / "subscription-active").touch()

    out = variant("theme", "proxmoxlib.js", "pvemanagerlib.js")
    theme = script("pve-modern-theme.sh")
    env = {"PX_FILE": str(out / "proxmoxlib.js"), "PVE_FILE": str(out / "pvemanagerlib.js"),
           "PROXY_FILE": "", "XTERM_FILE": ""}
    for patch in ("selector", "charts", "logs", "summary", "gap", "notes"):
        engine(theme, "ENGINE_PY", env, "apply", patch)
    parts = WORK / "theme-parts"
    parts.mkdir(exist_ok=True)
    for part, function in (("light_head", "theme_css_light_head"), ("dark_head", "theme_css_dark_head"),
                           ("shared", "theme_css_shared"), ("light_tail", "theme_css_light_tail"),
                           ("dark_tail", "theme_css_dark_tail"), ("colors", "theme_accent_colors")):
        css = subprocess.run(["bash", "-c", f"source <(sed -n '/^# >>> generated/,/^# <<< end/p' \"$0\"); {function}",
                              theme], check=True, capture_output=True, text=True).stdout
        (parts / part).write_text(css)
    (out / "themes").mkdir()
    engine(theme, "ENGINE_PY", env, "themes-write", str(out / "themes"), str(parts))

    out = variant("tree", "pvemanagerlib.js")
    for patch in ("tree", "logs"):
        engine(script("pve-expand-node-tree.sh"), "PATCH_PY", {"PM_FILE": str(out / "pvemanagerlib.js")}, "apply", patch)

    out = variant("nosub", "proxmoxlib.js")
    expr = shell_value(script("pve-remove-subscription-notice.sh"), "PATCH_SED_EXPR")
    subprocess.run(["sed", "-i", expr, str(out / "proxmoxlib.js")], check=True)

    # what the language script writes into /etc/pve/datacenter.cfg
    out = variant("lang-fr")
    (out / "datacenter.cfg").write_text("language: fr\n")
    (out / "subscription-active").touch()

    out = variant("newtab", "pvemanagerlib.js", "proxmoxlib.js")
    (out / "subscription-active").touch()
    env = {"PM_FILE": str(out / "pvemanagerlib.js"), "PX_FILE": str(out / "proxmoxlib.js")}
    for target in ("console", "tree"):
        engine(script("pve-console-newtab.sh"), "PATCH_PY", env, "apply", target)

    out = variant("tabtitle", "main.js")
    engine(script("pve-xterm-tab-title.sh"), "PATCH_PY", {"MAIN_FILE": str(out / "main.js")}, "apply")

    # the summary as pve-fastfetch-motd.sh prints it, drawn in its card; the namespaces need root
    out = WORK / "fastfetch"
    out.mkdir(exist_ok=True)
    script_path = script("pve-fastfetch-motd.sh")
    marker = next(line for line in Path(script_path).read_text(encoding="utf-8").splitlines()
                  if line.startswith("MANAGED_MARKER="))
    code = marker + "\n" + script_functions(
        script_path, ["tr_msg", "detect_bridge", "cert_module_block", "config_template", "render_config"])
    config = out / "config.jsonc"
    config.write_text(subprocess.run(["bash", "-c", code + "\nAPP_LANG=en\nrender_config '' ''"], check=True,
                                     capture_output=True, text=True).stdout)
    motd = subprocess.run(["unshare", "--net", "--uts", "--mount", "--fork", "bash", str(HERE / "fastfetch.sh"),
                           str(WORK / "root/usr/bin/fastfetch"), str(config)], check=True, capture_output=True).stdout
    (REPO / "site/demos/fastfetch-motd.ansi").write_bytes(motd)

    out = variant("scrollback", "util.js")
    engine(script("pve-xtermjs-scrollback.sh"), "PATCH_PY", {"UTIL_FILE": str(out / "util.js")}, "apply", "100000")


def main():
    fetch()
    build_variants()


if __name__ == "__main__":
    main()
