const CryptoJS = require('crypto-js');

// Helper to decode HTML entities in titles
function decodeHTMLEntities(text) {
  if (!text) return text;
  return text
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#039;/g, "'");
}

function mapSaavnResult(data) {
  let thumbnailUrl = '';
  if (data.image) {
    thumbnailUrl = data.image.replace('150x150', '500x500');
  }

  // Handle duration properly (could be string or int)
  let duration = data.duration;
  if (typeof duration === 'string') {
     duration = parseInt(duration, 10);
  }
  if (isNaN(duration)) duration = 0;

  return {
    videoId: data.id,
    title: decodeHTMLEntities(data.song || data.title || 'Unknown Title'),
    artist: decodeHTMLEntities(data.primary_artists || data.subtitle || 'Unknown Artist'),
    thumbnailUrl: thumbnailUrl,
    duration: duration,
  };
}

async function searchSaavn(query, limit = 20) {
  const url = `https://www.jiosaavn.com/api.php?__call=search.getResults&q=${encodeURIComponent(query)}&n=${limit}&p=1&_format=json&_marker=0&ctx=web6dot0`;
  const response = await fetch(url);
  if (!response.ok) throw new Error('Failed to fetch from JioSaavn search');
  const data = await response.json();
  
  if (!data.results) return [];
  
  return data.results.map(mapSaavnResult);
}

function decryptUrl(encryptedUrl) {
  try {
    const key = CryptoJS.enc.Utf8.parse('38346591');
    const decrypted = CryptoJS.DES.decrypt(
      { ciphertext: CryptoJS.enc.Base64.parse(encryptedUrl) },
      key,
      { mode: CryptoJS.mode.ECB, padding: CryptoJS.pad.Pkcs7 }
    ).toString(CryptoJS.enc.Utf8);
    
    // Convert low quality to high quality
    return decrypted.replace('_96.mp4', '_320.mp4').replace('.mp4', '.m4a');
  } catch (err) {
    console.error('Decryption error:', err);
    return null;
  }
}

async function getStreamUrl(songId) {
  const url = `https://www.jiosaavn.com/api.php?__call=song.getDetails&pids=${songId}&_format=json&_marker=0&ctx=web6dot0`;
  const response = await fetch(url);
  if (!response.ok) throw new Error('Failed to fetch song details');
  
  const data = await response.json();
  const songData = data[songId];
  if (!songData) throw new Error('Song not found');
  
  if (songData.encrypted_media_url) {
    const decryptedUrl = decryptUrl(songData.encrypted_media_url);
    if (decryptedUrl) return decryptedUrl;
  }
  
  throw new Error('Failed to decrypt or find media URL');
}

/**
 * The Hybrid Engine: Takes YouTube metadata and matches it against JioSaavn to get the stream
 */
async function getSaavnStreamByMetadata(title, artist) {
  // Clean up the query for better matching
  const cleanTitle = title.replace(/\\(Official.*?\\)|\\(Lyric.*?\\)|\\[.*?\\]|Music Video|Official Audio/gi, '').trim();
  const query = `${cleanTitle} ${artist}`;
  
  console.log(`[JioSaavn Hybrid] Searching for audio: "${query}"`);
  
  const url = `https://www.jiosaavn.com/api.php?__call=search.getResults&q=${encodeURIComponent(query)}&n=1&p=1&_format=json&_marker=0&ctx=web6dot0`;
  const response = await fetch(url);
  
  if (!response.ok) throw new Error('JioSaavn search failed');
  const data = await response.json();
  
  if (!data.results || data.results.length === 0) {
    throw new Error('No matching song found on JioSaavn for ' + query);
  }
  
  const bestMatch = data.results[0];
  
  if (bestMatch.encrypted_media_url) {
    const decryptedUrl = decryptUrl(bestMatch.encrypted_media_url);
    if (decryptedUrl) {
      console.log(`[JioSaavn Hybrid] Found audio stream for: ${bestMatch.song}`);
      return decryptedUrl;
    }
  }
  
  throw new Error('Failed to decrypt JioSaavn URL');
}

async function getPlaylistTracks(playlistId, limit = 30) {
  const url = `https://www.jiosaavn.com/api.php?__call=playlist.getDetails&listid=${playlistId}&_format=json&_marker=0&ctx=web6dot0`;
  try {
    const response = await fetch(url);
    if (!response.ok) return searchSaavn('Top Hits', limit);
    
    const data = await response.json();
    if (!data.list) return searchSaavn('Top Hits', limit);
    
    return data.list.map(mapSaavnResult);
  } catch (e) {
    return searchSaavn('Top Hits', limit);
  }
}

async function getRelatedTracks(songId, limit = 20) {
  try {
    const stationUrl = `https://www.jiosaavn.com/api.php?__call=webradio.createEntityStation&entity_id=${songId}&entity_type=queue&_format=json&_marker=0&ctx=web6dot0`;
    
    const response = await fetch(stationUrl);
    if (!response.ok) return searchSaavn('Top songs', limit);
    
    const data = await response.json();
    const stationId = data.stationid;
    if (!stationId) return searchSaavn('Top songs', limit);
    
    const tracksUrl = `https://www.jiosaavn.com/api.php?__call=webradio.getSong&stationid=${stationId}&k=${limit}&_format=json&_marker=0&ctx=web6dot0`;
    const tracksRes = await fetch(tracksUrl);
    const tracksData = await tracksRes.json();
    
    const results = [];
    for (const key in tracksData) {
      if (tracksData[key] && tracksData[key].song) {
        // webradio wraps the actual song object in another object
        results.push(mapSaavnResult(tracksData[key].song));
      }
    }
    
    if (results.length === 0) return searchSaavn('Top songs', limit);
    return results;
  } catch (e) {
    return searchSaavn('Top songs', limit);
  }
}

module.exports = {
  searchSaavn,
  getStreamUrl,
  getSaavnStreamByMetadata,
  getPlaylistTracks,
  getRelatedTracks
};
