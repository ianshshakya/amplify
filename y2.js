// y2.js — Automates y2mate button click
// Run: node y2.js <YouTube URL>

const { chromium } = require('playwright');

const youtubeUrl = process.argv[2];
if (!youtubeUrl) { console.error('Usage: node y2.js <YouTube URL>'); process.exit(1); }
const videoId = youtubeUrl.match(/(?:v=|youtu\.be\/)([a-zA-Z0-9_-]{11})/)?.[1];
if (!videoId) { console.error('❌ Could not extract Video ID'); process.exit(1); }

const fullUrl = `https://www.youtube.com/watch?v=${videoId}`;
console.log(`\n🎵 Video ID : ${videoId}\n`);

(async () => {
  const browser = await chromium.launch({ headless: false }); // SET TRUE OR FALSE HERE
  const context = await browser.newContext({
    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  });
  const page = await context.newPage();

  let downloadEvent = null;

  // Intercept any new popups or navigation to .mp3 files
  context.on('page', async (newPage) => {
    // Sometimes Y2mate opens a popup ad. Close it automatically.
    const url = newPage.url();
    if (!url.includes('y2mate') && !url.includes('youtube')) {
       await newPage.close();
    }
  });

  // Watch for Playwright's built-in download event
  page.on('download', download => {
    downloadEvent = download;
  });

  console.log('🌐 Loading y2mate...');
  await page.goto('https://v31.www-y2mate.com/convert/', { waitUntil: 'networkidle' });

  // Type URL and submit
  console.log('⌨️  Typing URL...');
  const inputSel = 'input[type="text"]';
  await page.waitForSelector(inputSel, { timeout: 15000 });
  await page.fill(inputSel, fullUrl);
  await page.keyboard.press('Enter');

  // Wait for the iframe results to load
  console.log('⏳ Waiting for results to load...');
  await page.waitForTimeout(5000);
  
  // The results are in an iframe, we need to click the button inside the iframe
  const frames = page.frames();
  const y2metaFrame = frames.find(f => f.url().includes('y2meta-uk.com/wwwindex.php'));

  if (!y2metaFrame) {
    console.log('❌ Could not find the results iframe.');
    await browser.close();
    return;
  }

  console.log('🖱️  Clicking the MP3 download button...');
  // Find the MP3 download button (data-format="mp3")
  const btnSel = 'button[data-format="mp3"]';
  try {
    await y2metaFrame.waitForSelector(btnSel, { timeout: 10000 });
    // Click the first MP3 button (usually highest quality)
    await y2metaFrame.click(btnSel);
    console.log('✅ Clicked! Generating file on their servers...');
  } catch (e) {
    console.log('❌ MP3 button not found.');
    await browser.close();
    return;
  }

  // Now we wait for the final download button to become clickable
  for (let i = 0; i < 30; i++) {
    await page.waitForTimeout(1000);
    const downloadLinkNode = await y2metaFrame.$('a.btn-download-link');
    if (downloadLinkNode) {
      const href = await downloadLinkNode.getAttribute('href');
      if (href && href !== 'javascript:void(0)' && href !== 'javascript:void(0);' && href !== 'JavaScript:void(0)') {
        console.log('📥 Final download button is ready! Clicking it...');
        
        // Wait for the download event to trigger
        const [download] = await Promise.all([
          page.waitForEvent('download', { timeout: 60000 }).catch(() => null),
          downloadLinkNode.click()
        ]);
        
        if (download) {
           downloadEvent = download;
        }
        break;
      }
    }
  }

  if (downloadEvent) {
    const fileName = await downloadEvent.suggestedFilename();
    console.log(`\n🎉 DOWNLOADING: ${fileName}`);
    await downloadEvent.saveAs(fileName);
    console.log(`✅ Saved successfully to: ${process.cwd()}\\${fileName}\n`);
  } else {
    console.log('\n❌ Download did not trigger. Anti-bot may have blocked it.');
  }

  // Prevent background tasks from crashing node when context closes
  context.removeAllListeners();
})();
