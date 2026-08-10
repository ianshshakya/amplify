// get-yt.js
// A standalone script that downloads the yt-dlp binary (if missing) and fetches the direct MP3 link
// Run: node get-yt.js <YouTube URL>

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const youtubeUrl = process.argv[2];

if (!youtubeUrl) {
  console.error('Usage: node get-yt.js <YouTube URL>');
  process.exit(1);
}

const exePath = path.join(__dirname, 'yt-dlp.exe');

async function downloadYtDlp() {
  console.log('⏳ First time setup: Downloading latest yt-dlp.exe (approx 14MB)...');
  const res = await fetch('https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe');
  if (!res.ok) throw new Error(`Failed to download: ${res.statusText}`);
  
  const buffer = await res.arrayBuffer();
  fs.writeFileSync(exePath, Buffer.from(buffer));
  console.log('✅ Download complete!\n');
}

async function run() {
  if (!fs.existsSync(exePath)) {
    await downloadYtDlp();
  }

  console.log(`🎵 Fetching direct audio link for: ${youtubeUrl}...`);
  console.log('⏳ Please wait a few seconds...\n');

  try {
    // Get direct audio URL
    const command = `"${exePath}" -g -f "bestaudio" "${youtubeUrl}"`;
    const output = execSync(command, { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'] });
    
    const directLink = output.trim();
    
    if (directLink) {
      console.log('✅ DIRECT AUDIO DOWNLOAD LINK:\n');
      console.log(directLink);
      console.log('\n(This link comes straight from YouTube servers, no bot protections)');
    } else {
      console.log('❌ No link returned.');
    }
  } catch (error) {
    console.error('❌ Failed to get link. Error:');
    if (error.stderr) console.error(error.stderr);
    else console.error(error.message);
  }
}

run();
