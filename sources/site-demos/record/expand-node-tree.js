const { Recorder } = require('../lib.js');
(async () => {
  const r = await Recorder.start('expand-node-tree', { variant: 'stock', theme: 'crisp' });
  await r.open('/#v1:0:18:4:::::::');
  await r.badge('Proxmox VE');
  await r.page.evaluate(() => window.__demo.hideCursor());
  await r.shot(1600);

  // what has to be done by hand after every login
  const f = await r.frame();
  for (const node of ['pve01', 'pve02']) {
    const exp = f.locator('.x-grid-item', { has: f.locator('.x-tree-node-text', { hasText: new RegExp('^' + node + '$') }) }).locator('.x-tree-expander').first();
    const b = await exp.boundingBox();
    await r.click(b.x + b.width / 2, b.y + b.height / 2, { after: 500 });
  }
  const arrow = f.locator('.x-splitter .x-collapse-el').filter({ visible: true }).last();
  const a = await arrow.boundingBox();
  await r.click(a.x + a.width / 2, a.y + a.height / 2, { after: 1200 });

  // the next login, with the script
  await r.page.evaluate(() => window.__demo.frame().contentWindow.localStorage.clear());
  await r.reload({ variant: 'tree', theme: 'crisp' });
  await r.badge('+ pve-expand-node-tree.sh', true);
  await r.page.evaluate(() => window.__demo.hideCursor());
  await r.shot(3200, 6);
  await r.finish();
})();
