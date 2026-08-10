// yt-direct.js
// Run: node yt-direct.js <YouTube URL>
// Extracts the direct download link instantly without any 3rd party APIs!

const ytdl = require('@distube/ytdl-core');

const youtubeUrl = process.argv[2];

if (!youtubeUrl) {
  console.error('Usage: node yt-direct.js <YouTube URL>');
  process.exit(1);
}

console.log(`\n🎵 Fetching direct link for: ${youtubeUrl}...\n`);

(async () => {
  try {
    const info = await ytdl.getInfo(youtubeUrl);
    
    console.log(`Title: ${info.videoDetails.title}`);
    console.log(`Channel: ${info.videoDetails.ownerChannelName}\n`);

    // Get all audio-only formats, sort by highest quality
    const audioFormats = ytdl.filterFormats(info.formats, 'audioonly');
    audioFormats.sort((a, b) => b.audioBitrate - a.audioBitrate);

    if (audioFormats.length === 0) {
      console.log('❌ No audio formats found.');
      return;
    }

    const bestAudio = audioFormats[0];

    console.log('✅ DIRECT AUDIO DOWNLOAD LINK (Highest Quality):');
    console.log(`   Bitrate: ${bestAudio.audioBitrate}kbps`);
    console.log(`   Format:  ${bestAudio.container}\n`);
    console.log(bestAudio.url);
    console.log('\n(You can download this URL using any standard tool or fetch())');

  } catch (error) {
    console.error('❌ Error getting info:', error.message);
  }
})();
