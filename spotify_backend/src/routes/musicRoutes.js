const express = require('express');
const { searchYouTube, getStreamUrl, getPlaylistTracks, getRelatedTracks, pipeAudioStream } = require('../utils/ytdlp');

const router = express.Router();

// 1. Search (using yt-dlp)
router.get('/search', async (req, res) => {
  try {
    const query = req.query.q;
    if (!query) return res.status(400).json({ error: 'Missing search query' });

    const songs = await searchYouTube(query, 20);
    res.json(songs);
  } catch (error) {
    console.error('Search error:', error.message);
    res.status(500).json({ error: 'Failed to search for songs.' });
  }
});

// 2. Stream URL (returns the custom backend proxy URL)
router.get('/stream/:songId', async (req, res) => {
  try {
    const { songId } = req.params;
    if (!songId) return res.status(400).json({ error: 'Missing songId' });

    // We don't fetch the Googlevideo URL here anymore. We just tell the mobile app 
    // to stream directly from our new /play endpoint on this exact server.
    const proxyUrl = `${req.protocol}://${req.get('host')}/api/music/play/${songId}`;

    res.json({
      streamUrl: proxyUrl,
      duration: 0, 
    });
  } catch (error) {
    console.error('Stream error:', error.message);
    res.status(500).json({ error: 'Failed to generate stream URL' });
  }
});

// 2.5 Play (Pipes audio directly to the client)
router.get('/play/:songId', (req, res) => {
  const { songId } = req.params;
  if (!songId) return res.status(400).send('Missing songId');
  
  // Hand off the response object to the yt-dlp piping function
  pipeAudioStream(songId, res);
});

// 3. Album
router.get('/album/:id', async (req, res) => {
  try {
    // If it's a YouTube playlist ID, fetch it directly
    // If not, we just search YouTube for it
    const playlistId = req.params.id;
    let tracks = [];
    if (playlistId.startsWith('PL') || playlistId.startsWith('OL') || playlistId.startsWith('RD')) {
      tracks = await getPlaylistTracks(`https://www.youtube.com/playlist?list=${playlistId}`, 30);
    } else {
      tracks = await searchYouTube(`${playlistId} album`, 20);
    }
    
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
    // We just return a fallback artist with top songs from YouTube search
    const tracks = await searchYouTube(`${req.params.id} songs`, 10);
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
  // YT-dlp doesn't easily extract lyrics, so we return null/404 to let the app handle it gracefully
  res.status(404).json({ error: 'Lyrics not supported in YT pipeline yet' });
});

module.exports = router;
