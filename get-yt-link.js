// get-yt-link.js
// Description: Gets the direct audio/video download URL using yt-dlp
// Run: node get-yt-link.js <YouTube URL>

const { execSync } = require('child_process');

const youtubeUrl = process.argv[2];

if (!youtubeUrl) {
  console.error('Usage: node get-yt-link.js <YouTube URL>');
  process.exit(1);
}

console.log(`\n🎵 Fetching direct download link for: ${youtubeUrl} ...`);
console.log('⏳ This might take a few seconds...\n');

try {
  // -g : get direct URL
  // -f : format (best audio)
  const command = `yt-dlp -g -f "bestaudio" "${youtubeUrl}"`;
  
  // Execute yt-dlp synchronously
  const output = execSync(command, { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'] });
  
  const directLink = output.trim();
  
  if (directLink) {
    console.log('✅ DIRECT AUDIO DOWNLOAD LINK:\n');
    console.log(directLink);
    console.log('\n(You can pass this link directly to fetch() or a downloader)');
  } else {
    console.log('❌ No link returned.');
  }

} catch (error) {
  console.error('❌ Failed to get link. Make sure yt-dlp is installed.');
  console.error('\nTo install yt-dlp on Windows, run:');
  console.error('winget install yt-dlp');
  
  if (error.stderr) {
    console.error('\nError details:\n', error.stderr);
  }
}
