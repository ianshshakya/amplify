const express = require('express');
const saavn = require('saavnapi').default;

const router = express.Router();

const CURATED_PLAYLISTS = [
  { 
    id: 'top50india', 
    title: 'Top 50 India', 
    query: 'Top 50 India',
    thumbnailUrl: 'https://c.saavncdn.com/327/Top-50-Musica-de-Meditacion-y-Relajacion-50-Musicas-Relajantes-para-Descansar-Dormir-y-So-ar-English-2017-500x500.jpg',
    description: 'The most played tracks in India right now.'
  },
  { 
    id: 'bollywoodhits', 
    title: 'Bollywood Chartbusters', 
    query: 'Bollywood Hits',
    thumbnailUrl: 'https://c.saavncdn.com/editorial/BollywoodChartbusters_20231011053154_500x500.jpg',
    description: 'Biggest Bollywood hits of the season.'
  },
  { 
    id: 'arijitsingh', 
    title: 'Best of Arijit Singh', 
    query: 'Arijit Singh',
    thumbnailUrl: 'https://c.saavncdn.com/editorial/ArijitSingh_20231011053154_500x500.jpg',
    description: 'Soulful melodies by the one and only Arijit Singh.'
  },
  { 
    id: 'punjabihits', 
    title: 'Trending Punjabi Hits', 
    query: 'Punjabi Hits',
    thumbnailUrl: 'https://c.saavncdn.com/editorial/PunjabiChartbusters_20231011053154_500x500.jpg',
    description: 'High energy Punjabi bangers.'
  }
];

// Returns the lightweight metadata for the home screen
router.get('/', async (req, res) => {
  try {
    const promises = CURATED_PLAYLISTS.map(async (p) => {
      let dynamicThumbnail = p.thumbnailUrl;
      try {
        const response = await saavn.search.searchSongs({ query: p.query, page: 1, limit: 1 });
        if (response.results && response.results.length > 0) {
          const song = response.results[0];
          dynamicThumbnail = song.image?.find(img => img.quality === '500x500')?.url 
                          || (song.image && song.image.length > 0 ? song.image[song.image.length - 1].url : p.thumbnailUrl);
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

    const response = await saavn.search.searchSongs({ query: playlist.query, page: 1, limit: 30 });
    const songs = response.results || [];

    const results = songs.map(song => {
      const thumbnail = song.image?.find(img => img.quality === '500x500')?.url 
                     || (song.image && song.image.length > 0 ? song.image[song.image.length - 1].url : '');
      const artist = song.artists?.primary?.map(a => a.name).join(', ') || 'Unknown Artist';

      return {
        videoId: song.id,
        title: song.name || song.title,
        artist: artist,
        thumbnailUrl: thumbnail,
        duration: song.duration,
      };
    });

    res.json({
      ...playlist,
      songs: results
    });
  } catch (error) {
    console.error('Error fetching curated playlist:', error);
    res.status(500).json({ error: 'Failed to fetch curated playlist' });
  }
});

module.exports = router;
