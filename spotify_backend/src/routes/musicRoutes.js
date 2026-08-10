const express = require('express');
const YTMusic = require('ytmusic-api');
const playdl = require('play-dl');

const router = express.Router();
const ytmusic = new YTMusic();
let ytmusicInitialized = false;

const cache = new Map();
function cacheGet(key) {
  const entry = cache.get(key);
  if (!entry) return null;
  if (Date.now() > entry.expires) { cache.delete(key); return null; }
  return entry.data;
}
function cacheSet(key, data, ttlSeconds) {
  cache.set(key, { data, expires: Date.now() + ttlSeconds * 1000 });
}

async function initYTMusic() {
  if (!ytmusicInitialized) {
    await ytmusic.initialize();
    ytmusicInitialized = true;
  }
}

function getBestThumbnail(thumbnails) {
  if (!thumbnails || thumbnails.length === 0) return '';
  let url = thumbnails[thumbnails.length - 1].url;
  if (url.includes('hqdefault.jpg')) {
      url = url.replace('hqdefault.jpg', 'maxresdefault.jpg');
  }
  if (url.includes('=w')) {
      url = url.replace(/=w\d+-h\d+/, '=w540-h540');
  }
  return url;
}

const stringSimilarity = require('string-similarity');

function normalizeStr(str) {
  if (!str) return '';
  return str.toLowerCase()
    .replace(/\([^)]*\)/g, '')
    .replace(/\[[^\]]*\]/g, '')
    .replace(/\b(feat\.?|ft\.?|featuring)\b.*$/g, '')
    .replace(/[^\w\s]/gi, '')
    .trim();
}

function pickBetterVersion(a, b) {
  if (a.bitrate !== b.bitrate) {
    return a.bitrate > b.bitrate ? a : b;
  }
  return a.source === 'jiosaavn' ? a : b;
}

router.get('/search', async (req, res) => {
  try {
    const { q, type = 'songs' } = req.query;
    if (!q) return res.status(400).json({ error: 'Query parameter q is required' });

    const cacheKey = `search:unified:${type}:${q}`;
    const cached = cacheGet(cacheKey);
    if (cached) return res.json(cached);

    let results = [];

    if (type === 'songs') {
      const saavnPromise = fetch(`https://saavn.dev/api/search/songs?query=${encodeURIComponent(q)}`)
        .then(r => r.ok ? r.json() : null)
        .then(data => {
          if (!data?.data?.results) return [];
          return data.data.results.map(s => {
            const bestImage = s.image?.sort((a, b) => parseInt(b.quality) - parseInt(a.quality))[0]?.url;
            const bestAudio = s.downloadUrl?.sort((a, b) => parseInt(b.quality) - parseInt(a.quality))[0];
            return {
              videoId: s.id, // keeping videoId key for flutter model compatibility
              source: 'jiosaavn',
              title: s.name,
              artist: s.primaryArtists || 'Unknown Artist',
              thumbnailUrl: bestImage || '',
              duration: parseInt(s.duration) || 0,
              streamUrl: bestAudio?.url || '',
              bitrate: parseInt(bestAudio?.quality) || 128,
              album: s.album?.name || null
            };
          }).filter(s => s.streamUrl !== '');
        }).catch(() => []);

      const jamendoPromise = fetch(`https://api.jamendo.com/v3.0/tracks?client_id=56d30c95&format=json&limit=20&search=${encodeURIComponent(q)}`)
        .then(r => r.ok ? r.json() : null)
        .then(data => {
          if (!data?.results) return [];
          return data.results.map(s => ({
            videoId: s.id,
            source: 'jamendo',
            title: s.name,
            artist: s.artist_name || 'Unknown Artist',
            thumbnailUrl: s.image || '',
            duration: parseInt(s.duration) || 0,
            streamUrl: s.audio || '',
            bitrate: 128, // Jamendo default MP3 bitrate for free API
            album: s.album_name || null
          })).filter(s => s.streamUrl !== '');
        }).catch(() => []);

      const [saavnResults, jamendoResults] = await Promise.all([saavnPromise, jamendoPromise]);
      const allResults = [...saavnResults, ...jamendoResults];
      
      // Deduplication using fuzzy match
      const deduplicated = [];
      for (const item of allResults) {
        let isDuplicate = false;
        const normTitle = normalizeStr(item.title);
        const normArtist = normalizeStr(item.artist);

        for (let i = 0; i < deduplicated.length; i++) {
          const existing = deduplicated[i];
          const existTitle = normalizeStr(existing.title);
          const existArtist = normalizeStr(existing.artist);

          const titleSim = stringSimilarity.compareTwoStrings(normTitle, existTitle);
          const artistSim = stringSimilarity.compareTwoStrings(normArtist, existArtist);

          if (titleSim > 0.85 && artistSim > 0.7) {
            isDuplicate = true;
            deduplicated[i] = pickBetterVersion(existing, item);
            break;
          }
        }
        if (!isDuplicate) {
          deduplicated.push(item);
        }
      }
      results = deduplicated;
    } else {
      // Fallback to YouTube Music for artists, albums, playlists (since Saavn/Jamendo API for these require full app rewrite)
      await initYTMusic();
      if (type === 'albums') {
        const raw = await ytmusic.searchAlbums(q);
        results = raw.map(a => ({
          id: a.albumId, title: a.name, artistName: a.artist?.name || 'Unknown Artist',
          thumbnailUrl: getBestThumbnail(a.thumbnails), year: a.year
        }));
      } else if (type === 'artists') {
        const raw = await ytmusic.searchArtists(q);
        results = raw.map(a => ({
          id: a.artistId, name: a.name, thumbnailUrl: getBestThumbnail(a.thumbnails)
        }));
      } else if (type === 'playlists') {
        const raw = await ytmusic.searchPlaylists(q);
        results = raw.map(p => ({
          id: p.playlistId, title: p.name, thumbnailUrl: getBestThumbnail(p.thumbnails)
        }));
      } else {
        return res.status(400).json({ error: 'Invalid search type' });
      }
    }

    cacheSet(cacheKey, results, 300);
    res.json(results);
  } catch (error) {
    console.error('Search error:', error);
    res.status(500).json({ error: 'Failed to perform search' });
  }
});

