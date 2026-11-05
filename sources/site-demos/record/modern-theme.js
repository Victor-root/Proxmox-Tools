const { Recorder } = require('../lib.js');
(async () => {
  const r = await Recorder.start('modern-theme', { variant: 'stock', theme: 'crisp' });
  await r.open('/#v1:0:=node%2Fpve01:4:5');
  await r.foldLogs();
  await r.badge('Proxmox VE');
  await r.page.evaluate(() => window.__demo.hideCursor());
  await r.shot(1800);

  await r.reload({ variant: 'theme', theme: 'modern-orange-dark' });
  await r.badge('+ pve-modern-theme.sh', true);
  await r.foldLogs();
  await r.shot(900, 6);
  let p = await r.treeRow('101 (truenas)');
  await r.move(p.x, p.y, 900);
  await r.film(400);
  p = await r.treeRow('200 (pihole)');
  await r.move(p.x, p.y, 500);
  await r.click(p.x, p.y, { after: 1200 });
  await r.move(760, 560, 700);
  await r.film(500);

  for (const theme of ['modern-blue-light', 'modern-violet-dark', 'modern-green-light', 'modern-pink-dark']) {
    await r.reload({ variant: 'theme', theme });
    await r.foldLogs();
    await r.page.evaluate(([a, b]) => window.__demo.cursor(a, b), [r.pos.x, r.pos.y]);
    await r.shot(1500, 6);
  }
  await r.finish();
})();
