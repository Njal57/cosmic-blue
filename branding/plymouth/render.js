// Render the boot screen logo (Plymouth bgrt-fallback.png) from the logo SVG,
// with Playwright's Chromium. Usage: node render.js (from this folder)
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const SIZE = 192; // px; the mark fills the square
const svg = fs.readFileSync(path.join(__dirname, '../logo/cosmic-blue-logo.svg'), 'utf8');
const out = path.join(__dirname,
  '../../system_files/usr/share/plymouth/themes/cosmic-blue/bgrt-fallback.png');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: SIZE, height: SIZE }, deviceScaleFactor: 1 });
  await page.setContent('<html><body style="margin:0;overflow:hidden;background:transparent">' + svg + '</body></html>');
  await page.evaluate(() => { document.querySelector('svg').style.cssText = 'width:100vw;height:100vh;display:block'; });
  await page.screenshot({ path: out, omitBackground: true });
  await browser.close();
})();
