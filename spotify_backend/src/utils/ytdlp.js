const fs = require('fs');
const path = require('path');
const { execSync, exec } = require('child_process');

const isWin = process.platform === 'win32';
const isMac = process.platform === 'darwin';
const exeName = isWin ? 'yt-dlp.exe' : 'yt-dlp';
const exePath = path.join(__dirname, '..', '..', exeName);

const https = require('https');

// Global Cookies Setup
const cookiesPath = path.join(__dirname, '..', '..', 'cookies.txt');
let globalCookiesArg = '';

if (fs.existsSync(cookiesPath)) {
  try {
    let cookieContent = fs.readFileSync(cookiesPath, 'utf-8');
    if (cookieContent.includes('\r\n') && !isWin) {
      cookieContent = cookieContent.replace(/\r\n/g, '\n');
      fs.writeFileSync(cookiesPath, cookieContent);
      console.log('[yt-dlp] Converted cookies.txt to Unix LF newlines for Render.');
    }
  } catch (err) {
    console.error('[yt-dlp] Failed to parse cookies.txt:', err);
  }
  globalCookiesArg = `--cookies "${cookiesPath}"`;
}

async function downloadYtDlp() {
  if (fs.existsSync(exePath)) return;
  console.log(`⏳ Downloading latest yt-dlp for ${process.platform}...`);
  
  let downloadName = 'yt-dlp_linux';
  if (isWin) downloadName = 'yt-dlp.exe';
  if (isMac) downloadName = 'yt-dlp_macos';

  const url = `https://github.com/yt-dlp/yt-dlp/releases/latest/download/${downloadName}`;

  return new Promise((resolve, reject) => {
    // Github releases redirect to objects.githubusercontent.com, so we need to follow redirects
    const downloadFile = (downloadUrl) => {
      https.get(downloadUrl, (response) => {
        if (response.statusCode >= 300 && response.statusCode < 400 && response.headers.location) {
          return downloadFile(response.headers.location);
        }
        if (response.statusCode !== 200) {
          return reject(new Error(`Failed to download yt-dlp: HTTP ${response.statusCode}`));
        }

        const fileStream = fs.createWriteStream(exePath);
        response.pipe(fileStream);

        fileStream.on('finish', () => {
          fileStream.close();
          if (!isWin) {
            fs.chmodSync(exePath, 0o755); // Make it executable on Linux/Mac
          }
          console.log('✅ yt-dlp downloaded and ready!');
          resolve();
        });

        fileStream.on('error', (err) => {
          fs.unlink(exePath, () => {});
          reject(err);
        });
      }).on('error', reject);
    };

    downloadFile(url);
  });
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
    const command = `"${exePath}" ${globalCookiesArg} "ytsearch${limit}:${query.replace(/"/g, '')}" -j --flat-playlist`;
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

    // We use the default web client instead of android because Android client often rejects browser cookies on Datacenter IPs
    const command = `"${exePath}" ${globalCookiesArg} --no-warnings --no-check-certificates -g -f "bestaudio" "https://www.youtube.com/watch?v=${videoId}"`;
    exec(command, { encoding: 'utf-8', timeout: 30000 }, (error, stdout, stderr) => {
      if (error) {
        return reject(new Error(`${error.message} - Stderr: ${stderr}`));
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
    const command = `"${exePath}" ${globalCookiesArg} "${playlistUrl}" --playlist-end ${limit} -j --flat-playlist`;
    
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
