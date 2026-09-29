# AGENTS.md

Instructions for an AI assistant that has to add or change a script in this repository.

If you are the human: tell your assistant "read AGENTS.md at the root of this repository and follow it to add a script that does X". Everything it needs is below. The bar is deliberately high: this repository patches files of a hypervisor as root, so a script that merely works on the author's machine is not acceptable.

If you are the assistant: read the whole file before touching anything, then work through the phases in order. Do not skip the research and the testing phases, they are where the bugs that already cost us time were caught or missed.

---

## 1. What this repository is

A collection of independent Bash scripts that fix, patch or configure Proxmox VE hosts (and a few LXC containers), plus a static website (`site/`) that presents every script with its run command and a preview of its menu.

Principles that explain most of the rules below:

* **One script, one file, self contained.** People run it with `bash <(curl -fsSL https://raw.githubusercontent.com/Victor-root/Proxmox-Tools/main/scripts/<file>)`. A script must never source another file of the repository. Code that looks duplicated between scripts (colors, panels, banner, backups, menu) is duplicated on purpose.
* **Safe by default.** Back up before changing anything, ask before writing, refuse when the environment is not exactly what was expected, always offer a way back.
* **Focused.** One real problem per script. Easy to understand, easy to test, easy to remove.
* **Honest.** Compatibility badges, "what this script touches" blocks and warnings must be true. Nothing is claimed that was not verified.
* **Bilingual.** Every user facing text exists in English and French.

License: GNU AGPL v3. Do not add code you cannot license under it.

## 2. Repository map

```text
scripts/            one file per script, named pve-<thing>.sh (Proxmox host) or lxc-<thing>.sh (inside a container)
site/
  index.html        page shell and the SVG icon sprite (rarely changes, except to add an icon)
  data.js           every script card and every interface string: this is what you edit
  assets/           styles.css and app.js, you normally never touch them
  README.md         notes on the site
.github/workflows/pages.yml   deploys site/ to GitHub Pages on every push to main that touches site/
.github/assets/     screenshots of the site shown at the top of README.md
README.md           one collapsible section per script
CONTRIBUTING.md     what a good pull request looks like, and the stance on AI assisted contributions
LICENSE             AGPL v3
```

Reference scripts, pick the closest one as your starting point and copy its shared engine:

| Kind of script | Start from |
| --- | --- |
| Patches a file shipped by a Proxmox package (most common) | `scripts/pve-expand-node-tree.sh` or `scripts/pve-xtermjs-scrollback.sh` |
| Patch with several independent options, plus an optional APT hook that re-applies it after updates | `scripts/pve-remove-subscription-notice.sh` |
| Installs a package and writes configuration | `scripts/pve-fastfetch-motd.sh` |
| Changes system settings (locale, datacenter.cfg) | `scripts/pve-default-language-i18n` (legacy file name without extension, do not copy that) |
| Runs inside an LXC container | `scripts/lxc-wireguard-server-install.sh` (older, its own i18n loader and French comments, do not copy that part) |

## 3. Hard rules

These apply to every file you write. A reviewer will check them one by one.

1. **Never use the em dash character** anywhere: scripts, README, site texts, commit messages. Use a comma, a colon, parentheses or two sentences.
2. **Never guess how Proxmox works.** Read the real source or the real installed file, and be able to say where you read it. If you could not verify something, say so in your report to the human, do not paper over it.
3. **No hacks, no fragile workarounds.** No global `sed` that could match twice, no "it works on my machine" anchors, no temporary fix left in.
4. **No dead code.** No commented out code, no unused variable or translation key, no leftover of a failed attempt. If an attempt fails, remove everything it added (code, files, imports, config, comments).
5. **Comments only for the why**, short, in English: a hidden constraint, a subtle invariant, a workaround for a specific bug. Never comment what the code plainly says, never mention the task or the conversation that produced it.
6. **Every text shown to a user exists in `en` and `fr`**, in the script and on the site.
7. **Never hard code a domain, an IP address, a hostname or a secret.** Detect or ask.
8. **Never touch `main`.** Work on a dedicated branch (see section 12).
9. **Re-read your complete diff before saying you are done** and delete every unneeded change, duplication or residue.
10. **Do not edit files that belong to other scripts** unless the change is the point of your task.

## 4. Phase 0: understand and challenge the request

Before anything else, make sure you know:

* what annoys the user, in one sentence, and what "fixed" looks like
* which Proxmox VE versions must be supported (8.x, 9.x, or a range)
* whether the change is per user, per node, or per cluster

