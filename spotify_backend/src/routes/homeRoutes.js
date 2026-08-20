const express = require('express');
const { searchSaavn } = require('../utils/saavn');

const router = express.Router();

const CURATED_PLAYLISTS = [
  { id: 'top50india',    title: 'Top 50 India',           query: 'Top Hindi Songs 2024',    description: 'The most played tracks in India right now.', thumbnailUrl: 'https://i.ytimg.com/vi/O5gwxm3NxFU/hq720.jpg' },
  { id: 'bollywoodhits', title: 'Bollywood Chartbusters', query: 'Bollywood Hits 2024',     description: 'Biggest Bollywood hits of the season.', thumbnailUrl: 'https://i.ytimg.com/vi/NX5yDs_TLqA/hq720.jpg' },
  { id: 'arijitsingh',   title: 'Best of Arijit Singh',   query: 'Arijit Singh best songs', description: 'Soulful melodies by Arijit Singh.', thumbnailUrl: 'https://i.ytimg.com/vi/nyuo9-OjNNg/hq720.jpg' },
  { id: 'punjabihits',   title: 'Trending Punjabi Hits',  query: 'Punjabi Hits 2024',       description: 'High energy Punjabi bangers.', thumbnailUrl: 'https://i.ytimg.com/vi/1zNlsL1E10w/hq720.jpg' },
  { id: 'globaltop50',   title: 'Global Top 50',          query: 'Top English Songs 2024',  description: 'The most played tracks in the world right now.', thumbnailUrl: 'https://i.ytimg.com/vi/kffacxfA7G4/hq720.jpg' },
];

// Home: return playlist cards instantly
router.get('/', (req, res) => {
  res.json(CURATED_PLAYLISTS);
});

// Playlist: return songs for a curated playlist
router.get('/playlist/:id', async (req, res) => {
  try {
    const playlist = CURATED_PLAYLISTS.find(p => p.id === req.params.id);
    if (!playlist) return res.status(404).json({ error: 'Playlist not found' });

    const songs = await searchSaavn(playlist.query, 20);
    const firstThumb = songs.length > 0 ? songs[0].thumbnailUrl : '';

    res.json({
      id: playlist.id,
      title: playlist.title,
      description: playlist.description,
      thumbnailUrl: firstThumb,
      songs: songs,
    });
  } catch (error) {
    console.error('Playlist error:', error.message);
    res.status(500).json({ error: 'Failed to fetch playlist' });
  }
});

// Charts
router.get('/charts', async (req, res) => {
  try {
    const songs = await searchSaavn('Top global hits 2024', 20);
    res.json(songs);
  } catch (error) {
    console.error('Charts error:', error.message);
    res.status(500).json({ error: 'Failed to fetch charts' });
  }
});

// Moods
router.get('/moods', async (req, res) => {
  // Return the fallback mood categories from the app directly, or empty to let app handle it.
  // The app will use fallbacks if it fails.
  res.status(500).json({ error: 'Use fallback moods' }); 
});

// Mood Playlist
router.get('/mood/:id', async (req, res) => {
  try {
    const songs = await searchSaavn(`${req.params.id} music`, 20);
    res.json({
      id: req.params.id,
      title: req.params.id,
      description: 'Mood playlist',
      thumbnailUrl: songs.length > 0 ? songs[0].thumbnailUrl : '',
      songs: songs,
    });
  } catch (error) {
    console.error('Mood playlist error:', error.message);
    res.status(500).json({ error: 'Failed to fetch mood' });
  }
});

module.exports = router;
