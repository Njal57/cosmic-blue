// Render an SVG to a transparent 5120x2880 PNG with Playwright's Chromium.
// Usage: node render.js [IN.svg OUT.png] (default: foreground.svg foreground.png)
const { chromium } = require('playwright');
const fs = require('fs');
const [input = 'foreground.svg', output = 'foreground.png'] = process.argv.slice(2);
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 2560, height: 1440 }, deviceScaleFactor: 2 });
  const svg = fs.readFileSync(input, 'utf8');
  await page.setContent('<html><body style="margin:0;overflow:hidden;background:transparent">' + svg + '</body></html>');
  await page.evaluate(() => { document.querySelector('svg').style.cssText = 'width:100vw;height:100vh;display:block'; });
  await page.waitForTimeout(1500);
  await page.screenshot({ path: output, omitBackground: true });
  await browser.close();
})();
