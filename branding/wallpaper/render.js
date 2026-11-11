// Render foreground.svg to a transparent 5120x2880 PNG with Playwright's Chromium.
const { chromium } = require('playwright');
const fs = require('fs');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 2560, height: 1440 }, deviceScaleFactor: 2 });
  const svg = fs.readFileSync('foreground.svg', 'utf8');
  await page.setContent('<html><body style="margin:0;overflow:hidden;background:transparent">' + svg + '</body></html>');
  await page.evaluate(() => { document.querySelector('svg').style.cssText = 'width:100vw;height:100vh;display:block'; });
  await page.waitForTimeout(1500);
  await page.screenshot({ path: 'foreground.png', omitBackground: true });
  await browser.close();
})();
