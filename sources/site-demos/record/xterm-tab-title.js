const { Recorder, sleep } = require('../lib.js');
const consoles = [
  '/?console=lxc&xtermjs=1&vmid=200&vmname=pihole&node=pve01&cmd=',
  '/?console=lxc&xtermjs=1&vmid=203&vmname=wireguard&node=pve01&cmd=',
  '/?console=lxc&xtermjs=1&vmid=201&vmname=jellyfin&node=pve03&cmd=',
];
(async () => {
  const r = await Recorder.start('xterm-tab-title', { variant: 'stock-sub', theme: 'crisp' });
  await r.open('/#v1:0:=lxc%2F200:4:5', 3000);
  for (const url of consoles) await r.open(url, 1500);
  await sleep(3000);
  await r.badge('Proxmox VE');
  await r.page.evaluate(() => window.__demo.hideCursor());
  await r.shot(1000);
  // which tab is which console?
  for (const i of [1, 2, 3]) {
    const t = await r.tab(i);
    await r.click(t.x, t.y, { after: 700 });
  }
  await r.film(500);

  await r.reloadAll({ variant: 'tabtitle', theme: 'crisp' }, 4000);
  await r.badge('+ pve-xterm-tab-title.sh', true);
  await r.shot(1200, 6);
  for (const i of [1, 2, 3]) {
    const t = await r.tab(i);
    await r.click(t.x, t.y, { after: 800 });
  }
  await r.film(1200);
  await r.finish();
})();