Then **challenge the idea of patching**. In this order, look for something cleaner than modifying a shipped file:

1. a documented setting (`/etc/pve/datacenter.cfg`, a per node or per guest option, an API parameter, a `pveum` or `pvesh` command)
2. a setting Proxmox already reads but exposes no UI for (for example browser storage keys read by the web interface)
3. only then, a patch of a file shipped by a package

If a native way exists but does not fit (for example it is per browser and the user has many computers), that is a valid reason to patch, but write the reasoning down in your report.

If the request is ambiguous, ask the human. Otherwise do not interrupt them with questions you can answer by reading the sources.

## 5. Phase 1: research in the real Proxmox sources

The Proxmox source is public. Fetch it, do not rely on memory.

```bash
git clone --depth 1 https://github.com/proxmox/pve-manager.git          # PVE 9 line (master)
git ls-remote --heads https://github.com/proxmox/pve-manager.git         # find the PVE 8 branch (stable-8) or the older ones
```

Useful repositories under `github.com/proxmox/`: `pve-manager` (web interface in `www/manager6/`, Perl API), `proxmox-widget-toolkit` (shared JavaScript, `proxmoxlib.js`), `pve-xtermjs` (web consoles), `pve-http-server` (how `pveproxy` serves files). If the GitHub API is blocked in your environment, `git clone` and `raw.githubusercontent.com` normally still work. Third party code such as ExtJS or the minified xterm.js bundle is not in these repositories, grep the shipped file itself.

What to establish, with evidence:

* **Where the behaviour lives**: which file, which function, which package ships it (`dpkg -S /path/to/file` on a real host tells you the package; the package version shown by `pveversion -v` is what the script should display and compare).
* **How the file reaches the disk.** Example that matters: the many `www/manager6/*.js` files are concatenated into one `/usr/share/pve-manager/js/pvemanagerlib.js`. **Your anchor has to be unique in the whole assembled file, not in the source file you found it in.** Reproduce the assembly and count:

  ```bash
  find www/manager6 -name '*.js' | sort | xargs cat > /tmp/assembled.js
  ```

  Then count your anchor in `/tmp/assembled.js` with a small Python check. A one line anchor like `collapsible: true,` looked unique in its file and matched three places in the assembled one.
* **Is the code identical on every version you will claim?** Diff the exact block between the PVE 8 and PVE 9 branches, and walk the file history (`git log -S'<anchor>' -- <file>`) to see every published form. Only claim "PVE 8.x / 9.x" if the block is byte identical or if the script handles each form. If something changed at some point (a reformatting, a renamed function), say from which release the script works.
* **How the file is served and cached.** For static files served by `pveproxy`, `pve-http-server` reads the file on each request and sends only `Last-Modified` (no `Cache-Control`, no expiry), so a restart may not be needed but **browsers can keep the old copy for days**. Decide from the source whether a service restart is really required, and say what you found. Existing scripts restart `pveproxy` (which can make the web interface unreachable for up to a minute), do not add a restart you cannot justify and do not omit one you cannot prove is unnecessary.
* **What survives a package update.** Patched files are overwritten when their package is updated. The script must say so, and may offer the opt in APT hook pattern from `pve-remove-subscription-notice.sh` (a hook in `/etc/apt/apt.conf.d/` that re-applies only what the user applied, with its own on/off menu entries).
* **Side effects and limits** of the change: memory, performance, security, behaviour for other users of the same feature. Put the real ones in the warning and on the site, with figures you measured or derived, never invented ones.

Keep notes of your findings as you go, you will need them for the script comments, the README and the report.

## 6. Phase 2: design

Decide, and be able to defend:

* the smallest change that solves the problem (a one line patch beats a rewritten function)
* the exact anchor: **a whole block, including the exact indentation, anchored on something unique** (an identifier such as a `stateId`, an `itemId`, a function name). Never a bare short string.
* the states the target file can be in: stock, patched (possibly with another parameter value), unknown. Unknown means "refuse and change nothing".
* what a user can choose (options, values) and what is constant
* the rollback path: restore from backup, and where useful a direct "put it back" entry
* the menu, in this order for a patch script: apply, restore latest backup, restore from a chosen backup, show status, list backups, then the script specific entries, then quit

## 7. Phase 3: write the script

### 7.1 Skeleton

Copy the closest reference script and keep its order. A patch script is laid out like this:

