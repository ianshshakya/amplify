const express = require('express');

const router = express.Router();

const CURATED_PLAYLISTS = [
  { id: 'top50india',    title: 'Top 50 India',           query: 'Top Hindi Songs 2024',    description: 'The most played tracks in India right now.' },
  { id: 'bollywoodhits', title: 'Bollywood Chartbusters', query: 'Bollywood Hits 2024',     description: 'Biggest Bollywood hits of the season.' },
  { id: 'arijitsingh',   title: 'Best of Arijit Singh',   query: 'Arijit Singh best songs', description: 'Soulful melodies by Arijit Singh.' },
  { id: 'punjabihits',   title: 'Trending Punjabi Hits',  query: 'Punjabi Hits 2024',       description: 'High energy Punjabi bangers.' },
  { id: 'globaltop50',   title: 'Global Top 50',          query: 'Top English Songs 2024',  description: 'The most played tracks in the world right now.' },
];

const SAAVN_API = 'https://www.jiosaavn.com/api.php';
const SAAVN_HEADERS = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36',
  'Referer': 'https://www.jiosaavn.com/',
  'Accept': 'application/json',
};

async function saavnSearch(query, limit = 10) {
  const url = `${SAAVN_API}?__call=search.getResults&_format=json&_marker=0&api_version=4&ctx=web6dot0&q=${encodeURIComponent(query)}&n=${limit}&p=1`;
  const res = await fetch(url, { headers: SAAVN_HEADERS });
  const text = await res.text();
  const json = text.startsWith('/**/') ? text.slice(4) : text;
  const data = JSON.parse(json);
  return data.results || [];
}

function mapSong(song) {
  const image = (song.image || '').replace('150x150', '500x500');
  const primaryArtists = song.more_info?.artistMap?.primary_artists || [];
  const artist = primaryArtists.map(a => a.name).join(', ') || song.subtitle?.split(' - ')[0] || 'Unknown Artist';
  return {
    videoId: song.id,
    title: song.title || 'Unknown',
    artist,
    thumbnailUrl: image,
    duration: song.more_info?.duration ? parseInt(song.more_info.duration, 10) : null,
  };
}

// Home: return playlist cards with dynamic thumbnails
router.get('/', async (req, res) => {
  try {
    const promises = CURATED_PLAYLISTS.map(async (p) => {
      let thumbnailUrl = '';
      try {
        const songs = await saavnSearch(p.query, 1);
        if (songs.length > 0) {
          thumbnailUrl = (songs[0].image || '').replace('150x150', '500x500');
        }
      } catch (err) {
        console.error(`Thumbnail fetch failed for ${p.id}:`, err.message);
      }
      return { id: p.id, title: p.title, thumbnailUrl, description: p.description };
    });

    res.json(await Promise.all(promises));
  } catch (error) {
    console.error('Home error:', error.message);
    res.status(500).json({ error: 'Failed to fetch home data' });
  }
});

// Playlist: return songs for a curated playlist
router.get('/playlist/:id', async (req, res) => {
  try {
    const playlist = CURATED_PLAYLISTS.find(p => p.id === req.params.id);
    if (!playlist) return res.status(404).json({ error: 'Playlist not found' });

    const songs = await saavnSearch(playlist.query, 20);
    const results = songs.map(mapSong);
    const firstThumb = results.length > 0 ? results[0].thumbnailUrl : '';

    res.json({
      id: playlist.id,
      title: playlist.title,
      description: playlist.description,
      thumbnailUrl: firstThumb,
      songs: results,
    });
  } catch (error) {
    console.error('Playlist error:', error.message);
    res.status(500).json({ error: 'Failed to fetch playlist' });
  }
});

module.exports = router;
