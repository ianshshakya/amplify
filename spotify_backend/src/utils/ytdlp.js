const fs = require('fs');
const path = require('path');
const { execSync, exec } = require('child_process');

const exePath = path.join(__dirname, '..', '..', 'yt-dlp.exe');

async function downloadYtDlp() {
  if (fs.existsSync(exePath)) return;
  console.log('⏳ Downloading latest yt-dlp.exe...');
  const res = await fetch('https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe');
  if (!res.ok) throw new Error(`Failed to download yt-dlp: ${res.statusText}`);
  const buffer = await res.arrayBuffer();
  fs.writeFileSync(exePath, Buffer.from(buffer));
  console.log('✅ yt-dlp downloaded!');
}

/**
 * Searches YouTube and returns a list of parsed video results.
 * @param {string} query The search string
 * @param {number} limit Number of results
 * @returns {Array} List of formatted songs
 */
async function searchYouTube(query, limit = 10) {
  return new Promise((resolve, reject) => {
    // --flat-playlist is much faster for search as it doesn't extract individual video pages
    const command = `"${exePath}" "ytsearch${limit}:${query.replace(/"/g, '')}" -j --flat-playlist`;
    console.log('[yt-dlp] Executing:', command);
    
    exec(command, { encoding: 'utf-8', maxBuffer: 1024 * 1024 * 10 }, (error, stdout, stderr) => {
      console.log('[yt-dlp] Finished. Error:', !!error);
      if (error && !stdout) {
        console.error('[yt-dlp] Error:', error.message);
        return reject(error);
      }
      
      try {
        const results = [];
        const lines = stdout.trim().split('\n');
        for (const line of lines) {
          if (!line) continue;
          const data = JSON.parse(line);
          results.push(mapYtResult(data));
        }
        console.log(`[yt-dlp] Parsed ${results.length} results.`);
        resolve(results);
      } catch (err) {
        console.error('[yt-dlp] Parse error:', err.message);
        reject(err);
      }
    });
  });
}

/**
 * Gets the direct audio stream URL for a given YouTube video ID.
 * @param {string} videoId 
 * @returns {string} The direct googlevideo.com audio stream URL
 */
async function getStreamUrl(videoId) {
  return new Promise((resolve, reject) => {
    // YouTube IDs are exactly 11 characters long
    if (!videoId || videoId.length !== 11) {
      return reject(new Error(`Invalid YouTube ID format: ${videoId}. (Probably an old JioSaavn ID)`));
    }

    // Using android player client bypasses heavy JS deciphering and is much faster
    // We use "ba/b" (best audio, fallback to best) because android client often only exposes combined mp4 format 18
    const command = `"${exePath}" --no-warnings --no-check-certificates --extractor-args "youtube:player_client=android" -g -f "ba/b" "https://www.youtube.com/watch?v=${videoId}"`;
    exec(command, { encoding: 'utf-8' }, (error, stdout, stderr) => {
      if (error) {
        return reject(error);
      }
      resolve(stdout.trim());
    });
  });
}

function mapYtResult(data) {
  // Use the highest quality thumbnail available
  let thumbnailUrl = '';
  if (data.thumbnails && data.thumbnails.length > 0) {
    thumbnailUrl = data.thumbnails[data.thumbnails.length - 1].url;
  } else {
    thumbnailUrl = `https://i.ytimg.com/vi/${data.id}/hqdefault.jpg`;
  }

  return {
    videoId: data.id,
    title: data.title,
    artist: data.uploader || data.channel || 'Unknown Artist',
    thumbnailUrl: thumbnailUrl,
    duration: typeof data.duration === 'number' ? data.duration : null,
  };
}

/**
 * Gets tracks from a specific YouTube playlist (used for albums)
 */
async function getPlaylistTracks(playlistUrl, limit = 20) {
  return new Promise((resolve, reject) => {
    const command = `"${exePath}" "${playlistUrl}" --playlist-end ${limit} -j --flat-playlist`;
    
    exec(command, { encoding: 'utf-8', maxBuffer: 1024 * 1024 * 10 }, (error, stdout, stderr) => {
      if (error && !stdout) {
        return reject(error);
      }
      try {
        const results = [];
        const lines = stdout.trim().split('\n');
        for (const line of lines) {
          if (!line) continue;
          results.push(mapYtResult(JSON.parse(line)));
        }
        resolve(results);
      } catch (err) {
        reject(err);
      }
    });
  });
}

/**
 * Gets related/watch-next tracks for a video (used for radio/autoplay)
 */
async function getRelatedTracks(videoId, limit = 20) {
  // We can just search for the video title + "mix" or just run a search for similar things
  // Or better, use youtube's auto-generated mix playlist for the video:
  // The mix playlist ID for any video is usually RD + videoId
  const mixId = `RD${videoId}`;
  return getPlaylistTracks(`https://www.youtube.com/playlist?list=${mixId}`, limit).catch(() => {
    // Fallback if mix doesn't exist
    return searchYouTube('Top hits 2024', limit);
  });
}

module.exports = {
  downloadYtDlp,
  searchYouTube,
  getStreamUrl,
  getPlaylistTracks,
  getRelatedTracks,
};
