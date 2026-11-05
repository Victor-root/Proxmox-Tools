const { Recorder } = require('../lib.js');
(async () => {
  const r = await Recorder.start('console-newtab', { variant: 'stock-sub', theme: 'crisp' });
  await r.open('/#v1:0:=lxc%2F200:4:5');
  await r.foldLogs();
  await r.badge('Proxmox VE');
  await r.page.evaluate(() => window.__demo.hideCursor());
  await r.shot(1200);

  const consoleBtn = async () => { const b = await (await r.frame()).locator('.x-btn', { hasText: /^Console$/ }).first().boundingBox(); return [b.x + 30, b.y + b.height / 2]; };
  let [x, y] = await consoleBtn();
  // a middle click does nothing, a click opens a separate window
  await r.click(x, y, { button: 'middle', after: 900 });
  await r.click(x, y, { after: 2600 });
  await r.page.evaluate(() => window.__demo.closePopup());

  await r.reload({ variant: 'newtab', theme: 'crisp' });
  await r.foldLogs();
  await r.badge('+ pve-console-newtab.sh', true);
  await r.shot(1000, 6);
  [x, y] = await consoleBtn();
  await r.click(x, y, { button: 'middle', after: 2200 });

  // back to the interface, then a middle click on a guest of the tree
  let t = await r.tab(0);
  await r.click(t.x, t.y, { after: 700 });
  const p = await r.treeRow('203 (wireguard)');
  await r.click(p.x, p.y, { button: 'middle', after: 2600 });
  await r.finish();
})();
