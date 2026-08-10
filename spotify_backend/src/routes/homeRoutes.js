const express = require('express');
const saavn = require('saavnapi').default;

const router = express.Router();

// Define Curated Playlists
const CURATED_PLAYLISTS = [
  { id: 'top50india',      title: 'Top 50 India',              query: 'Top Hindi Songs 2024',    description: 'The most played tracks in India right now.' },
  { id: 'bollywoodhits',   title: 'Bollywood Chartbusters',    query: 'Bollywood Hits 2024',     description: 'Biggest Bollywood hits of the season.' },
  { id: 'arijitsingh',     title: 'Best of Arijit Singh',      query: 'Arijit Singh best songs', description: 'Soulful melodies by Arijit Singh.' },
  { id: 'punjabihits',     title: 'Trending Punjabi Hits',     query: 'Punjabi Hits 2024',       description: 'High energy Punjabi bangers.' },
  { id: 'globaltop50',     title: 'Global Top 50',             query: 'Top English Songs 2024',  description: 'The most played tracks in the world right now.' },
];

// Helper: map a search result to our Track format
function searchResultToTrack(song) {
  const thumbnail =
    (song.image || []).find(img => img.quality === '500x500')?.url ||
    (song.image || []).slice(-1)[0]?.url ||
    '';
  return {
    videoId: song.id,
    title: song.title || song.name || 'Unknown',
    artist: song.primaryArtists || 'Unknown Artist',
    thumbnailUrl: thumbnail,
    duration: null,
  };
}

// Returns the lightweight metadata for the home screen (just playlist cards)
router.get('/', async (req, res) => {
  try {
    const promises = CURATED_PLAYLISTS.map(async (p) => {
      let dynamicThumbnail = '';
      try {
        // searchAll returns { songs, albums, artists, playlists } — no .data wrapper
        const response = await saavn.search.searchAll({ query: p.query });
        const songs = response?.songs?.results || [];
        if (songs.length > 0) {
          const song = songs[0];
          dynamicThumbnail =
            (song.image || []).find(img => img.quality === '500x500')?.url ||
            (song.image || []).slice(-1)[0]?.url ||
            '';
        }
      } catch (err) {
        console.error(`Failed to fetch thumbnail for ${p.id}:`, err.message);
      }
      return {
        id: p.id,
        title: p.title,
        thumbnailUrl: dynamicThumbnail,
        description: p.description,
      };
    });

    const playlists = await Promise.all(promises);
    res.json(playlists);
  } catch (error) {
    console.error('Error in home route:', error);
    res.status(500).json({ error: 'Failed to fetch home metadata' });
  }
});

// Returns the actual songs for a specific curated playlist
router.get('/playlist/:id', async (req, res) => {
  try {
    const playlist = CURATED_PLAYLISTS.find(p => p.id === req.params.id);
    if (!playlist) {
      return res.status(404).json({ error: 'Playlist not found' });
    }

    // searchAll returns { songs, albums, artists, playlists } — no .data wrapper
    const response = await saavn.search.searchAll({ query: playlist.query });
    const songs = response?.songs?.results || [];
    const results = songs.map(searchResultToTrack);

    const firstThumbnail = results.length > 0 ? results[0].thumbnailUrl : '';

    res.json({
      id: playlist.id,
      title: playlist.title,
      description: playlist.description,
      thumbnailUrl: firstThumbnail,
      songs: results,
    });
  } catch (error) {
    console.error('Error fetching curated playlist:', error);
    res.status(500).json({ error: 'Failed to fetch curated playlist' });
  }
});

module.exports = router;
