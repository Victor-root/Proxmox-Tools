# The site

Static site published on GitHub Pages by `.github/workflows/pages.yml`.
No build step, no dependency: three files and one data file.

```text
site/
├── index.html        page shell, rarely changes
├── data.js           the scripts AND every interface string, THIS is what you edit
├── README.md         this file
└── assets/
    ├── styles.css    look and feel, light and dark themes
    └── app.js        builds the cards, handles language and theme
```

Every text is bilingual, written as `{ en: '…', fr: '…' }`. A missing French
string falls back to the English one, so nothing breaks while you translate.
Interface strings live in the `UI` block at the bottom of `data.js`.

Language follows the browser on the first visit, theme follows the system.
Both have a switch in the header and the choice is remembered afterwards.

## Add a script

1. Push the script into `scripts/` on the `main` branch.
2. Open `site/data.js` and copy one block of `SCRIPTS`, paste it, change the values.
3. Commit on the `website` branch. The workflow redeploys, the card appears.

The run command, the "read the source" link and the history link are built from
`file`, so there is no URL to write by hand.

```js
{
    id: 'my-script',                       // anchor in the URL
    icon: 'browser',                       // symbol name without the i- prefix
    file: 'pve-my-script.sh',              // exact name inside scripts/
    target: 'pve',                         // 'pve' host, or 'lxc' container
    name: 'What it is',
    tagline: 'One line, what it does.',
    runsOn: 'Proxmox VE host, as root',
    compat: 'PVE 9.x',                     // small badge on the card
    updated: 'What changed, one short line.',
    points: [
        'Three to five short bullets',
        'No long sentences',
    ],
    note: 'Optional warning shown in a quieter box.',
    touches: {                             // folded block, what it writes
        files: [
            { path: '/etc/some/file', role: 'what that file is' },
        ],
        installs: 'package-one, package-two',   // optional
        backup: '/root/my-script-<date>/',
        restarts: 'pveproxy',
    },
    terminal: {
        banner: 'proxmox',                 // 'proxmox' or 'wireguard'
        theme: 'orange',                   // 'orange' or 'red'
        host: 'root@pve01',                // window title and shell prompt
        subtitle: 'Line printed under the logo',
        panel: { title: 'Box title', lines: ['line one', 'line two'] },
        menu: ['First entry', 'Second entry', 'Quit'],
        prompt: 'Choose an option [1-3]:',
    },
},
```

`panel`, `note` and `touches.installs` can be removed if the script has none.

Fill `touches` from the script itself, never from memory: the paths at the top
of the file, the backup directory it builds, the services it restarts. It is
the block people read before running something as root, so it has to be exact.

`target` only picks the icon shown next to "Runs on": a server for the Proxmox
host, a container for a script that runs inside an LXC.

The first script of the list is also the one drawn in the hero terminal, under
the pasted command line. Move a block to the top to feature it there.

## Change a script that already exists

Edit its block in `data.js`. Only `updated` needs care: it is what shows up in
"What's new", where each card is a link down to the script it talks about, so
keep it to one short sentence.

## Change the questions

The "Questions people ask" section reads the `FAQ` list in `data.js`: one block
per question, `q` and `a`, both bilingual. Add or remove blocks freely, the
grid stays on two columns.

## Icons

Icons come from [Tabler Icons](https://tabler.io/icons) (MIT), outline set. They
live in one sprite at the top of `index.html`. To use a new one, copy the paths
of the published SVG into a `<symbol viewBox="0 0 24 24" id="i-name">`, drop the
invisible `stroke="none"` rectangle, then reference it anywhere with
`<svg class="ico"><use href="#i-name"/></svg>`. Keeping the `viewBox` matters:
without it the icon is drawn cropped.

A script card and its news card use the `icon` field of its block in `data.js`,
which is the symbol name without the `i-` prefix.

## Add a new ASCII logo

Only needed if a script ships a logo that is neither Proxmox nor WireGuard.
Add it to `BANNERS` at the bottom of `data.js`, then point `terminal.banner`
at its key. Copy the lines straight out of the script's `banner()` function so
the site shows exactly what the terminal shows.

## Preview it locally

```bash
cd site && python3 -m http.server 8000
```

Then open `http://localhost:8000`. Editing `data.js` and reloading is enough,
there is nothing to rebuild.

## First deploy

On GitHub: **Settings > Pages > Source: GitHub Actions**. The workflow runs on
every push to `website` that touches `site/`, and can also be started by hand
from the Actions tab.
