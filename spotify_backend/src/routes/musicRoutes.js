const express = require('express');
const { searchSaavn, searchSaavnPage, getStreamUrl, getPlaylistTracks, getRelatedTracks, getLyrics, searchSaavnArtists, searchSaavnAlbums } = require('../utils/saavn');
const { normalizeTracks, deduplicateTracks } = require('../services/AmplifyNormalizer');
const CreatorSong = require('../models/CreatorSong');
const { streamCache, metadataCache } = require('../utils/cache');
const https = require('https');
const http = require('http');

const router = express.Router();

// 0. Creator Songs
router.get('/creator', async (req, res) => {
  try {
    const songs = await CreatorSong.find().sort({ createdAt: -1 }).lean();
    res.json(songs);
  } catch (error) {
    console.error('Creator songs error:', error.message);
    res.status(500).json({ error: 'Failed to fetch creator songs.' });
  }
});

// 1. Search
router.get('/search', async (req, res) => {
  try {
    const query = req.query.q;
    if (!query) return res.status(400).json({ error: 'Missing search query' });

    const type = req.query.type || 'songs';
    const cacheKey = `search_${type}_${query}`;
    const cachedResult = metadataCache.get(cacheKey);
    if (cachedResult) return res.json(cachedResult);

    // Entity Routing (Artists & Albums)
    if (type === 'artists') {
      const artists = await searchSaavnArtists(query, 20);
      metadataCache.set(cacheKey, artists);
      return res.json(artists);
    }
    
    if (type === 'albums') {
      const albums = await searchSaavnAlbums(query, 20);
      metadataCache.set(cacheKey, albums);
      return res.json(albums);
    }

    // Default: Songs
    if (query === '_FETCH_GLOBAL_100_') {
      const creatorSongs = await CreatorSong.find().limit(100).sort({ createdAt: -1 }).lean();
      const result = creatorSongs.map(s => ({
        videoId: s.videoId,
        title: s.title,
        artist: s.artist,
        thumbnailUrl: s.thumbnailUrl || 'https://archive.org/services/img/internet_archive_logo',
        duration: s.duration,
      }));
      metadataCache.set(cacheKey, result);
      return res.json(result);
    }

    // NLP Parsing for "Song by Artist"
    let songQuery = query;
    let targetArtist = null;
    const byMatch = query.match(/(.+?)\s+by\s+(.+)/i);
    if (byMatch) {
      songQuery = byMatch[1].trim();
      targetArtist = byMatch[2].trim();
    }

    const regex = new RegExp(songQuery, 'i');
    let creatorQuery = { $or: [{ title: regex }, { artist: regex }] };
    if (targetArtist) {
      const artistRegex = new RegExp(targetArtist, 'i');
      creatorQuery = { title: regex, artist: artistRegex };
    }

    const creatorMatches = await CreatorSong.find(creatorQuery).limit(10).lean();

    const formattedCreatorMatches = creatorMatches.map(s => ({
      videoId: s.videoId,
      title: s.title,
      artist: s.artist,
      thumbnailUrl: s.thumbnailUrl || 'https://archive.org/services/img/internet_archive_logo',
      duration: s.duration,
    }));

    let songs = [];
    try {
      songs = await searchSaavn(songQuery, 20, targetArtist);
    } catch (saavnError) {}
    
    const finalResult = [...formattedCreatorMatches, ...songs];
    metadataCache.set(cacheKey, finalResult);
    res.json(finalResult);
  } catch (error) {
    res.status(500).json({ error: 'Failed to search for songs.' });
  }
});

// 2. Stream URL
router.get('/stream/:songId', async (req, res) => {
  try {
    const { songId } = req.params;
    if (!songId) return res.status(400).json({ error: 'Missing songId' });
    
    const cachedUrl = streamCache.get(songId);
    if (cachedUrl) return res.json({ streamUrl: cachedUrl, duration: 0 });

    let streamUrl;
    if (songId.startsWith('creator_')) {
      const creatorSong = await CreatorSong.findOne({ videoId: songId });
      if (creatorSong) streamUrl = creatorSong.streamUrl;
    } else {
      streamUrl = await getStreamUrl(songId);
    }

    if (streamUrl) {
      streamCache.set(songId, streamUrl);
      res.json({ streamUrl, duration: 0 });
    } else {
      res.status(404).json({ error: 'Stream not found' });
    }
  } catch (error) {
    res.status(500).json({ error: 'Failed to generate stream URL' });
  }
});

