/* Builds the page from data.js, handles language and theme.
 * Nothing here needs to change when a script is added: edit data.js only. */

(function () {
    'use strict';

    const REPO_URL = 'https://github.com/' + SITE.repo;
    const AUTHOR_URL = 'https://github.com/' + SITE.author;
    const RAW_BASE = 'https://raw.githubusercontent.com/' + SITE.repo + '/' + SITE.branch + '/' + SITE.scriptsDir + '/';
    const BLOB_BASE = REPO_URL + '/blob/' + SITE.branch + '/' + SITE.scriptsDir + '/';

    const LANGS = ['en', 'fr'];
    const THEMES = ['system', 'light', 'dark'];

    /* where a script runs, from the target field of data.js */
    const TARGET_ICON = { pve: 'server', lxc: 'box' };

    let lang = 'en';

    const esc = (s) => String(s).replace(/[&<>"']/g, (c) => (
        { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
    ));

    /* value can be a plain string (same in every language) or { en, fr } */
    const tr = (value) => {
        if (value === null || value === undefined) return '';
        if (typeof value === 'string') return value;
        return value[lang] !== undefined ? value[lang] : (value.en || '');
    };

    const icon = (name, cls) =>
        '<svg class="ico' + (cls ? ' ' + cls : '') + '" aria-hidden="true"><use href="#i-' + name + '"/></svg>';

    const store = {
        get(key) { try { return localStorage.getItem(key); } catch (e) { return null; } },
        set(key, value) { try { localStorage.setItem(key, value); } catch (e) {} },
    };

    /* ---------- theme ---------- */

    const systemDark = () => window.matchMedia('(prefers-color-scheme: dark)').matches;

    function applyTheme(mode) {
        const dark = mode === 'dark' || (mode === 'system' && systemDark());
        document.documentElement.dataset.theme = dark ? 'dark' : 'light';
        document.documentElement.dataset.themeMode = mode;
        document.querySelectorAll('#theme-seg button').forEach((b) => {
            b.setAttribute('aria-pressed', String(b.dataset.themeMode === mode));
        });
    }

    function initTheme() {
        const saved = store.get('pmt-theme');
        const mode = THEMES.indexOf(saved) !== -1 ? saved : 'system';
        applyTheme(mode);

        document.querySelectorAll('#theme-seg button').forEach((btn) => {
            btn.addEventListener('click', () => {
                store.set('pmt-theme', btn.dataset.themeMode);
                applyTheme(btn.dataset.themeMode);
            });
        });

        // follow the system while the "system" mode is active
        const mq = window.matchMedia('(prefers-color-scheme: dark)');
        const onChange = () => {
            if (document.documentElement.dataset.themeMode === 'system') applyTheme('system');
        };
        if (mq.addEventListener) mq.addEventListener('change', onChange);
        else if (mq.addListener) mq.addListener(onChange);
    }

    /* ---------- language ---------- */

    function detectLang() {
        const saved = store.get('pmt-lang');
        if (LANGS.indexOf(saved) !== -1) return saved;
        const wanted = navigator.languages || [navigator.language || 'en'];
        for (const tag of wanted) {
            const code = String(tag).toLowerCase().slice(0, 2);
            if (LANGS.indexOf(code) !== -1) return code;
        }
        return 'en';
    }

    function applyLang(next) {
        lang = next;
        document.documentElement.lang = next;

        document.querySelectorAll('[data-i18n]').forEach((el) => {
            const key = el.dataset.i18n;
            if (UI[key]) el.textContent = tr(UI[key]);
        });
        document.querySelectorAll('[data-i18n-title]').forEach((el) => {
            const key = el.dataset.i18nTitle;
            if (UI[key]) el.title = tr(UI[key]);
        });
        document.querySelectorAll('#lang-seg button').forEach((b) => {
            b.setAttribute('aria-pressed', String(b.dataset.lang === next));
        });

        renderCards();
        renderNews();
    }

    function initLang() {
        document.querySelectorAll('#lang-seg button').forEach((btn) => {
            btn.addEventListener('click', () => {
                store.set('pmt-lang', btn.dataset.lang);
                applyLang(btn.dataset.lang);
            });
        });
        applyLang(detectLang());
    }

    /* ---------- fake terminal ---------- */

    /* KDE Breeze frame: title on the left, chevron buttons on the right. */
    function termFrame(host, body, cls) {
        return [
            '<div class="term' + (cls ? ' ' + cls : '') + '">',
            '  <div class="term-bar">',
            '    <span class="term-name">' + esc(host) + ': ~</span>',
            '    <span class="term-btns" aria-hidden="true">',
            '      <span class="term-btn min">' + icon('chevron-down') + '</span>',
            '      <span class="term-btn max">' + icon('chevron-up') + '</span>',
            '      <span class="term-btn close">' + icon('x') + '</span>',
            '    </span>',
            '  </div>',
            '  <div class="term-body">' + body + '</div>',
            '</div>',
        ].join('\n');
    }

    /* The screen a script draws: logo, subtitle, optional box, menu, prompt.
       withPanel is false for the hero, which stays compact. */
    function termScreen(t, withPanel) {
        const red = t.theme === 'red' ? ' red' : '';
        const logo = BANNERS[t.banner] || [];
        const width = Math.max(...logo.map((l) => l.length), t.subtitle.length + 20);
        const out = [];

        out.push('<span class="t-logo' + red + '">' + esc(logo.join('\n')) + '</span>');
        out.push('');
        out.push('  <span class="t-sub' + red + '">' + esc(t.subtitle) + '</span> <span class="t-by">· by ' + esc(SITE.author) + '</span>');
        out.push('<span class="t-rule' + red + '">' + '─'.repeat(width) + '</span>');

        if (withPanel && t.panel) {
            out.push('');
            out.push('<span class="t-box' + red + '">┌</span> <span class="t-box' + red + '">' + esc(t.panel.title) + '</span>');
            t.panel.lines.forEach((line) => {
                out.push('<span class="t-box' + red + '">│</span> ' + esc(line));
            });
            out.push('<span class="t-box' + red + '">└</span>');
        }

        out.push('');
        t.menu.forEach((item, i) => {
            out.push(' <span class="t-num' + red + '">' + (i + 1) + ')</span> ' + esc(item));
        });
        out.push('');
        out.push('<span class="t-q">?</span> ' + esc(t.prompt) + ' <span class="t-cursor"></span>');

        return '<pre>' + out.join('\n') + '</pre>';
    }

    /* Hero: the first script of data.js, shown from the pasted line onwards. */
    function renderHero() {
        const script = SCRIPTS[0];
        const slot = document.getElementById('hero-demo');
        if (!script || !slot) return;

        const t = script.terminal;
        const typed = [
            '<pre class="t-run"><span class="t-user">' + esc(t.host) + ':~#</span> ',
            '<span class="c-cmd">bash</span> &lt;(<span class="c-cmd">curl</span> -fsSL ',
            '<span class="c-url">' + esc(RAW_BASE + script.file) + '</span>)</pre>',
        ].join('');

        slot.innerHTML = termFrame(t.host, typed + termScreen(t, false), 'term-hero');
    }

    /* ---------- cards ---------- */

    function card(script) {
        const cmd = 'bash <(curl -fsSL ' + RAW_BASE + script.file + ')';
        const points = tr(script.points)
            .map((p) => '<li>' + icon('circle-check') + '<span>' + esc(p) + '</span></li>')
            .join('');
        const note = script.note
            ? '<p class="card-note">' + icon('info') + '<span>' + esc(tr(script.note)) + '</span></p>'
            : '';

        return [
            '<article class="card" id="' + esc(script.id) + '">',
            '  <div class="card-grid">',
            '    <div class="card-info">',
            '      <div class="card-top">',
            '        <h3 class="card-title">' + icon(script.icon || 'code') + '<span>' + esc(tr(script.name)) + '</span></h3>',
            '        <span class="badge">' + esc(tr(script.compat)) + '</span>',
            '      </div>',
            '      <p class="card-tagline">' + esc(tr(script.tagline)) + '</p>',
            '      <span class="runs-on">' + icon(TARGET_ICON[script.target] || 'server') + '<b>' + esc(tr(UI.cardRunOn)) + '</b> ' + esc(tr(script.runsOn)) + '</span>',
            '      <ul class="points">' + points + '</ul>',
            note,
            '      <div class="run">',
            '        <span class="run-label">' + esc(tr(UI.cardCopyLabel)) + '</span>',
            '        <div class="run-box">',
            '          <div class="run-cmd"><code><span class="c-cmd">bash</span> &lt;(<span class="c-cmd">curl</span> -fsSL <span class="c-url">' + esc(RAW_BASE + script.file) + '</span>)</code></div>',
            '          <button class="copy" type="button" data-cmd="' + esc(cmd) + '" title="' + esc(tr(UI.cardCopy)) + '" aria-label="' + esc(tr(UI.cardCopy)) + '">',
            '            ' + icon('copy', 'ico-copy') + icon('check', 'ico-done'),
            '          </button>',
            '        </div>',
            '      </div>',
            '      <div class="card-links">',
            '        <a href="' + BLOB_BASE + encodeURIComponent(script.file) + '" rel="noopener">' + icon('external') + esc(tr(UI.cardSource)) + '</a>',
            '      </div>',
            '    </div>',
            '    <div class="term-side">',
            termFrame(script.terminal.host, termScreen(script.terminal, true)),
            '    </div>',
            '  </div>',
            '</article>',
        ].join('\n');
    }

    function renderCards() {
        document.getElementById('cards').innerHTML = SCRIPTS.map(card).join('\n');
        wireCopyButtons();
    }

    /* Each card is one link: clicking anywhere on it scrolls to the script. */
    function renderNews() {
        document.getElementById('news-list').innerHTML = SCRIPTS
            .filter((s) => s.updated)
            .map((s) => [
                '<a class="news-card" href="#' + esc(s.id) + '">',
                '  <div class="news-top">',
                '    <span class="news-icon">' + icon(s.icon || 'code') + '</span>',
                '    <span class="news-name">' + esc(tr(s.name)) + '</span>',
                '  </div>',
                '  <p class="news-body">' + esc(tr(s.updated)) + '</p>',
                '  <div class="news-foot">',
                '    <span class="news-badge">' + icon('bolt') + esc(tr(UI.newsBadge)) + '</span>',
                '    <span class="news-go" aria-hidden="true">' + icon('arrow-right') + '</span>',
                '  </div>',
                '</a>',
            ].join('\n'))
            .join('\n');
    }

    /* ---------- copy ---------- */

    let toastTimer;
    function toast(message) {
        const el = document.getElementById('toast');
        el.textContent = message;
        el.classList.add('show');
        clearTimeout(toastTimer);
        toastTimer = setTimeout(() => el.classList.remove('show'), 2200);
    }

    async function copy(text) {
        try {
            await navigator.clipboard.writeText(text);
            return true;
        } catch (err) {
            // the clipboard API needs a secure context, fall back to a textarea
            const ta = document.createElement('textarea');
            ta.value = text;
            ta.setAttribute('readonly', '');
            ta.style.position = 'fixed';
            ta.style.opacity = '0';
            document.body.appendChild(ta);
            ta.select();
            let ok = false;
            try { ok = document.execCommand('copy'); } catch (e) { ok = false; }
            document.body.removeChild(ta);
            return ok;
        }
    }

    function wireCopyButtons() {
        document.querySelectorAll('.copy').forEach((btn) => {
            btn.addEventListener('click', async () => {
                const ok = await copy(btn.dataset.cmd);
                if (!ok) { toast(tr(UI.copyFail)); return; }
                btn.classList.add('done');
                toast(tr(UI.copyOk));
                setTimeout(() => btn.classList.remove('done'), 1800);
            });
        });
    }

    /* ---------- build ---------- */

    function build() {
        document.getElementById('fact-count').textContent = SCRIPTS.length;
        renderHero();

        [['nav-repo', REPO_URL],
         ['hero-repo', REPO_URL + '/tree/' + SITE.branch + '/' + SITE.scriptsDir],
         ['foot-repo', REPO_URL],
         ['foot-issues', REPO_URL + '/issues'],
         ['hero-author', AUTHOR_URL],
         ['foot-author', AUTHOR_URL]].forEach(([id, href]) => {
            const el = document.getElementById(id);
            if (el) el.href = href;
        });

        initTheme();
        initLang();
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', build);
    } else {
        build();
    }
})();