```text
#!/usr/bin/env bash
set -euo pipefail
constants (PATCH_PREFIX, target file paths, anchors) with the WHY comment above them
detect_lang, tr_msg (all translations)
APP_NAME, colors, term_width, hr, panel, say_info/ok/warn/err, banner, show_banner, pause, confirm_yes
require_root, require_files, show_warning_and_confirm
patch state: detection and the python (or sed) patch functions
backups: latest_backup_dir, list_backups_raw, create_backup, pkg_version_from_backup, installed_pkg_version
actions: show_status, apply, ...
confirm_backup_versions, restore_specific, restore_latest, interactive_restore_menu, show_backups
menu_action, main_menu
require_root; require_files; main_menu      (the last three lines)
```

Shared engine, copy it unchanged from the reference script rather than rewriting it: language detection, colors (only when stdout is a terminal), `panel`, the ASCII banner (the `PROXMOX` logo, orange theme, for Proxmox host scripts), backups with `INFO.txt` and `SHA256SUMS.txt`, version mismatch check on restore, `menu_action`.

### 7.2 Conventions

* `set -euo pipefail`. Four spaces of indentation. Quote every expansion. Use `local` in functions. No `eval`.
* Backup directory: `/root/<script-name>-patch-<YYYY-MM-DD-HHMMSS>/` containing a copy of every file the script modifies, `INFO.txt` (timestamp, hostname, path, output of `pveversion -v`) and `SHA256SUMS.txt`. `PATCH_PREFIX` holds the path prefix.
* Root only, with a clear message. Check that required tools exist (`python3`, `sha256sum`, ...), and that the target file exists.
* Language: English by default, French when the system locale starts with `fr` (`detect_lang`). Translations live in one big `tr_msg` `case` with a `fr:key` line and an `en:key` line for every key, the French line first (that is the existing order in every script). Keys are lowercase with underscores. Texts that embed values compute them at call time.
* Prompts: destructive or file modifying actions ask the user to type `yes`. Show a warning panel that says what is modified, that it is unsupported, that package updates overwrite it, and any real side effect. Menu actions go through `menu_action` so a failing action returns to the menu instead of ending the session through `set -e`, then `pause`.
* Validate every user input with an anchored regex and a range check. Force base 10 when doing arithmetic on typed numbers (`$((10#$value))`), otherwise a leading zero is read as octal.
* Temporary files: `mktemp` and a `trap` cleanup. Files holding secrets: restrictive `umask`/permissions.
* Never leave the system half changed: on failure after a backup, say what happened and how to restore.
* `pveproxy` (or any service) restart, if needed: use a `restart_pveproxy` function that warns the user it can take up to a minute and that the script is not frozen.
* `set -e` gotcha: a function whose last command is `[[ cond ]] && something` returns 1 when the condition is false. Use `if`.

### 7.3 Patching a file

Use the pattern of the reference scripts: a short Python heredoc that receives the path (and values) through environment variables, checks that the anchor occurs **exactly once**, replaces that one occurrence, and exits non zero otherwise. Use `sed` only for genuinely single line, quote free anchors (as `pve-remove-subscription-notice.sh` does).

```bash
apply_python_patch() {
    TARGET_FILE="$TARGET_FILE" python3 <<'PY'
from pathlib import Path
import os
import sys

path = Path(os.environ["TARGET_FILE"])
text = path.read_text(encoding="utf-8")

anchor = (
    "                    stateId: 'example',\n"
    "                    collapsible: true,\n"
)
if text.count(anchor) != 1:
    sys.exit(1)

path.write_text(text.replace(anchor, anchor + "                    collapsed: true,\n", 1), encoding="utf-8")
PY
}
```

If the heredoc terminator (`PY`) appears inside the code you generate, pick another one.

**State detection must match the whole anchored block, never a bare grep for the text you add.** `grep -F "collapsed: true,"` reported "already applied" on an untouched Proxmox because that text exists elsewhere in the stock file. A robust detector reports one of three states (`stock`, `patched`, `unknown`) by counting whole blocks:

```bash
get_state() {
    TARGET_FILE="$TARGET_FILE" python3 <<'PY'
from pathlib import Path
import os

text = Path(os.environ["TARGET_FILE"]).read_text(encoding="utf-8")
stock = text.count("<whole stock block>")
patched = text.count("<whole patched block>")
print("patched" if patched == 1 and stock == 0 else "stock" if stock == 1 and patched == 0 else "unknown")
PY
}
```

If the patch has a variable part (a user chosen number), match it with a regex, report it in the state (`patched:N`), and let the user change it by applying again.

