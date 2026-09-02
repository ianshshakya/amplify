const CryptoJS = require('crypto-js');
const { getTracks } = require('spotify-url-info')(fetch);

const saavnHeaders = {
  'X-Forwarded-For': '103.15.228.1', // Delhi IP to bypass geo-restrictions on Render
  'Accept-Language': 'en-US,en;q=0.9,hi;q=0.8,bn;q=0.7',
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
};

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

  // Normalize play count — JioSaavn returns strings like "100,000" or raw numbers
  let playCount = 0;
  if (data.play_count !== undefined && data.play_count !== null) {
    const raw = String(data.play_count).replace(/,/g, '');
    playCount = parseInt(raw, 10) || 0;
  }

  // Extract year from release_date or year field (format: "YYYY-MM-DD" or "YYYY")
  let releaseYear = null;
  const rawYear = data.year || data.release_date || '';
  if (rawYear) {
    const yearMatch = String(rawYear).match(/^(\d{4})/);
    if (yearMatch) releaseYear = parseInt(yearMatch[1], 10);
  }

  // Normalize language — JioSaavn uses lowercase like 'hindi', 'english', 'punjabi'
  const language = data.language
    ? data.language.charAt(0).toUpperCase() + data.language.slice(1).toLowerCase()
    : null;

  // Album info
  const album = data.album ? decodeHTMLEntities(data.album) : null;

  return {
    videoId: data.id,
    title: decodeHTMLEntities(data.song || data.title || 'Unknown Title'),
    artist: decodeHTMLEntities(data.primary_artists || data.subtitle || 'Unknown Artist'),
    thumbnailUrl: thumbnailUrl,
    duration: duration,
    // ── Enrichment fields (used by AmplifyNormalizer) ──
    playCount: playCount,
    releaseYear: releaseYear,
    language: language,
    album: album,
    isExplicit: data.explicit_content === 1 || data.explicit_content === '1',
  };
}

async function searchSaavn(query, limit = 20, targetArtist = null) {
  let allResults = [];
  let page = 1;
  const maxPerPage = 40;
  
  while (allResults.length < limit) {
    const url = `https://www.jiosaavn.com/api.php?__call=search.getResults&q=${encodeURIComponent(query)}&n=${maxPerPage}&p=${page}&_format=json&_marker=0&ctx=web6dot0`;
    const response = await fetch(url, { headers: saavnHeaders });
    if (!response.ok) break;
    
    const data = await response.json();
    if (!data.results || data.results.length === 0) break;
    
    allResults = allResults.concat(data.results);
    page++;
    
    if (data.results.length < maxPerPage) break; // No more results
  }
  
  // Truncate to exact limit if we over-fetched
  if (allResults.length > limit) {
    allResults = allResults.slice(0, limit);
  }
  
  const cleanQuery = query.toLowerCase().trim();
  const cleanTargetArtist = targetArtist ? targetArtist.toLowerCase().trim() : null;

  // Smart Ranking Algorithm
  const sortedResults = allResults.sort((a, b) => {
    let scoreA = 0;
    let scoreB = 0;

    const titleA = decodeHTMLEntities(a.song || a.title || '').toLowerCase();
    const titleB = decodeHTMLEntities(b.song || b.title || '').toLowerCase();
    const artistA = decodeHTMLEntities(a.primary_artists || a.subtitle || '').toLowerCase();
    const artistB = decodeHTMLEntities(b.primary_artists || b.subtitle || '').toLowerCase();

    // 1. Exact Title Match Boost (+10000)
    if (titleA === cleanQuery) scoreA += 10000;
    if (titleB === cleanQuery) scoreB += 10000;

    // 2. Target Artist Boost (+5000) - For "Song by Artist" NLP queries
    if (cleanTargetArtist) {
      if (artistA.includes(cleanTargetArtist)) scoreA += 5000;
      if (artistB.includes(cleanTargetArtist)) scoreB += 5000;
    }

    // 3. Popularity (Play Count) Boost (fractional to keep within bounds)
    const playA = parseInt(String(a.play_count || '0').replace(/,/g, ''), 10) || 0;
    const playB = parseInt(String(b.play_count || '0').replace(/,/g, ''), 10) || 0;
    
    // Normalize play count to a 0-1000 scale assuming max playcount is around 1 billion
    scoreA += (playA / 1000000); 
    scoreB += (playB / 1000000);

    return scoreB - scoreA; // Descending
  });
  
  return sortedResults.map(mapSaavnResult);
}

