/* Builds the whole page from data.js. Nothing here needs to change when a
 * script is added: edit data.js only. */

(function () {
    'use strict';

    const REPO_URL = 'https://github.com/' + SITE.repo;
    const RAW_BASE = 'https://raw.githubusercontent.com/' + SITE.repo + '/' + SITE.branch + '/' + SITE.scriptsDir + '/';
    const BLOB_BASE = REPO_URL + '/blob/' + SITE.branch + '/' + SITE.scriptsDir + '/';

    const esc = (s) => String(s).replace(/[&<>"']/g, (c) => (
        { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
    ));

    const runCommand = (file) => 'bash <(curl -fsSL ' + RAW_BASE + file + ')';

    /* ---------- fake terminal ---------- */

    function terminal(script) {
        const t = script.terminal;
        const red = t.theme === 'red' ? ' red' : '';
        const logo = BANNERS[t.banner] || [];
        const width = Math.max(
            ...logo.map((l) => l.length),
            t.subtitle.length + 20
        );
        const rule = '─'.repeat(width);
        const out = [];

        out.push('<span class="t-logo' + red + '">' + esc(logo.join('\n')) + '</span>');
        out.push('');
        out.push('  <span class="t-sub' + red + '">' + esc(t.subtitle) + '</span> <span class="t-by">· by Victor-root</span>');
        out.push('<span class="t-rule' + red + '">' + rule + '</span>');

        if (t.panel) {
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

    /* ---------- cards ---------- */

    function card(script) {
        const cmd = runCommand(script.file);
        const points = script.points.map((p) => '<li>' + esc(p) + '</li>').join('');
        const note = script.note
            ? '<p class="card-note">' + esc(script.note) + '</p>'
            : '';

        return [
            '<article class="card" id="' + esc(script.id) + '">',
            '  <div class="card-grid">',
            '    <div class="card-info">',
            '      <div class="card-top">',
            '        <h3 class="card-title">' + esc(script.name) + '</h3>',
            '        <span class="badge">' + esc(script.compat) + '</span>',
            '      </div>',
            '      <p class="card-tagline">' + esc(script.tagline) + '</p>',
            '      <span class="runs-on"><b>Run it on</b> ' + esc(script.runsOn) + '</span>',
            '      <ul class="points">' + points + '</ul>',
            note,
            '      <div class="run">',
            '        <span class="run-label">Copy this line into your shell</span>',
            '        <div class="run-box">',
            '          <div class="run-cmd"><code><span class="c-cmd">bash</span> &lt;(<span class="c-cmd">curl</span> -fsSL <span class="c-url">' + esc(RAW_BASE + script.file) + '</span>)</code></div>',
            '          <button class="copy" type="button" data-cmd="' + esc(cmd) + '" aria-label="Copy the command for ' + esc(script.name) + '">Copy</button>',
            '        </div>',
            '      </div>',
            '      <div class="card-links">',
            '        <a href="' + BLOB_BASE + encodeURIComponent(script.file) + '" rel="noopener">Read the source on GitHub</a>',
            '        <a href="' + REPO_URL + '/commits/' + SITE.branch + '/' + SITE.scriptsDir + '/' + encodeURIComponent(script.file) + '" rel="noopener">History</a>',
            '      </div>',
            '    </div>',
            '    <div class="term-side">',
            '      <div class="term">',
            '        <div class="term-bar">',
            '          <span class="term-dot r"></span><span class="term-dot y"></span><span class="term-dot g"></span>',
            '          <span class="term-name">root@' + (script.terminal.banner === 'wireguard' ? 'lxc-wireguard' : 'pve01') + ': ~</span>',
            '        </div>',
            '        <div class="term-body">' + terminal(script) + '</div>',
            '      </div>',
            '    </div>',
            '  </div>',
            '</article>',
        ].join('\n');
    }

    /* ---------- copy button ---------- */

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
            // clipboard API needs https, fall back to a hidden textarea
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
                if (!ok) {
                    toast('Copy failed, select the line by hand');
                    return;
                }
                const label = btn.textContent;
                btn.textContent = 'Copied';
                btn.classList.add('done');
                toast('Command copied, paste it as root');
                setTimeout(() => {
                    btn.textContent = label;
                    btn.classList.remove('done');
                }, 1800);
            });
        });
    }

    /* ---------- build ---------- */

    function build() {
        document.getElementById('cards').innerHTML = SCRIPTS.map(card).join('\n');

        document.getElementById('news-list').innerHTML = SCRIPTS
            .filter((s) => s.updated)
            .map((s) => (
                '<li><a href="#' + esc(s.id) + '">' + esc(s.name) + '</a><p>' + esc(s.updated) + '</p></li>'
            ))
            .join('\n');

        document.getElementById('fact-count').textContent = SCRIPTS.length;

        [['nav-repo', REPO_URL], ['hero-repo', REPO_URL + '/tree/' + SITE.branch + '/' + SITE.scriptsDir],
         ['foot-repo', REPO_URL], ['foot-issues', REPO_URL + '/issues']]
            .forEach(([id, href]) => {
                const el = document.getElementById(id);
                if (el) el.href = href;
            });

        wireCopyButtons();
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', build);
    } else {
        build();
    }
})();
