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

const { getSaavnStreamByMetadata } = require('../utils/saavn');

// 2. Stream URL (Hybrid: Takes YouTube metadata and returns JioSaavn Audio)
router.get('/stream/:songId', async (req, res) => {
  try {
    const { songId } = req.params;
    const { title, artist } = req.query;
    
    if (!songId) return res.status(400).json({ error: 'Missing songId' });
    
    // If the frontend didn't pass title and artist (e.g. old app version), fallback to a basic search
    const searchTitle = title || 'Unknown Title';
    const searchArtist = artist || '';

    console.log(`[Hybrid Engine] Fetching audio for: ${searchTitle} by ${searchArtist}`);
    
    const streamUrl = await getSaavnStreamByMetadata(searchTitle, searchArtist);

    res.json({
      streamUrl: streamUrl,
      duration: 0, 
    });
  } catch (error) {
    console.error('[Hybrid Engine] Stream error:', error.message);
    res.status(500).json({ error: 'Failed to generate stream URL' });
  }
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
