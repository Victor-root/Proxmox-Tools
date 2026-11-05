# Site demos

The animated pictures shown on the cards of the site (`site/demos/*.webp`) are recorded from here. Each one shows the **real Proxmox VE web interface**, as shipped and then patched by a script of this repository, in a browser driven by a script, with demo data served by a fake API.

## What is in here

* `prepare.py`: downloads the official Proxmox VE packages the interface is made of (pinned versions, checked against their SHA256) into `work/root`, then builds `work/variants`: the same files patched by the scripts' own code (`ENGINE_PY` / `PATCH_PY` / the sed expression they apply), one directory per state a recording shows
* `server.py`: serves those files with a fake API, a cookie picking the variant; it also answers the xterm.js consoles with a small shell
* `static/host.html`: the browser frame the recordings run in (tabs, address bar, mouse pointer, the label showing which state is on screen)
* `lib.js`: drives the interface with [Playwright](https://playwright.dev) and writes the frames
* `record/<name>.js`: one recording each, named after the file it produces
* `assemble.py`: turns the frames into an animated WebP, with short fades between the states
* `run.py`: does all of the above and writes `site/demos/<name>.webp`

## Record again

Needs Python 3 with Pillow, `dpkg-deb`, Node.js and network access:

```bash
npm ci
npx playwright install chromium
python3 run.py
```

`python3 run.py modern-theme` records only the named ones.

Record again when a script changes what it shows, and check the result frame by frame before committing it.

## Add one

Write `record/<name>.js` from the closest existing one, add the variant it needs to `prepare.py` (patched by the script's own code, never by hand), run `python3 run.py <name>`, then point the card at it with a `demo` block in `site/data.js`.
