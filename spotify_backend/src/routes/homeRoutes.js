const express = require('express');
const YTMusic = require('ytmusic-api');

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
        
      const artist = song.artist?.name || 'Unknown Artist';

      return {
        videoId: song.videoId,
        title: song.name,
        artist: artist,
        thumbnailUrl: bestThumbnail,
        duration: song.duration,
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

router.get('/charts', async (req, res) => {
  try {
    const cached = cacheGet('charts');
    if (cached) return res.json(cached);

    await initYTMusic();
    const results = await ytmusic.searchSongs('Top 50 songs trending India');
    const tracks = results.slice(0, 50).map(song => {
      const thumbnails = song.thumbnails || [];
      const bestThumbnail = thumbnails.length > 0 
        ? thumbnails[thumbnails.length - 1].url 
        : '';
      return {
        videoId: song.videoId,
        title: song.name,
        artist: song.artist?.name || 'Unknown Artist',
        thumbnailUrl: bestThumbnail,
        duration: song.duration
      };
    });

    cacheSet('charts', tracks, 600);
    res.json(tracks);
  } catch (error) {
    console.error('Error fetching charts:', error);
    res.status(500).json({ error: 'Failed to fetch charts' });
  }
});

router.get('/moods', (req, res) => {
  res.json([
    {
      "title": "Moods & Genres",
      "playlists": [
        {"title": "Happy Hits", "playlistId": "top50india", "thumbnailUrl": "", "color1": "FFB300", "color2": "FF6D00"},
        {"title": "Workout", "playlistId": "punjabihits", "thumbnailUrl": "", "color1": "B71C1C", "color2": "EF5350"},
        {"title": "Chill Vibes", "playlistId": "bollywoodhits", "thumbnailUrl": "", "color1": "1565C0", "color2": "42A5F5"},
        {"title": "Focus & Study", "playlistId": "globaltop50", "thumbnailUrl": "", "color1": "2E7D32", "color2": "66BB6A"},
        {"title": "Bollywood", "playlistId": "bollywoodhits", "thumbnailUrl": "", "color1": "6A1B9A", "color2": "AB47BC"},
        {"title": "Trending Now", "playlistId": "top50india", "thumbnailUrl": "", "color1": "00838F", "color2": "26C6DA"},
        {"title": "Punjabi Beats", "playlistId": "punjabihits", "thumbnailUrl": "", "color1": "E65100", "color2": "FF8A65"},
        {"title": "Romantic", "playlistId": "arijitsingh", "thumbnailUrl": "", "color1": "880E4F", "color2": "E91E63"}
      ]
    }
  ]);
});

router.get('/mood/:playlistId', async (req, res) => {
  try {
    const playlist = CURATED_PLAYLISTS.find(p => p.id === req.params.playlistId);
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
        
      const artist = song.artist?.name || 'Unknown Artist';

      return {
        videoId: song.videoId,
        title: song.name,
        artist: artist,
        thumbnailUrl: bestThumbnail,
        duration: song.duration,
      };
    });

    const firstThumbnail = results.length > 0 ? results[0].thumbnailUrl : '';

    res.json({
      ...playlist,
      thumbnailUrl: firstThumbnail,
      songs: results
    });
  } catch (error) {
    console.error('Error fetching mood playlist:', error);
    res.status(500).json({ error: 'Failed to fetch mood playlist' });
  }
});

module.exports = router;