async function searchSaavnArtists(query, limit = 20) {
  const url = `https://www.jiosaavn.com/api.php?__call=search.getArtistResults&q=${encodeURIComponent(query)}&n=${limit}&p=1&_format=json&_marker=0&ctx=web6dot0`;
  const response = await fetch(url, { headers: saavnHeaders });
  if (!response.ok) return [];
  const data = await response.json();
  if (!data.results || data.results.length === 0) return [];
  
  return data.results.map(a => {
    let imageUrl = a.image || '';
    if (imageUrl) imageUrl = imageUrl.replace('150x150', '500x500');
    return {
      id: a.id || a.url,
      name: decodeHTMLEntities(a.title || a.name || 'Unknown Artist'),
      imageUrl: imageUrl,
      followerCount: a.description || '',
      isVerified: Boolean(a.isVerified),
      biography: '',
      topSongs: [],
      albums: [],
      singles: [],
      relatedArtists: []
    };
  });
}

async function searchSaavnAlbums(query, limit = 20) {
  const url = `https://www.jiosaavn.com/api.php?__call=search.getAlbumResults&q=${encodeURIComponent(query)}&n=${limit}&p=1&_format=json&_marker=0&ctx=web6dot0`;
  const response = await fetch(url, { headers: saavnHeaders });
  if (!response.ok) return [];
  const data = await response.json();
  if (!data.results || data.results.length === 0) return [];

  return data.results.map(a => {
    let thumbnailUrl = a.image || '';
    if (thumbnailUrl) thumbnailUrl = thumbnailUrl.replace('150x150', '500x500');
    return {
      id: a.id,
      title: decodeHTMLEntities(a.title || 'Unknown Album'),
      artistName: decodeHTMLEntities(a.subtitle || a.music || 'Unknown'),
      year: a.year || '',
      thumbnailUrl: thumbnailUrl,
      totalDuration: '',
      tracks: [] // Albums from search won't have full tracks list yet
    };
  });
}

async function searchSaavnPage(query, page = 1) {
  const maxPerPage = 40;
  const url = `https://www.jiosaavn.com/api.php?__call=search.getResults&q=${encodeURIComponent(query)}&n=${maxPerPage}&p=${page}&_format=json&_marker=0&ctx=web6dot0`;
  const response = await fetch(url, { headers: saavnHeaders });
  
  if (!response.ok) return [];
  
  const data = await response.json();
  if (!data.results || data.results.length === 0) return [];
  
  return data.results.map(mapSaavnResult);
}

/**
 * Search with optional language and year range filters.
 * Fetches a larger candidate pool and post-filters by the given constraints.
 */
async function searchSaavnWithFilters(query, limit = 20, options = {}) {
  const { language = null, minYear = null, maxYear = null } = options;

  // Fetch a larger pool to account for post-filter attrition
  const poolSize = Math.min(limit * 5, 200);
  const rawResults = await searchSaavn(query, poolSize);

  let filtered = rawResults;

  if (language) {
    const targetLang = language.toLowerCase();
    filtered = filtered.filter(r => r.language && r.language.toLowerCase() === targetLang);
  }

  if (minYear !== null) {
    filtered = filtered.filter(r => r.releaseYear !== null && r.releaseYear >= minYear);
  }

  if (maxYear !== null) {
    filtered = filtered.filter(r => r.releaseYear !== null && r.releaseYear <= maxYear);
  }

  // If hard-filtering removed too many results, loosen the year constraint and try again
  if (filtered.length < Math.min(limit, 5) && (minYear !== null || maxYear !== null)) {
    if (process.env.NODE_ENV !== 'production') console.log(`[Saavn] Year filter too strict for "${query}", using unfiltered pool.`);
    filtered = language
      ? rawResults.filter(r => r.language && r.language.toLowerCase() === (language || '').toLowerCase())
      : rawResults;
  }

  return filtered.slice(0, limit);
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
    return decrypted.replace('_96.mp4', '_320.mp4');
  } catch (err) {
    console.error('Decryption error:', err);
    return null;
  }
}

