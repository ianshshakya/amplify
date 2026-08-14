const puppeteer = require('puppeteer-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');

puppeteer.use(StealthPlugin());

const url = process.argv[2];
if (!url) {
  console.error('Please provide a YouTube URL as an argument.');
  process.exit(1);
}

(async () => {
  const browser = await puppeteer.launch({
    headless: 'new', // Uses the new headless mode which is harder for Cloudflare to detect
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  
  try {
    await page.goto('https://superceramika.pl', { waitUntil: 'networkidle2' });
    
    // Wait for the input box
    await page.waitForSelector('input[type="url"], input[type="text"]', { timeout: 15000 });
    
    // Type the URL
    await page.type('input[type="url"], input[type="text"]', url);
    
    // Press Enter to submit
    await page.keyboard.press('Enter');
    
    // Wait for the result section to appear. We wait for an 'a' tag whose href is clearly external or a download endpoint.
    await page.waitForSelector('a', { timeout: 45000 }).catch(() => {});
    
    // Polling until a valid external download link appears (up to 45 seconds)
    let downloadLink = null;
    for (let i = 0; i < 45; i++) {
      const links = await page.$$eval('a', as => as.map(a => ({ text: a.innerText, href: a.href, download: a.hasAttribute('download') })));
      
      downloadLink = links.find(l => {
        // Ignore links pointing back to the page itself
        if (l.href.includes('youtube-downloader')) return false;
        
        // Match actual download endpoints or files
        return l.href.includes('api') || 
               l.href.includes('.mp3') || 
               l.href.includes('.mp4') || 
               l.download ||
               l.text.toLowerCase().includes('download mp');
      });
      
      if (downloadLink) break;
      await new Promise(resolve => setTimeout(resolve, 1000)); // wait 1 second and check again
    }
    
    if (downloadLink) {
      // ONLY output the final URL for backend parsing
      console.log(downloadLink.href);
    } else {
      console.error('ERROR: Could not find the download link. Cloudflare blocked the request or the video is unavailable.');
      process.exit(1);
    }
    
  } catch (err) {
    console.error(`ERROR: ${err.message}`);
    process.exit(1);
  } finally {
    await browser.close();
  }
})();
