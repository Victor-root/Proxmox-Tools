# Modern theme sources

The themes installed by [`scripts/pve-modern-theme.sh`](../../scripts/pve-modern-theme.sh) are generated from this folder. The script stays self contained: the generated CSS is embedded in it, between the `# >>> generated` and `# <<< end of generated part` markers. Do not edit that part by hand, change the sources here and rebuild.

## What is in here

* `scss/_tokens.scss`, `_modern.scss`, `_light.scss`, `_extras.scss`, `_titlebars.scss`: the layers of the Modern look, written on top of the official Proxmox dark theme
* `build.py`: fetches the official dark theme SCSS from [proxmox-widget-toolkit](https://github.com/proxmox/proxmox-widget-toolkit) at a pinned commit, sets the colors of each accent and mode, inlines the [Phosphor](https://phosphoricons.com) icons (MIT license), compiles every theme and writes them into the script
* `package.json`: the exact versions of the build tools (`sass` and `@phosphor-icons/core`)

## How the themes are built

* **Dark** themes are the official dark theme recolored, plus the Modern layers.
* **Light** themes are the stock light theme (crisp) plus `_light.scss` and the Modern layers.
* **Auto** themes hold both, each behind a `prefers-color-scheme` media query.

To keep the script small, it only carries the orange light and dark themes, split around the part they share (mostly the icons), and for each other accent the list of colors to swap. `build.py` checks that this rebuilds every theme byte for byte and stops otherwise.

## Rebuild

Needs Python 3, Node.js and git:

```bash
npm ci
python3 build.py
```

Then test the script again as described in [AGENTS.md](../../AGENTS.md).