async function getSongDetails(songId) {
  const url = `https://www.jiosaavn.com/api.php?__call=song.getDetails&pids=${songId}&_format=json&_marker=0&ctx=web6dot0`;
  const response = await fetch(url, { headers: saavnHeaders });
  if (!response.ok) throw new Error('Failed to fetch song details');
  
  const data = await response.json();
  
  let songData = null;
  if (data.songs && data.songs.length > 0) {
    songData = data.songs.find(s => s.id === songId) || data.songs[0];
  } else if (data[songId]) {
    songData = data[songId];
  }
  
  if (!songData) {
    throw new Error('Song not found in JioSaavn response');
  }
  
  return songData;
}

async function getStreamUrl(songId) {
  const songData = await getSongDetails(songId);
  
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
  let cleanTitle = title.replace(/\(Official.*?\)|\(Lyric.*?\)|\[.*?\]|Music Video|Official Audio/gi, '').trim();
  
  if (artist && cleanTitle.toLowerCase().includes(artist.toLowerCase())) {
     cleanTitle = cleanTitle.replace(new RegExp(artist, 'ig'), '').replace(/-/g, '').trim();
  }
  
  cleanTitle = cleanTitle.replace(/^[\s-]+|[\s-]+$/g, '');
  const query = `${cleanTitle} ${artist}`.trim();
  
  if (process.env.NODE_ENV !== 'production') console.log(`[JioSaavn Hybrid] Searching for audio: "${query}"`);
  
  const url = `https://www.jiosaavn.com/api.php?__call=search.getResults&q=${encodeURIComponent(query)}&n=1&p=1&_format=json&_marker=0&ctx=web6dot0`;
  const response = await fetch(url, { headers: saavnHeaders });
  
  if (!response.ok) throw new Error('JioSaavn search failed');
  const data = await response.json();
  
  if (!data.results || data.results.length === 0) {
    throw new Error('No matching song found on JioSaavn for ' + query);
  }
  
  const bestMatch = data.results[0];
  
  if (bestMatch.encrypted_media_url) {
    const decryptedUrl = decryptUrl(bestMatch.encrypted_media_url);
    if (decryptedUrl) {
      if (process.env.NODE_ENV !== 'production') console.log(`[JioSaavn Hybrid] Found audio stream for: ${bestMatch.song}`);
      return decryptedUrl;
    }
  }
  
  throw new Error('Failed to decrypt JioSaavn URL');
}

async function getPlaylistTracks(playlistId, limit = 30) {
  let allTracks = [];
  let page = 1;
  const maxPerPage = 50;
  
  try {
    while (allTracks.length < limit) {
      const url = `https://www.jiosaavn.com/api.php?__call=playlist.getDetails&listid=${playlistId}&p=${page}&n=${maxPerPage}&_format=json&_marker=0&ctx=web6dot0`;
      const response = await fetch(url, { headers: saavnHeaders });
      if (!response.ok) break;
      
      const data = await response.json();
      const tracksArray = data.songs || data.list;
      
      if (!tracksArray || !Array.isArray(tracksArray) || tracksArray.length === 0) break;
      
      allTracks = allTracks.concat(tracksArray.map(mapSaavnResult));
      page++;
      
      if (tracksArray.length < maxPerPage) break;
    }
    
    if (allTracks.length === 0) return searchSaavn('Top Hits', limit);
    return allTracks.slice(0, limit);
  } catch (e) {
    return searchSaavn('Top Hits', limit);
  }
}

async function getRelatedTracks(songId, limit = 20) {
  try {
    const stationUrl = `https://www.jiosaavn.com/api.php?__call=webradio.createEntityStation&entity_id=${songId}&entity_type=queue&_format=json&_marker=0&ctx=web6dot0`;
    
    const response = await fetch(stationUrl, { headers: saavnHeaders });
    if (!response.ok) return searchSaavn('Top songs', limit);
    
    const data = await response.json();
    const stationId = data.stationid;
    if (!stationId) return searchSaavn('Top songs', limit);
    
    // Fetch a large pool of related tracks (50) to sort by popularity
    const tracksUrl = `https://www.jiosaavn.com/api.php?__call=webradio.getSong&stationid=${stationId}&k=50&_format=json&_marker=0&ctx=web6dot0`;
    const tracksRes = await fetch(tracksUrl, { headers: saavnHeaders });
    const tracksData = await tracksRes.json();
    
    let rawSongs = [];
    for (const key in tracksData) {
      if (tracksData[key] && tracksData[key].song) {
        rawSongs.push(tracksData[key].song);
      }
    }
    
    // Sort the related tracks by most streamed/listened (play_count)
    rawSongs.sort((a, b) => {
      const playA = parseInt(a.play_count, 10) || 0;
      const playB = parseInt(b.play_count, 10) || 0;
      return playB - playA; // descending
    });
    
    // Take the top requested limit and map them
    const results = rawSongs.slice(0, limit).map(mapSaavnResult);
    
    if (results.length === 0) return searchSaavn('Top songs', limit);
    return results;
  } catch (e) {
    return searchSaavn('Top songs', limit);
  }
}

