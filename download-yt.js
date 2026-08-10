// download-yt.js
// Run: node download-yt.js <YouTube URL>

const youtubeUrl = process.argv[2];

if (!youtubeUrl) {
  console.error('Usage: node download-yt.js <YouTube URL>');
  process.exit(1);
}

const videoId = youtubeUrl.match(/(?:v=|youtu\.be\/)([a-zA-Z0-9_-]{11})/)?.[1];
if (!videoId) {
  console.error('❌ Could not extract Video ID from URL.');
  process.exit(1);
}

const fullUrl = `https://www.youtube.com/watch?v=${videoId}`;
console.log(`\n🎵 Fetching download link for: ${fullUrl} ...\n`);

async function getDownloadLink() {
  try {
    // We use the open-source Cobalt API (no ads, no captchas, pure JSON)
    const res = await fetch('https://cobalt.api.wuk.sh/api/json', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: JSON.stringify({
        url: fullUrl,
        aFormat: 'mp3',
        isAudioOnly: true,
      }),
    });

    const data = await res.json();

    if (data.url) {
      console.log('✅ DIRECT MP3 DOWNLOAD LINK:\n');
      console.log(`   ${data.url}\n`);
    } else {
      console.error('❌ API returned an error:', data.text || 'Unknown error');
      console.error('Raw response:', data);
    }
  } catch (error) {
    console.error('❌ Failed to fetch from API:', error.message);
  }
}

getDownloadLink();
