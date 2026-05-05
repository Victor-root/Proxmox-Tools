# Proxmox-Tools

A growing hub of useful shell scripts for **Proxmox VE**.

Fast to run. Easy to reuse. Built for real-world homelab and admin workflows.

---

## ✨ What is this repository?

**Proxmox-Tools** is a central place for small, practical, focused scripts made to improve day-to-day life on **Proxmox VE**.

The goal is simple:

- keep each tool **independent**
- ⚡ make scripts runnable in **one command**
- keep behavior **clear and predictable**
- always prefer **safe changes with backup/restore when possible**
- build a reusable **toolbox / hub** instead of one giant script

This repository is meant to grow over time with more Proxmox-oriented utilities.

---

## Repository philosophy

Each script lives as its **own file** inside the `scripts/` directory.

That means:

- you can call **one specific script** directly
- you do **not** need a global installer for everything
- each tool can evolve independently
- sharing a tool is easy with a targeted raw GitHub URL

Example layout:

```text
scripts/
├── pve-console-newtab.sh
├── pve-default-language-i18n
├── future-tool-1.sh
├── future-tool-2.sh
└── ...
```

---

## 🧰 Available scripts

### `pve-console-newtab.sh`

Adds a more convenient browser workflow for the Proxmox VE web interface:

- 🖱️ **Middle click** on the main **Console** button opens the default web console in a **new tab**
- 🖱️ **Middle click** on **noVNC** opens it in a **new tab**
- 🖱️ **Middle click** on **xterm.js** opens it in a **new tab**
- 🖱️ **Middle click** on **SPICE** behaves like a normal click, without opening a useless browser tab
- automatic **backup** before patching
- ♻️ built-in **restore** options
- interactive menu

#### Run it directly

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Victor-root/Proxmox-Tools/main/scripts/pve-console-newtab.sh)
```

#### Alternative method

```bash
curl -fsSL https://raw.githubusercontent.com/Victor-root/Proxmox-Tools/main/scripts/pve-console-newtab.sh -o /tmp/pve-console-newtab.sh && bash /tmp/pve-console-newtab.sh
```

---

### `pve-default-language-i18n`

Changes the default language configuration of a Proxmox VE host.

It can update both the **system shell locale** and the **Proxmox VE web interface language**:

- enables and generates the selected locale in `/etc/locale.gen`
- updates the system locale through `/etc/default/locale`
- removes old persistent `LC_ALL` / `LC_*` overrides that could force the wrong language
- writes a shell profile helper in `/etc/profile.d/proxmox-tools-locale.sh`
- updates the Proxmox VE web interface language in `/etc/pve/datacenter.cfg`
- can update timezone and enable NTP with `timedatectl`
- detects the server language and displays the script UI in that language when available
- falls back to English if the server language is unknown or unsupported
- supports Proxmox VE UI language targets such as `fr`, `en`, `de`, `es`, `it`, `pt_BR`, `zh_CN`, and more
- automatic **backup** before changes
- ♻️ built-in **restore** options
- interactive menu

> Keep an active **root SSH session** open while running this script, in case the Proxmox VE web interface does not restart correctly.

#### Run it directly

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Victor-root/Proxmox-Tools/main/scripts/pve-default-language-i18n)
```

#### Alternative method

```bash
curl -fsSL https://raw.githubusercontent.com/Victor-root/Proxmox-Tools/main/scripts/pve-default-language-i18n -o /tmp/pve-default-language-i18n && bash /tmp/pve-default-language-i18n
```

---

## Safety notes

Some tools in this repository may modify Proxmox files or behavior.

Before using any script:

- read what it does
- keep an active **root SSH session** open
- make sure you understand the rollback path
- prefer testing on a non-critical node first

When relevant, scripts in this repository should:

- create backups before changes
- fail safely if expected patterns are not found
- avoid destructive behavior by default

---

## Project goals

This repo is intended to become a practical **Proxmox utility hub**, for example:

- UI enhancements
- backup helpers
- audit / health-check scripts
- storage / ZFS helpers
- cluster helpers
- networking helpers
- quick-fix admin tools

The main idea is not to build a huge framework.

The idea is to keep things:

- simple
- useful
- modular
- easy to launch

---

## Contributing

Ideas, fixes, and improvements are welcome.

Good contributions are usually:

- focused on one real problem
- easy to understand
- safe to test
- easy to remove or rollback

---

## Disclaimer

These scripts are provided as-is. Use them carefully, review them before running them, and test them in your own environment.

---

## ⭐ Why this repo exists

Because Proxmox is great, but there are always a few small things that can be made faster, cleaner, or less annoying with the right script.

This repository exists to collect those improvements in one place.
