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

    // 1. Try Invidious API (Very resilient to datacenter blocks)
    const invidiousInstances = [
      'https://inv.tux.pizza',
      'https://invidious.nerdvpn.de',
      'https://invidious.lunar.icu',
      'https://invidious.privacydev.net'
    ];
    
    for (const instance of invidiousInstances) {
      if (streamUrl) break;
      try {
        const response = await fetch(`${instance}/api/v1/videos/${songId}`, {
          headers: { 'User-Agent': 'Mozilla/5.0' }
        });
        
        if (response.ok) {
          const data = await response.json();
          // Invidious returns formatStreams (which contain video+audio or audio only)
          // and adaptiveFormats (which contain separate audio tracks)
          const formats = [...(data.adaptiveFormats || []), ...(data.formatStreams || [])];
          
          // Try to find the best audio-only stream (m4a or webm)
          const audioFormats = formats.filter(f => f.type && f.type.startsWith('audio'));
          if (audioFormats.length > 0) {
            // Sort by bitrate highest to lowest
            audioFormats.sort((a, b) => (parseInt(b.bitrate) || 0) - (parseInt(a.bitrate) || 0));
            streamUrl = audioFormats[0].url;
          } else if (formats.length > 0) {
            streamUrl = formats[0].url;
          }
        }
      } catch (err) {
        lastError = err;
      }
    }

    // 2. Fallback to @distube/ytdl-core (Built specifically to bypass bot detection on servers)
    if (!streamUrl) {
      try {
        const ytdl = require('@distube/ytdl-core');
        const info = await ytdl.getInfo(videoUrl);
        const format = ytdl.chooseFormat(info.formats, { quality: 'highestaudio' });
        if (format && format.url) {
          streamUrl = format.url;
        }
      } catch (err) {
        lastError = err;
      }
    }

    if (streamUrl) {
      cacheSet(cacheKey, streamUrl, 60);
      res.json({ url: streamUrl });
    } else {
      console.error('All extraction methods failed:', lastError?.message || lastError);
      res.status(502).json({ 
        error: 'stream_unavailable', 
        message: 'Could not bypass YouTube restrictions right now. Please try again later.' 
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
