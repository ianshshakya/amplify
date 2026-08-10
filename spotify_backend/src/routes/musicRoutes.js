const express = require('express');
const YTMusic = require('ytmusic-api');
const youtubedl = require('youtube-dl-exec');

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
  return thumbnails[thumbnails.length - 1].url;
}

router.get('/search', async (req, res) => {
  try {
    const { q, type = 'songs' } = req.query;
    if (!q) return res.status(400).json({ error: 'Query parameter q is required' });

    const cacheKey = `search:${type}:${q}`;
    const cached = cacheGet(cacheKey);
    if (cached) return res.json(cached);

    await initYTMusic();
    let results = [];

    if (type === 'songs') {
      const raw = await ytmusic.searchSongs(q);
      results = raw.map(s => ({
        videoId: s.videoId,
        title: s.name,
        artist: s.artist?.name || 'Unknown Artist',
        thumbnailUrl: getBestThumbnail(s.thumbnails),
        duration: s.duration
      }));
    } else if (type === 'albums') {
      const raw = await ytmusic.searchAlbums(q);
      results = raw.map(a => ({
        id: a.albumId,
        title: a.name,
        artistName: a.artist?.name || 'Unknown Artist',
        thumbnailUrl: getBestThumbnail(a.thumbnails),
        year: a.year
      }));
    } else if (type === 'artists') {
      const raw = await ytmusic.searchArtists(q);
      results = raw.map(a => ({
        id: a.artistId,
        name: a.name,
        thumbnailUrl: getBestThumbnail(a.thumbnails)
      }));
    } else if (type === 'playlists') {
      const raw = await ytmusic.searchPlaylists(q);
      results = raw.map(p => ({
        id: p.playlistId,
        title: p.name,
        thumbnailUrl: getBestThumbnail(p.thumbnails)
      }));
    } else {
      return res.status(400).json({ error: 'Invalid search type' });
    }

    cacheSet(cacheKey, results, 300);
    res.json(results);
  } catch (error) {
    console.error('Search error:', error);
    res.status(500).json({ error: 'Failed to perform search' });
  }
});

router.get('/stream/:songId', async (req, res) => {
  try {
    const { songId } = req.params;
    const cacheKey = `stream:${songId}`;
    const cached = cacheGet(cacheKey);
    if (cached) return res.json({ url: cached });

    const videoUrl = `https://www.youtube.com/watch?v=${songId}`;
    
    let streamUrl = null;
    let attempts = 0;
    while (attempts < 2 && !streamUrl) {
      try {
        const info = await youtubedl(videoUrl, {
          dumpSingleJson: true,
          noWarnings: true,
          noCheckCertificate: true,
          youtubeSkipDashManifest: true,
          format: 'bestaudio'
        });
        streamUrl = info.url;
      } catch (err) {
        attempts++;
        if (attempts >= 2) throw err;
        await new Promise(r => setTimeout(r, 1000));
      }
    }

    if (streamUrl) {
      cacheSet(cacheKey, streamUrl, 60);
      res.json({ url: streamUrl });
    } else {
      res.status(404).json({ error: 'Stream not found' });
    }
  } catch (error) {
    console.error('Stream error:', error);
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
