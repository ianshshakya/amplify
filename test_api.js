const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  
  page.on('request', request => {
    if (request.url().includes('api') || request.url().includes('download') || request.url().includes('fetch')) {
      console.log('API Request:', request.method(), request.url(), request.postData());
    }
  });
  
  page.on('response', async response => {
    if (response.url().includes('api') || response.url().includes('download') || response.url().includes('fetch')) {
      try {
        const text = await response.text();
        console.log('API Response:', text.substring(0, 500));
      } catch (e) {}
    }
  });

  await page.goto('https://iamtypist.dev/tools/youtube-downloader');
  
  // Fill the input and submit
  await page.fill('input[type="text"], input[type="url"]', 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
  await page.keyboard.press('Enter');
  
  await page.waitForTimeout(5000);
  await browser.close();
})();
