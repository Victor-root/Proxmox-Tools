const { Recorder } = require('../lib.js');
const url = '/?console=lxc&xtermjs=1&vmid=200&vmname=pihole&node=pve01&cmd=';

async function run(r) {
  await r.move(640, 460, 600);
  await r.page.mouse.click(640, 460);
  await r.type('seq -f "Test line %g" 1 5000', 45);
  await r.page.keyboard.press('Enter');
  await r.film(900, 150);
  // scroll back, at the same speed in both, to the oldest line the console kept
  const f = await r.frame();
  while (await f.evaluate(() => term.buffer.active.viewportY > 0)) {
    await f.evaluate(() => term.scrollLines(-260));
    await r.shot(80);
  }
  await r.film(2400, 600);
}

(async () => {
  const r = await Recorder.start('xterm-scrollback', { variant: 'stock-sub' });
  await r.open(url, 3000);
  await r.badge('Proxmox VE');
  await r.page.evaluate(() => window.__demo.hideCursor());
  await r.shot(800);
  await run(r);

  await r.reloadAll({ variant: 'scrollback' }, 3000);
  await r.badge('+ pve-xtermjs-scrollback.sh', true);
  await r.shot(900, 6);
  await run(r);
  await r.finish();
})();
