const { Recorder } = require('../lib.js');

(async () => {
  const r = await Recorder.start('subscription-notice', { login: false, variant: 'stock', theme: 'crisp' });
  await r.open('/');
  await r.badge('Proxmox VE');
  await r.page.evaluate(() => window.__demo.hideCursor());
  await r.shot(1000);
  await r.login();
  await r.film(1200, 200);
  const f = await r.frame();
  const ok = await f.locator('.x-message-box').getByRole('button', { name: 'OK' }).boundingBox();
  await r.click(ok.x + ok.width / 2, ok.y + ok.height / 2, { after: 1000 });

  // the same login with the script
  await r.page.evaluate(() => window.__demo.frame().contentWindow.localStorage.clear());
  await r.reload({ login: false, variant: 'nosub', theme: 'crisp' });
  await r.badge('+ pve-remove-subscription-notice.sh', true);
  await r.page.evaluate(() => window.__demo.hideCursor());
  await r.shot(1000, 6);
  await r.login();
  await r.film(2400, 300);
  await r.finish();
})();
