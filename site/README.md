# The site

Static site published on GitHub Pages by `.github/workflows/pages.yml`.
No build step, no dependency: three files and one data file.

```text
site/
├── index.html        page shell, rarely changes
├── data.js           the scripts, THIS is what you edit
├── README.md         this file
└── assets/
    ├── styles.css    look and feel
    └── app.js        builds the cards from data.js
```

## Add a script

1. Push the script into `scripts/` on the `main` branch.
2. Open `site/data.js` and copy one block of `SCRIPTS`, paste it, change the values.
3. Commit on the `website` branch. The workflow redeploys, the card appears.

The run command, the "read the source" link and the history link are built from
`file`, so there is no URL to write by hand.

```js
{
    id: 'my-script',                       // anchor in the URL
    file: 'pve-my-script.sh',              // exact name inside scripts/
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
    terminal: {
        banner: 'proxmox',                 // 'proxmox' or 'wireguard'
        theme: 'orange',                   // 'orange' or 'red'
        subtitle: 'Line printed under the logo',
        panel: { title: 'Box title', lines: ['line one', 'line two'] },
        menu: ['First entry', 'Second entry', 'Quit'],
        prompt: 'Choose an option [1-3]:',
    },
},
```

`panel` and `note` can be removed if the script has none.

## Change a script that already exists

Edit its block in `data.js`. Only `updated` needs care: it is what shows up in
the "What's new" list, so keep it to one short sentence.

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
