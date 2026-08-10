// search-yt.js
// Searches YouTube and returns the link for the top result
// Run: node search-yt.js "Song Name"

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const query = process.argv.slice(2).join(' ');

if (!query) {
  console.error('Usage: node search-yt.js "Song Name"');
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

  console.log(`🔍 Searching YouTube for: "${query}"...`);

  try {
    // "ytsearch1:" tells yt-dlp to search youtube and return the 1st result
    // --print webpage_url tells it to ONLY print the video URL
    const command = `"${exePath}" "ytsearch1:${query}" --print webpage_url`;
    
    // stdio: 'pipe' to capture stdout, 'ignore' stderr to hide warnings about missing node/ffmpeg
    const output = execSync(command, { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'ignore'] });
    
    const youtubeUrl = output.trim();
    
    if (youtubeUrl) {
      console.log('✅ TOP RESULT YOUTUBE LINK:\n');
      console.log(youtubeUrl);
    } else {
      console.log('❌ No results found.');
    }
  } catch (error) {
    console.error('❌ Search failed. Error:');
    if (error.stderr) console.error(error.stderr);
    else console.error(error.message);
  }
}

run();