Required behaviours of the apply action:

* already applied: say so, change nothing, create no backup
* unknown structure: print that this version is not supported, that no file was modified, return failure, create no backup
* confirmation refused: change nothing
* otherwise: backup, patch, **verify by detecting the new state**, and only then report success and, if needed, restart
* the restore actions bring the file back byte for byte

### 7.4 Scripts that install or configure things (not patches)

Follow `pve-fastfetch-motd.sh`: check you are on a Proxmox host when relevant, download only from the official source of the tool, detect the CPU architecture instead of assuming one, verify what you downloaded before using it, keep the original state before overwriting it so a removal can restore it, make re running safe, and offer removal at two levels when it makes sense (stop the feature, or remove everything).

## 8. Phase 4: test, for real

You usually cannot run a Proxmox host. That is no excuse for not testing: reproduce the situation from the real sources.

Checklist, all of it:

1. `bash -n scripts/<file>` passes. `shellcheck` too if available.
2. **Translation completeness**, both directions:

   ```bash
   f=scripts/<file>
   for k in $(grep -o 'tr_msg [a-z_0-9]*' $f | awk '{print $2}' | sort -u); do
     grep -q "en:$k)" $f && grep -q "fr:$k)" $f || echo "MISSING $k"; done
   for k in $(grep -o 'en:[a-z_0-9]*)' $f | sed 's/en://;s/)//'); do
     [ "$(grep -c "tr_msg $k\b" $f)" -gt 0 ] || echo "UNUSED $k"; done
   ```
3. **Run the patch functions against the real upstream files**, for every version and form you claim (PVE 9 branch, PVE 8 branch, and the historical forms found in the file history). Assemble the file the way Proxmox does (section 5) so uniqueness is tested for real. Check that: exactly the intended lines change, the result is syntactically valid (`node --check file.js`, `perl -c` for Perl, `python3 -m py_compile`, ...), applying twice is refused, the restore gives a file identical to the original (`cmp`).
4. **Run the whole script in a sandbox**, driving the menu through stdin. Redirect the hard coded paths in a *copy* of the script, because the script assigns its own variables and environment variables would be overwritten:

   ```bash
   sed -e "s|^TARGET_FILE=.*|TARGET_FILE=\"$SANDBOX/target.js\"|" \
       -e "s|^PATCH_PREFIX=.*|PATCH_PREFIX=\"$SANDBOX/root/patch\"|" \
       -e "s|find /root -maxdepth 1|find $SANDBOX/root -maxdepth 1|g" scripts/<file> > $SANDBOX/run.sh
   printf '1\nyes\n\n<last menu number>\n' | bash $SANDBOX/run.sh
   ```

   (Applying twice within the same second reuses the same backup directory name, add a `sleep 1` between applications in tests.) Exercise: apply, apply again, status, restore latest, restore a chosen one, cancel at each prompt, invalid menu choice, invalid typed values, a target file that no longer has the expected structure, not being root, both languages (`LANG=fr_FR.UTF-8`).
5. **When the behaviour is visible in a browser, test it in a real browser with the real library.** Example: load the real xterm.js bundle in headless Chromium with the patched `util.js`, write test data and read the resulting buffer. Unit checks of extracted functions with mocked objects are not enough for UI behaviour.
6. Anything you could not test (typically: the real host, the real Proxmox UI) goes in your report as **not verified**, with what the human should check.

## 9. Phase 5: README section

Add one collapsible section to `README.md`, **at the end of the list of scripts** (after the last `</details>`, before the `---` that precedes "Repository philosophy"). The counter badge at the top counts the files of `scripts/` by itself, do not edit it.

````markdown
<details>
<summary><b>🖥️ Short title of the script</b></summary>

**Script:** `pve-my-script.sh`

One sentence saying what it fixes or adds:

* 🎯 concrete behaviour, with an emoji, one line each
* 🔎 safety property (exact match, refuses when unsure, ...)
* 💾 automatic **backup** before patching
* ♻️ built-in **restore** options
* 📋 interactive menu

#### Good to know

* side effects, limits, what package updates do, browser cache, ...

#### Version compatibility

What was checked and against what ("the patched block is identical from PVE 8 to 9.2"), and what the script does on an unsupported version ("stops with a clear message, creates no backup and leaves the file untouched").

