const { Recorder } = require('../lib.js');
(async () => {
  const r = await Recorder.start('default-language', { login: false, variant: 'stock-sub', theme: 'crisp' });
  await r.open('/');
  await r.badge('Proxmox VE');
  await r.page.evaluate(() => window.__demo.hideCursor());
  await r.shot(1400);
  await r.login();
  await r.film(1800, 300);

  // the same login once the script set the default language of the server
  await r.page.evaluate(() => window.__demo.frame().contentWindow.localStorage.clear());
  await r.reload({ login: false, variant: 'lang-fr', theme: 'crisp' });
  await r.badge('+ pve-default-language-i18n', true);
  await r.page.evaluate(() => window.__demo.hideCursor());
  await r.shot(1600, 6);
  await r.login();
  await r.film(2600, 300);
  await r.finish();
})();