const youtubedl = require('youtube-dl-exec');
const fs = require('fs');

router.get('/stream/:songId', async (req, res) => {
  try {
    const { songId } = req.params;
    const cacheKey = `stream:${songId}`;
    const cached = cacheGet(cacheKey);
    if (cached) return res.json({ url: cached });

    const videoUrl = `https://www.youtube.com/watch?v=${songId}`;
    let streamUrl = null;
    let lastError = null;

    // Cobalt public API instances
    const cobaltInstances = [
      'https://api.cobalt.tools',
      'https://co.wuk.sh'
    ];

    for (const instance of cobaltInstances) {
      try {
        const response = await fetch(`${instance}/api/json`, {
          method: 'POST',
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
          },
          body: JSON.stringify({
            url: videoUrl,
            isAudioOnly: true,
            aFormat: 'mp3'
          })
        });

        if (response.ok) {
          const data = await response.json();
          if (data.status === 'stream' || data.status === 'redirect') {
            streamUrl = data.url;
            break;
          } else if (data.url) {
            streamUrl = data.url;
            break;
          }
        }
      } catch (err) {
        lastError = err;
      }
    }

    if (streamUrl) {
      cacheSet(cacheKey, streamUrl, 60);
      res.json({ url: streamUrl });
    } else {
      console.error('Cobalt API extraction failed:', lastError?.message || lastError);
      res.status(502).json({ 
        error: 'stream_unavailable', 
        message: 'Could not fetch the song right now. Please try again later.' 
      });
    }
  } catch (error) {
    console.error('Unexpected Stream error:', error);
    res.status(500).json({ error: 'Failed to get stream URL' });
  }
});