#### Run it directly

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Victor-root/Proxmox-Tools/main/scripts/pve-my-script.sh)
```

</details>
````

Write in the tone of the existing sections: short bullets, bold for the key words, honest warnings in `> ℹ️` or `> ⚠️` quotes. Keep it in sync with the script: if the menu or the behaviour changes, update the README in the same change.

## 10. Phase 6: website card

Edit `site/data.js` (and `site/index.html` only to add an icon). Never edit `site/assets/`.

### 10.1 The block

Append a block **at the end of the `SCRIPTS` array** (the first block is the one drawn in the hero terminal, do not reorder). The run command, the "read the source" link and the history link are built from `file`, never write a URL.

```js
    {
        id: 'my-script',                       // URL anchor, lowercase, no spaces
        icon: 'history',                       // sprite symbol name without the i- prefix
        file: 'pve-my-script.sh',              // exact file name in scripts/
        target: 'pve',                         // 'pve' (host) or 'lxc' (container), only picks an icon
        name: { en: 'What it is', fr: 'Ce que c’est' },
        tagline: { en: 'One line, what it does.', fr: 'Une ligne, ce que ça fait.' },
        runsOn: { en: 'Proxmox VE host, as root', fr: 'Sur l’hôte Proxmox VE, en root' },
        compat: 'PVE 8.x / 9.x',                // small badge, same text in both languages
        updated: { en: 'New script. ...', fr: 'Nouveau script. ...' },
        points: {                              // 3 to 5 short bullets, same count in both languages
            en: ['...', '...', '...'],
            fr: ['...', '...', '...'],
        },
        touches: {                             // folded block, what the script writes
            files: [
                { path: '/usr/share/...', role: { en: 'what changes in it', fr: 'ce qui change dedans' } },
            ],
            installs: 'package-one',           // optional
            backup: '/root/my-script-patch-<date>/',
            restarts: 'pveproxy',              // optional, omit if nothing is restarted
        },
        note: { en: 'Optional warning.', fr: 'Avertissement optionnel.' },   // optional
        terminal: {
            banner: 'proxmox',                 // 'proxmox' or 'wireguard'
            theme: 'orange',                   // 'orange' or 'red'
            host: 'root@pve01',
            subtitle: 'Text printed under the logo, as the script prints it',
            panel: { title: 'Patch status', lines: ['Detected version: pve-x 1.2.3', '...'] },   // optional
            menu: ['Entry 1', 'Entry 2', 'Quit'],
            prompt: 'Choose an option [1-3]:',
        },
    },
