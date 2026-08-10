const express = require('express');
const saavn = require('saavnapi').default;

const router = express.Router();

// Define Curated Playlists (We will search for these on Saavn)
const CURATED_PLAYLISTS = [
  { 
    id: 'top50india', 
    title: 'Top 50 India', 
    query: 'Top 50 India',
    description: 'The most played tracks in India right now.'
  },
  { 
    id: 'bollywoodhits', 
    title: 'Bollywood Chartbusters', 
    query: 'Bollywood Hits',
    description: 'Biggest Bollywood hits of the season.'
  },
  { 
    id: 'arijitsingh', 
    title: 'Best of Arijit Singh', 
    query: 'Arijit Singh',
    description: 'Soulful melodies by the one and only Arijit Singh.'
  },
  { 
    id: 'punjabihits', 
    title: 'Trending Punjabi Hits', 
    query: 'Punjabi Hits',
    description: 'High energy Punjabi bangers.'
  },
  {
    id: 'globaltop50',
    title: 'Global Top 50',
    query: 'Global Top 50 Songs',
    description: 'The most played tracks in the world right now.'
  }
];

// Returns the lightweight metadata for the home screen
router.get('/', async (req, res) => {
  try {
    const promises = CURATED_PLAYLISTS.map(async (p) => {
      let dynamicThumbnail = '';
      try {
        const response = await saavn.search.searchAll({ query: p.query });
        const songs = response.data?.songs?.results || [];
        if (songs.length > 0) {
          const song = songs[0];
          dynamicThumbnail = song.image.find(img => img.quality === '500x500')?.url 
                          || song.image[song.image.length - 1]?.url;
        }
      } catch (err) {
        console.error(`Failed to fetch thumbnail for ${p.id}:`, err);
      }

      return {
        id: p.id,
        title: p.title,
        thumbnailUrl: dynamicThumbnail,
        description: p.description
      };
    });

    const playlistsWithDynamicImages = await Promise.all(promises);
    res.json(playlistsWithDynamicImages);
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

    const response = await saavn.search.searchAll({ query: playlist.query });
    const songs = response.data?.songs?.results || [];

    const results = songs.map(song => {
      const thumbnail = song.image.find(img => img.quality === '500x500')?.url 
                     || song.image[song.image.length - 1]?.url;
                     
      return {
        videoId: song.id,
        title: song.title,
        artist: song.primaryArtists || 'Unknown Artist',
        thumbnailUrl: thumbnail,
        duration: null,
      };
    });
    
    const firstThumbnail = results.length > 0 ? results[0].thumbnailUrl : '';

    res.json({
      ...playlist,
      thumbnailUrl: firstThumbnail,
      songs: results
    });
  } catch (error) {
    console.error('Error fetching curated playlist:', error);
    res.status(500).json({ error: 'Failed to fetch curated playlist' });
  }
});

module.exports = router;
