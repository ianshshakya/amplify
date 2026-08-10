// vidssave-cli.js
const { chromium } = require('playwright');

const youtubeUrl = process.argv[2];
if (!youtubeUrl) {
  console.error('Usage: node vidssave-cli.js <YouTube URL>');
  process.exit(1);
}

console.log(`\n🎵 Target URL: ${youtubeUrl}\n`);

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  });
  const page = await context.newPage();

  let finalUrl = null;

  // Intercept the API response that contains the download links
  page.on('response', async (response) => {
    const url = response.url();
    if (url.includes('api/convert') || url.includes('api/analyze') || url.includes('api/json')) {
      try {
        const json = await response.json();
        // Console log any JSON response from their API to debug structure
        // console.log(JSON.stringify(json, null, 2));
      } catch (e) {}
    }
  });

  try {
    console.log('🌐 Loading vidssave.com...');
    await page.goto('https://vidssave.com/youtube-video-downloader-8hs', { waitUntil: 'networkidle', timeout: 30000 });

    const inputSel = 'input[type="text"], input[name="url"], input[placeholder*="Paste"]';
    console.log('⌨️  Pasting URL...');
    await page.waitForSelector(inputSel, { timeout: 10000 });
    await page.fill(inputSel, youtubeUrl);

    const btnSel = 'button[type="submit"], button:has-text("Download"), button:has-text("Start")';
    await page.click(btnSel);

    console.log('⏳ Waiting for processing...');

    // Wait for download links to appear on the page
    const linkSel = 'a[href*="download"], a[href*=".mp3"], a[href*=".mp4"], a.download-btn, button:has-text("Download")';
    await page.waitForSelector(linkSel, { timeout: 20000 });

    // Try to extract all download links
    const links = await page.evaluate(() => {
      const anchors = Array.from(document.querySelectorAll('a'));
      return anchors
        .filter(a => a.href && (a.href.includes('download') || a.href.includes('videoplayback') || a.textContent.toLowerCase().includes('download')))
        .map(a => ({ text: a.textContent.trim(), url: a.href }));
    });

    if (links.length > 0) {
      console.log('\n✅ Download Links Found:\n');
      links.forEach((l, i) => {
         if (l.url.startsWith('http') && !l.url.includes('vidssave.com')) {
           console.log(`  ${i+1}. [${l.text || 'Link'}]`);
           console.log(`     ${l.url}\n`);
         }
      });
    } else {
      console.log('❌ Could not extract links automatically. Saving screenshot...');
      await page.screenshot({ path: 'vidssave-error.png' });
    }

  } catch (error) {
    console.error('❌ Error:', error.message);
    await page.screenshot({ path: 'vidssave-error.png' }).catch(() => {});
  } finally {
    await browser.close();
  }
})();