// NEW: 2.5 Chunked Stream Proxy (Insta-Play)
router.get('/play/:songId', async (req, res) => {
  try {
    const { songId } = req.params;
    let streamUrl = streamCache.get(songId);

    if (!streamUrl) {
      if (songId.startsWith('creator_')) {
        const creatorSong = await CreatorSong.findOne({ videoId: songId });
        if (creatorSong) streamUrl = creatorSong.streamUrl;
      } else {
        streamUrl = await getStreamUrl(songId);
      }
      if (streamUrl) streamCache.set(songId, streamUrl);
    }

    if (!streamUrl) {
      return res.status(404).send('Stream not found');
    }

    const client = streamUrl.startsWith('https') ? https : http;
    const options = { headers: {} };
    if (req.headers.range) {
      options.headers['Range'] = req.headers.range;
    }

    client.get(streamUrl, options, (proxyRes) => {
      res.writeHead(proxyRes.statusCode, proxyRes.headers);
      proxyRes.pipe(res);
    }).on('error', (err) => {
      res.status(500).send('Proxy stream error');
    });

  } catch (error) {
    res.status(500).send('Failed to play stream');
  }
});

// 3. Album
router.get('/album/:id', async (req, res) => {
  try {
    const playlistId = req.params.id;
    const cacheKey = `album_${playlistId}`;
    const cachedResult = metadataCache.get(cacheKey);
    if (cachedResult) return res.json(cachedResult);

    const tracks = await getPlaylistTracks(playlistId, 30);
    const result = {
      id: playlistId,
      title: 'Album',
      artistName: 'Unknown',
      year: '',
      thumbnailUrl: tracks.length > 0 ? tracks[0].thumbnailUrl : '',
      totalDuration: 'Unknown',
      tracks: tracks
    };
    metadataCache.set(cacheKey, result);
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: 'Failed to get album' });
  }
});

// 4. Artist
router.get('/artist/:id', async (req, res) => {
  try {
    const artistId = req.params.id;
    const cacheKey = `artist_${artistId}`;
    const cachedResult = metadataCache.get(cacheKey);
    if (cachedResult) return res.json(cachedResult);

    const tracks = await searchSaavn(`${artistId} top songs`, 50);
    
    let normalized = normalizeTracks(tracks);
    normalized = normalized.filter(t => !t.isRemix);
    normalized = deduplicateTracks(normalized);

    const result = {
      id: artistId,
      name: artistId,
      imageUrl: normalized.length > 0 ? normalized[0].thumbnailUrl : '',
      followerCount: 'Unknown',
      isVerified: false,
      biography: '',
      topSongs: normalized,
      albums: [],
      singles: [],
      relatedArtists: []
    };
    metadataCache.set(cacheKey, result);
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: 'Failed to get artist' });
  }
});

// 4.5 Artist Songs (Paginated)
router.get('/artist/:id/songs', async (req, res) => {
  try {
    const artistId = req.params.id;
    const page = parseInt(req.query.page) || 1;
    const cacheKey = `artist_${artistId}_songs_page_${page}`;
    
    const cachedResult = metadataCache.get(cacheKey);
    if (cachedResult) return res.json(cachedResult);

    let tracks = await searchSaavnPage(`${artistId} top songs`, page);
    
    let normalized = normalizeTracks(tracks);
    normalized = normalized.filter(t => !t.isRemix);
    normalized = deduplicateTracks(normalized);
    
    metadataCache.set(cacheKey, normalized);
    res.json(normalized);
  } catch (error) {
    res.status(500).json({ error: 'Failed to get artist songs' });
  }
});

// 5. Watch Next (Radio)
router.get('/watch/:id', async (req, res) => {
  try {
    const songId = req.params.id;
    const cacheKey = `watch_${songId}`;
    const cachedResult = metadataCache.get(cacheKey);
    if (cachedResult) return res.json(cachedResult);

    const tracks = await getRelatedTracks(songId, 20);
    metadataCache.set(cacheKey, tracks);
    res.json(tracks);
  } catch (error) {
    res.status(500).json({ error: 'Failed to get related tracks' });
  }
});

// 6. Lyrics
router.get('/lyrics/:id', async (req, res) => {
  try {
    const songId = req.params.id;
    const cacheKey = `lyrics_${songId}`;
    const cachedResult = metadataCache.get(cacheKey);
    if (cachedResult) return res.json(cachedResult);

    const lyrics = await getLyrics(songId);
    if (!lyrics) return res.status(404).json({ error: 'Lyrics not found' });
    
    metadataCache.set(cacheKey, lyrics);
    res.json(lyrics);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch lyrics' });
  }
});

module.exports = router;
