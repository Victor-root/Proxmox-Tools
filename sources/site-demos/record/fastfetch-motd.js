const { Recorder } = require('../lib.js');
(async () => {
  const r = await Recorder.start('fastfetch-motd', { variant: 'fastfetch', theme: 'crisp' });
  // the font size of My Settings, as large as the summary still fits the width
  await r.page.evaluate(() => localStorage.setItem('pve-xterm-fontSize', '18'));
  // the shell of the node, as opened from the web interface
  await r.open('/?console=shell&xtermjs=1&vmid=0&vmname=&node=pve01&cmd=', 3500);
  await r.badge('+ pve-fastfetch-motd.sh', true);
  await r.page.evaluate(() => window.__demo.hideCursor());
  await r.shot(3000);
  await r.finish();
})();