```

### 10.2 Rules

* **Everything is bilingual** (`{ en, fr }`). French strings use the typographic apostrophe `’`.
* `updated` is what the "What's new" cards show, one short sentence. A brand new script starts with `New script.` / `Nouveau script.`. For a later change, describe the change in one sentence.
* `touches` is filled **from the script itself**, never from memory: the paths at the top of the file, the backup directory it builds, the services it restarts. It is the block people read before running something as root, it has to be exact.
* `terminal` reproduces the script **exactly as it runs in English**, not translated: same subtitle, same status panel wording, the menu entries in the same order with the same text, the same prompt (`[1-N]`). When you change the script's menu or texts, change this block too.
* `compat` must match what you verified in phase 1.
* `points`: concrete and short, no long sentences.
* Icon: from [Tabler Icons](https://tabler.io/icons) (MIT), outline set. Add it to the sprite at the top of `site/index.html` as `<symbol viewBox="0 0 24 24" id="i-name">...</symbol>`, copying only the visible paths (drop the invisible `stroke="none"` rectangle), keeping the `viewBox`. Reuse an existing icon when it fits, check the sprite first.
* A logo other than Proxmox or WireGuard goes in `BANNERS` at the bottom of `data.js`, copied line by line from the script's `banner()`.

### 10.3 Check it

```bash
node --check site/data.js
cd site && python3 -m http.server 8000
```

Open the page and check, in **both languages** and **both themes** (light and dark, and the header switches): the card renders, the icon shows, the "What's new" card links to it, the folded "what this script touches" block is right, the terminal preview matches the script, there is no error in the browser console and nothing overflows on a phone width. Only refresh the screenshots in `.github/assets/` if the top of the page changed, which adding a card at the end does not do. The site deploys from `main` (see `.github/workflows/pages.yml`).

## 11. Phase 7: quality gate

Before you report, go through this list and fix what fails. Every box must be ticked or explicitly reported as not verified.

**Research**
- [ ] I looked for a native, cleaner way than patching and can say why it does not fit
- [ ] I read the real source, and I know which package ships the target file
- [ ] The anchor is a whole block, with exact indentation, unique in the **assembled** file
- [ ] I compared the block across every version I claim and walked the file history
- [ ] I know whether a restart is needed and whether browsers can cache the file, from the source
- [ ] Side effects and figures in the warning are measured or derived, not invented

**Script**
- [ ] Self contained, `set -euo pipefail`, root check, tools check, target file check
- [ ] State detection matches whole blocks (stock, patched, unknown), never a bare grep of the added text
- [ ] Already applied: no change, no backup. Unknown structure: refuses, no change, no backup
- [ ] Confirmation typed `yes` before any write, warning panel accurate
- [ ] Backup with `INFO.txt` and `SHA256SUMS.txt`, restore latest and restore chosen, version mismatch warning on restore
- [ ] Result verified after writing, success only reported after that
- [ ] Menu goes through `menu_action`, numbering and prompt range are consistent
- [ ] User input validated, base 10 forced, no `eval`, variables quoted
- [ ] Every key exists in `en` and `fr`, none unused, no em dash
- [ ] Comments only explain the why, no dead code, no leftover

**Tests**
- [ ] Patch functions run on the real upstream files of every claimed version and form
- [ ] Apply, apply twice, restore (byte identical), cancel, invalid input, unexpected structure, not root, both languages
- [ ] Behaviour checked in a real browser or real runtime when it is visible there
- [ ] `bash -n`, translation check, JS/Perl syntax check of the patched result

**README and site**
- [ ] README section added at the end, same facts as the script
- [ ] `site/data.js` block appended at the end, bilingual, `touches` exact, `terminal` identical to the script, `compat` verified
- [ ] Icon added or reused, page checked in both languages and both themes, no console error
- [ ] Nothing else in `site/` or `README.md` changed by accident

**Diff**
- [ ] I re-read the complete diff, removed every useless change, and no file outside the task is touched

## 12. Phase 8: git and handoff

* Create a branch named after the script in kebab case (for example `xterm-scrollback`). **Never commit to or push `main`.**
* Commit messages: English, imperative, first line short, a body that explains the why. Keep coherent commits (script, then README and site, or all together for a small script). Do not amend commits that were already pushed.
* Push only your branch. Do not open a pull request unless the human asks you to. When they do, follow `CONTRIBUTING.md`: one focused change, a description a human can read (problem, what the change does, no code level detail), a mention that it was AI assisted, and a **Testing** section saying what was really run and where.
* Commits on `main` are signed by the maintainer, who re-signs and merges the branch with a fast forward. Do not try to merge it yourself. A contributor without write access works from a fork and opens a pull request, the maintainer takes it from there.
* Before the merge, the script can be tried from its branch: `bash <(curl -fsSL https://raw.githubusercontent.com/Victor-root/Proxmox-Tools/<branch>/scripts/<file>)`. The definitive command on the site and in the README uses `main`.

## 13. What to tell the human

Keep it short, in plain words, in the language the human uses. Say:

1. what you built and where (branch, files)
2. what you verified and how (which versions, which tests, real browser or not)
3. what you could **not** verify and what they should check on a real host
4. the real side effects and limits they should know about
5. the command to try it from the branch

Never claim something works because it should. If you have a doubt about a fix, say so plainly and add a way to observe it rather than hoping.

## 14. Pitfalls that already happened here

Learn from these, each one was a real bug or a near miss.

* **An anchor unique in its source file but not in the assembled file.** The patch silently refused to apply on real hosts (the uniqueness guard did its job), while every test on the single source file passed. Always test on the assembled file.
* **A state detector that grepped for the added text.** That text already existed elsewhere in the stock file, so the script claimed the patch was applied when it never wrote anything, and the "undo" then failed. Detect the whole block.
* **Browser cache.** The server sends no expiry for these static files, so a browser may keep the old copy for days and even a hard refresh is not always enough. Tell the user to verify in a private window and to clear the site data in each browser. Do not present a refresh as a guaranteed fix.
* **A result box that looked like a confirmation.** A script cannot see what the user's browser does. Text printed after a test must read as an explanation of how to interpret it, not as a verdict.
* **Assuming a restart is needed, or not.** Read how the file is served, then decide.
* **A quick test that reused one backup directory** because two applications happened in the same second. It is a test artifact, sleep between applications in tests.
* **`[[ ... ]] && x` as the last line of a function under `set -e`.** Use `if`.
* **A leading zero read as octal** in arithmetic on typed numbers. Use `10#`.
* **Claims in the README, on the site, and in the script drifting apart** after a change of behaviour. Update all three together.
