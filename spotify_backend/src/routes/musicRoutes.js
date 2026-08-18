const express = require('express');
const { searchSaavn, getStreamUrl, getPlaylistTracks, getRelatedTracks } = require('../utils/saavn');

const router = express.Router();

// 1. Search (using JioSaavn)
router.get('/search', async (req, res) => {
  try {
    const query = req.query.q;
    if (!query) return res.status(400).json({ error: 'Missing search query' });

    const songs = await searchSaavn(query, 20);
    res.json(songs);
  } catch (error) {
    console.error('Search error:', error.message);
    res.status(500).json({ error: 'Failed to search for songs.' });
  }
});

// 2. Stream URL (returns the direct JioSaavn URL)
router.get('/stream/:songId', async (req, res) => {
  try {
    const { songId } = req.params;
    if (!songId) return res.status(400).json({ error: 'Missing songId' });

    // Because JioSaavn provides a fast, direct .m4a URL, we don't need to proxy the audio stream 
    // through your phone! This saves 100% of the server bandwidth.
    const directUrl = await getStreamUrl(songId);

    res.json({
      streamUrl: directUrl,
      duration: 0, 
    });
  } catch (error) {
    console.error('Stream error:', error.message);
    res.status(500).json({ error: 'Failed to generate stream URL' });
  }
});

// 2.5 Play Endpoint (DEPRECATED - No longer needed because we return direct URL)
router.get('/play/:songId', (req, res) => {
  res.status(410).send('Play endpoint deprecated. Use /stream to get direct URL.');
});

// 3. Album
router.get('/album/:id', async (req, res) => {
  try {
    const playlistId = req.params.id;
    const tracks = await getPlaylistTracks(playlistId, 30);
    
    res.json({
      id: playlistId,
      title: 'Album',
      artistName: 'Unknown',
      year: '',
      thumbnailUrl: tracks.length > 0 ? tracks[0].thumbnailUrl : '',
      totalDuration: 'Unknown',
      tracks: tracks
    });
  } catch (error) {
    console.error('Album error:', error.message);
    res.status(500).json({ error: 'Failed to get album' });
  }
});

// 4. Artist
router.get('/artist/:id', async (req, res) => {
  try {
    const tracks = await searchSaavn(`${req.params.id} top songs`, 10);
    res.json({
      id: req.params.id,
      name: req.params.id,
      imageUrl: tracks.length > 0 ? tracks[0].thumbnailUrl : '',
      followerCount: 'Unknown',
      isVerified: false,
      biography: '',
      topSongs: tracks,
      albums: [],
      singles: [],
      relatedArtists: []
    });
  } catch (error) {
    console.error('Artist error:', error.message);
    res.status(500).json({ error: 'Failed to get artist' });
  }
});

// 5. Watch Next (Radio)
router.get('/watch/:id', async (req, res) => {
  try {
    const tracks = await getRelatedTracks(req.params.id, 20);
    res.json(tracks);
  } catch (error) {
    console.error('Watch next error:', error.message);
    res.status(500).json({ error: 'Failed to get related tracks' });
  }
});

// 6. Lyrics
router.get('/lyrics/:id', async (req, res) => {
  res.status(404).json({ error: 'Lyrics not supported in this pipeline yet' });
});

module.exports = router;