router.get('/artist/:artistId', async (req, res) => {
  try {
    const { artistId } = req.params;
    const cacheKey = `artist:${artistId}`;
    const cached = cacheGet(cacheKey);
    if (cached) return res.json(cached);

    await initYTMusic();
    try {
      const artistInfo = await ytmusic.getArtist(artistId);
      
      const mapped = {
        id: artistId,
        name: artistInfo.name,
        thumbnailUrl: getBestThumbnail(artistInfo.thumbnails),
        description: artistInfo.description || '',
        subscribers: artistInfo.subscribers || '',
        topSongs: (artistInfo.topSongs || []).map(s => ({
          videoId: s.videoId,
          title: s.name,
          artist: s.artist?.name || artistInfo.name,
          thumbnailUrl: getBestThumbnail(s.thumbnails),
          duration: s.duration
        })),
        albums: (artistInfo.albums || []).map(a => ({
          id: a.albumId,
          title: a.name,
          artistName: artistInfo.name,
          thumbnailUrl: getBestThumbnail(a.thumbnails),
          year: a.year
        })),
        singles: (artistInfo.singles || []).map(s => ({
          id: s.albumId,
          title: s.name,
          artistName: artistInfo.name,
          thumbnailUrl: getBestThumbnail(s.thumbnails),
          year: s.year
        })),
        relatedArtists: (artistInfo.relatedArtists || []).map(r => ({
          id: r.artistId,
          name: r.name,
          thumbnailUrl: getBestThumbnail(r.thumbnails)
        }))
      };

      cacheSet(cacheKey, mapped, 600);
      return res.json(mapped);
    } catch (err) {
      // Fallback
      const fallbackSearch = await ytmusic.searchSongs(artistId);
      const mapped = {
        id: artistId,
        name: artistId,
        thumbnailUrl: '',
        description: '',
        subscribers: '',
        topSongs: fallbackSearch.slice(0, 10).map(s => ({
          videoId: s.videoId,
          title: s.name,
          artist: s.artist?.name || 'Unknown',
          thumbnailUrl: getBestThumbnail(s.thumbnails),
          duration: s.duration
        })),
        albums: [],
        singles: [],
        relatedArtists: []
      };
      cacheSet(cacheKey, mapped, 600);
      return res.json(mapped);
    }
  } catch (error) {
    console.error('Artist error:', error);
    res.status(500).json({ error: 'Failed to fetch artist details' });
  }
});

router.get('/album/:albumId', async (req, res) => {
  try {
    const { albumId } = req.params;
    const cacheKey = `album:${albumId}`;
    const cached = cacheGet(cacheKey);
    if (cached) return res.json(cached);

    await initYTMusic();
    const albumInfo = await ytmusic.getAlbum(albumId);
    
    const mapped = {
      id: albumId,
      title: albumInfo.name,
      artistName: albumInfo.artist?.name || 'Unknown Artist',
      artistId: albumInfo.artist?.artistId || '',
      thumbnailUrl: getBestThumbnail(albumInfo.thumbnails),
      year: albumInfo.year || '',
      tracks: (albumInfo.songs || []).map((s, index) => ({
        videoId: s.videoId,
        title: s.name,
        artist: s.artist?.name || albumInfo.artist?.name || 'Unknown Artist',
        thumbnailUrl: getBestThumbnail(s.thumbnails) || getBestThumbnail(albumInfo.thumbnails),
        durationMs: s.duration,
        trackNumber: index + 1
      }))
    };

    cacheSet(cacheKey, mapped, 600);
    res.json(mapped);
  } catch (error) {
    console.error('Album error:', error);
    res.status(500).json({ error: 'Failed to fetch album details' });
  }
});

router.get('/lyrics/:videoId', async (req, res) => {
  try {
    const { videoId } = req.params;
    const cacheKey = `lyrics:${videoId}`;
    const cached = cacheGet(cacheKey);
    if (cached) return res.json(cached);

    // Provide empty response as lyrics are not available
    const response = { syncedLines: null, plainText: null };
    cacheSet(cacheKey, response, 900);
    res.json(response);
  } catch (error) {
    console.error('Lyrics error:', error);
    res.status(500).json({ error: 'Failed to fetch lyrics' });
  }
});

router.get('/watch/:videoId', async (req, res) => {
  try {
    const { videoId } = req.params;
    const cacheKey = `watch:${videoId}`;
    const cached = cacheGet(cacheKey);
    if (cached) return res.json(cached);

    await initYTMusic();
    let results = [];
    
    if (typeof ytmusic.getUpNextVideos === 'function') {
      try {
        const upNext = await ytmusic.getUpNextVideos(videoId);
        results = upNext.map(s => ({
          videoId: s.videoId,
          title: s.name,
          artist: s.artist?.name || 'Unknown Artist',
          thumbnailUrl: getBestThumbnail(s.thumbnails),
          duration: s.duration
        }));
      } catch (err) {
        // ignore and fallback
      }
    }

    if (results.length === 0) {
      // fallback
      const fallbackSearch = await ytmusic.searchSongs(videoId);
      results = fallbackSearch.map(s => ({
        videoId: s.videoId,
        title: s.name,
        artist: s.artist?.name || 'Unknown Artist',
        thumbnailUrl: getBestThumbnail(s.thumbnails),
        duration: s.duration
      }));
    }

    results = results.slice(0, 20);
    cacheSet(cacheKey, results, 180);
    res.json(results);
  } catch (error) {
    console.error('Watch error:', error);
    res.status(500).json({ error: 'Failed to fetch watch recommendations' });
  }
});

module.exports = router;
