// Records a demo: drives the real Proxmox VE interface inside the browser frame
// of static/host.html, draws the mouse, and writes the frames plus a manifest
// that assemble.py turns into an animated WebP.
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const BASE = 'http://127.0.0.1:' + (process.env.DEMO_PORT || '8010');
const W = 1280, H = 800;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const ease = (t) => (t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2);

class Recorder {
    static async start(name, opts = {}) {
        const r = new Recorder();
        r.name = name;
        r.dir = path.join(__dirname, 'work', 'frames', name);
        fs.rmSync(r.dir, { recursive: true, force: true });
        fs.mkdirSync(r.dir, { recursive: true });
        r.frames = [];
        r.pos = { x: W * 0.6, y: H * 0.6 };
        r.browser = await chromium.launch();
        r.ctx = await r.browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
        await r.cookies(opts);
        r.page = await r.ctx.newPage();
        r.page.on('pageerror', (e) => console.error('pageerror', e.message));
        await r.page.goto(BASE + '/__demo/host.html');
        return r;
    }

    async cookies({ login = true, theme, lang, variant } = {}) {
        const c = (name, value) => ({ name, value, domain: '127.0.0.1', path: '/' });
        await this.ctx.clearCookies();
        const list = [c('PMTVariant', variant || 'stock')];
        if (login) list.push(c('PVEAuthCookie', 'PVE:root@pam:FAKE'));
        if (theme) list.push(c('PVEThemeCookie', theme));
        if (lang) list.push(c('PVELangCookie', lang));
        await this.ctx.addCookies(list);
    }

    async open(url, wait = 3500) {
        const i = await this.page.evaluate((u) => window.__demo.openTab(u, true), BASE + url);
        await sleep(wait);
        await this.ensureCaps(wait);
        return i;
    }

    // A real login stores the permissions of the user in the browser; the
    // datacenter panels fail without them, so give the fake session the same.
    async ensureCaps(wait) {
        const f = await this.frame();
        const missing = await f.evaluate(() => {
            if (typeof Ext === 'undefined' || !Ext.state.Manager.getProvider() || !PVE.UserName) return false;
            if (Ext.state.Manager.get('GuiCap').mapping) return false;
            const yes = (...ks) => Object.fromEntries(ks.map((k) => [k, 1]));
            Ext.state.Manager.set('GuiCap', {
                vms: yes('VM.Allocate', 'VM.Audit', 'VM.Console', 'VM.PowerMgmt', 'VM.Config.Options', 'VM.Snapshot', 'VM.Backup', 'VM.Clone', 'VM.Migrate'),
                storage: yes('Datastore.Audit', 'Datastore.Allocate', 'Datastore.AllocateSpace'),
                access: yes('User.Modify', 'Permissions.Modify', 'Group.Allocate'),
                nodes: yes('Sys.Audit', 'Sys.Modify', 'Sys.Console', 'Sys.PowerMgmt', 'Sys.Syslog'),
                dc: yes('Sys.Audit', 'Sys.Modify', 'SDN.Audit'),
                sdn: yes('SDN.Audit', 'SDN.Allocate'),
                mapping: yes('Mapping.Audit', 'Mapping.Modify'),
            });
            return true;
        });
        if (missing) {
            await this.page.evaluate(() => window.__demo.frame().contentWindow.location.reload());
            await sleep(wait);
        }
    }

    // the Playwright frame of the active tab, to query or drive ExtJS
    async frame() {
        const handle = await this.page.evaluateHandle(() => window.__demo.frame());
        return handle.asElement().contentFrame();
    }

    async reload(opts, wait = 3500) {
        await this.cookies(opts);
        await this.page.evaluate(() => window.__demo.frame().contentWindow.location.reload());
        await sleep(wait);
        await this.ensureCaps(wait);
    }

    // a guest or node row of the resource tree, in host coordinates
    async treeRow(text) {
        const f = await this.frame();
        const b = await f.getByText(text, { exact: true }).first().boundingBox();
        if (!b) throw new Error('not visible: ' + text);
        return { x: b.x + Math.min(40, b.width / 2), y: b.y + b.height / 2 };
    }

    // the bottom Logs panel, folded the way its own chevron does
    async foldLogs() {
        const f = await this.frame();
        await f.evaluate(() => { Ext.ComponentQuery.query('#south')[0].collapse(null, false); });
        await sleep(400);
    }

    // a tab of the browser frame, in host coordinates
    async tab(i) {
        const b = await this.page.locator('.tab').nth(i).boundingBox();
        return { x: b.x + 60, y: b.y + b.height / 2 };
    }

    // every tab of the browser frame reloads, as after reopening the consoles
    async reloadAll(opts, wait = 3000) {
        await this.cookies(opts);
        await this.page.evaluate(() => document.querySelectorAll('#pages iframe').forEach((f) => f.contentWindow.location.reload()));
        await sleep(wait);
    }

    badge(text, script) { return this.page.evaluate(([t, s]) => window.__demo.badge(t, s), [text, script]); }

    async shot(ms, fade) {
        const file = String(this.frames.length).padStart(4, '0') + '.png';
        await this.page.screenshot({ path: path.join(this.dir, file) });
        this.frames.push({ file, ms, fade: fade || 0 });
    }

    // keep filming for a while, one frame every step ms
    async film(total, step = 80) {
        for (let t = 0; t < total; t += step) {
            const started = Date.now();
            await this.shot(step);
            await sleep(Math.max(0, step - (Date.now() - started)));
        }
    }

    async move(x, y, duration = 700) {
        const from = { ...this.pos };
        const steps = Math.max(4, Math.round(duration / 45));
        for (let i = 1; i <= steps; i++) {
            const k = ease(i / steps);
            const px = from.x + (x - from.x) * k, py = from.y + (y - from.y) * k;
            await this.page.mouse.move(px, py);
            await this.page.evaluate(([a, b]) => window.__demo.cursor(a, b), [px, py]);
            await this.shot(45);
        }
        this.pos = { x, y };
    }

    async click(x, y, { button = 'left', after = 600 } = {}) {
        await this.move(x, y);
        await this.page.evaluate(([a, b]) => window.__demo.ripple(a, b), [x, y]);
        await this.page.mouse.down({ button });
        await this.page.mouse.up({ button });
        await this.film(after);
    }

    async type(text, delay = 90) {
        for (const ch of text) {
            await this.page.keyboard.type(ch);
            await this.shot(delay);
        }
    }

    // fills the login window of the active tab and submits it
    async login() {
        const f = await this.frame();
        const center = async (loc) => { const b = await loc.boundingBox(); return [b.x + b.width / 2, b.y + b.height / 2]; };
        let [x, y] = await center(f.locator('input[name=username]'));
        await this.click(x, y, { after: 200 });
        await this.type('root', 110);
        [x, y] = await center(f.locator('input[name=password]'));
        await this.click(x, y, { after: 200 });
        await this.type('secret12', 70);
        [x, y] = await center(f.getByRole('button', { name: /^(Login|Connexion)$/ }));
        await this.click(x, y, { after: 2400 });
    }

    async finish() {
        fs.writeFileSync(path.join(this.dir, 'manifest.json'), JSON.stringify(this.frames, null, 1));
        await this.browser.close();
    }
}

module.exports = { Recorder, sleep, BASE, W, H };
