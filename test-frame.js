const { chromium } = require('playwright');
const fs = require('fs');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  
  page.on('response', async (response) => {
    const url = response.url();
    if (url.includes('frame.y2meta-uk.com/wwwindex.php')) {
      try {
        const text = await response.text();
        fs.writeFileSync('frame-real.html', text);
        console.log('Saved frame HTML to frame-real.html');
      } catch (e) {}
    }
  });

  console.log('Loading y2mate...');
  await page.goto('https://v31.www-y2mate.com/convert/', { waitUntil: 'networkidle' });
  
  const inputSel = 'input[type="text"]';
  await page.fill(inputSel, 'https://www.youtube.com/watch?v=LUgpPmj6nR8');
  await page.keyboard.press('Enter');
  
  await page.waitForTimeout(5000);
  await browser.close();
})();