async function getLyrics(songId) {
  try {
    // 1. Try JioSaavn first
    const url = `https://www.jiosaavn.com/api.php?__call=lyrics.getLyrics&lyrics_id=${songId}&ctx=web6dot0&api_version=4&_format=json&_marker=0`;
    const response = await fetch(url, { headers: saavnHeaders });
    
    if (response.ok) {
      const data = await response.json();
      if (data.lyrics) {
        return {
          id: songId,
          text: data.lyrics.replace(/<br>/g, '\n')
        };
      }
    }

    // 2. Fallback to LRCLib.net
    if (process.env.NODE_ENV !== 'production') console.log(`[Lyrics] JioSaavn empty for ${songId}, trying LRCLib...`);
    const songData = await getSongDetails(songId);
    
    // Use the same extraction logic used by mapSaavnResult
    const titleRaw = songData.song || songData.title || '';
    const artistRaw = songData.primary_artists || songData.subtitle || '';
    
    // Basic cleanup
    const cleanTitle = decodeHTMLEntities(titleRaw).replace(/\(Official.*?\)|\[.*?\]/gi, '').trim();
    const cleanArtist = decodeHTMLEntities(artistRaw).split(',')[0].trim();
    
    if (cleanTitle) {
      const lrcUrl = `https://lrclib.net/api/get?track_name=${encodeURIComponent(cleanTitle)}&artist_name=${encodeURIComponent(cleanArtist)}`;
      const lrcRes = await fetch(lrcUrl);
      if (lrcRes.ok) {
        const lrcData = await lrcRes.json();
        if (lrcData && lrcData.plainLyrics) {
          if (process.env.NODE_ENV !== 'production') console.log(`[Lyrics] Found LRCLib fallback for ${cleanTitle}`);
          return {
            id: songId,
            text: lrcData.plainLyrics
          };
        }
      }
    }

    return null;
  } catch (error) {
    if (process.env.NODE_ENV !== 'production') console.error('getLyrics error:', error.message);
    return null;
  }
}

async function fetchSpotifyPlaylistTracks(spotifyUrl, limit = 50, fallbackSaavnId = null) {
  try {
    const tracks = await getTracks(spotifyUrl);
    
    // Take up to 'limit' tracks
    const topTracks = tracks.slice(0, limit);
    
    // We fetch them concurrently in small batches to avoid rate limiting
    const results = [];
    for (let i = 0; i < topTracks.length; i += 5) {
      const chunk = topTracks.slice(i, i + 5);
      const chunkPromises = chunk.map(async (t) => {
        try {
          const title = t.name || '';
          const artist = t.artist || '';
          
          // 1. Try exact match with artist
          let searchRes = await searchSaavn(`${title} ${artist}`.trim(), 1);
          if (searchRes && searchRes.length > 0) return searchRes[0];
          
          // 2. Try looser match with just title
          searchRes = await searchSaavn(title.trim(), 1);
          if (searchRes && searchRes.length > 0) return searchRes[0];
          
          return null;
        } catch (err) {
          return null;
        }
      });
      
      const chunkResults = await Promise.all(chunkPromises);
      results.push(...chunkResults.filter(r => r != null));
    }
    
    if (results.length === 0) throw new Error('No tracks found via cross-referencing');
    return results;
  } catch (error) {
    console.error('Spotify fetch error:', error);
    // Fallback to Saavn Playlist if scraping completely fails
    if (fallbackSaavnId) {
      return getPlaylistTracks(fallbackSaavnId, limit);
    }
    return searchSaavn('Top Hits', limit);
  }
}

module.exports = {
  searchSaavn,
  searchSaavnPage,
  searchSaavnWithFilters,
  searchSaavnArtists,
  searchSaavnAlbums,
  getStreamUrl,
  getSaavnStreamByMetadata,
  getPlaylistTracks,
  getRelatedTracks,
  getLyrics,
  fetchSpotifyPlaylistTracks
};
