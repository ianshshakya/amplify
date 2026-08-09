const express = require('express');
const YTMusic = require('ytmusic-api');

const router = express.Router();
const ytmusic = new YTMusic();
let ytmusicInitialized = false;

// Initialize YTMusic
async function initYTMusic() {
  if (!ytmusicInitialized) {
    await ytmusic.initialize();
    ytmusicInitialized = true;
  }
}

// Define Curated Playlists (We will search for these on YT Music)
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
    await initYTMusic();
    const promises = CURATED_PLAYLISTS.map(async (p) => {
      let dynamicThumbnail = '';
      try {
        // Fetch one song just to get a good cover art for the category
        const response = await ytmusic.searchSongs(p.query);
        if (response && response.length > 0) {
          const thumbnails = response[0].thumbnails || [];
          dynamicThumbnail = thumbnails.length > 0 ? thumbnails[thumbnails.length - 1].url : '';
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

    await initYTMusic();
    const searchResults = await ytmusic.searchSongs(playlist.query);

    const results = searchResults.map(song => {
      const thumbnails = song.thumbnails || [];
      const bestThumbnail = thumbnails.length > 0 
        ? thumbnails[thumbnails.length - 1].url 
        : '';
        
      const artist = song.artists?.map(a => a.name).join(', ') || 'Unknown Artist';

      return {
        videoId: song.videoId,
        title: song.name,
        artist: artist,
        thumbnailUrl: bestThumbnail,
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
