const express = require('express');
const saavn = require('saavnapi').default;

const router = express.Router();

// ─── JioSaavn direct API helpers ─────────────────────────────────────────────
// The saavnapi npm package has a bug in searchAll (passes [object Object] as query).
// We call JioSaavn's internal API directly for search, and use saavnapi for stream URLs
// since it correctly handles the DES decryption of encrypted_media_url.

const SAAVN_API = 'https://www.jiosaavn.com/api.php';
const SAAVN_HEADERS = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36',
  'Referer': 'https://www.jiosaavn.com/',
  'Accept': 'application/json',
};

async function saavnSearch(query, limit = 20) {
  const url = `${SAAVN_API}?__call=search.getResults&_format=json&_marker=0&api_version=4&ctx=web6dot0&q=${encodeURIComponent(query)}&n=${limit}&p=1`;
  const res = await fetch(url, { headers: SAAVN_HEADERS });
  const text = await res.text();
  // JioSaavn occasionally wraps JSON in /**/
  const json = text.startsWith('/**/') ? text.slice(4) : text;
  const data = JSON.parse(json);
  return data.results || [];
}

function mapSearchResult(song) {
  // image comes as "150x150" URL — upgrade to 500x500
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

// ─── Routes ──────────────────────────────────────────────────────────────────

// 1. Search
router.get('/search', async (req, res) => {
  try {
    const query = req.query.q;
    if (!query) return res.status(400).json({ error: 'Missing search query' });

    const songs = await saavnSearch(query);
    res.json(songs.map(mapSearchResult));
  } catch (error) {
    console.error('Search error:', error.message);
    res.status(500).json({ error: 'Failed to search for songs.' });
  }
});

// 2. Stream — use saavnapi which correctly decrypts JioSaavn media URLs
router.get('/stream/:songId', async (req, res) => {
  try {
    const { songId } = req.params;
    if (!songId) return res.status(400).json({ error: 'Missing songId' });

    const songArray = await saavn.songs.getSongByIds({ songIds: [songId] });
    const song = Array.isArray(songArray) ? songArray[0] : null;

    if (!song || !song.downloadUrl || song.downloadUrl.length === 0) {
      return res.status(404).json({ error: 'Song not found or no stream available' });
    }

    const urlList = song.downloadUrl;
    const bestUrl =
      urlList.find(u => u.quality === '320kbps')?.url ||
      urlList.find(u => u.quality === '160kbps')?.url ||
      urlList.find(u => u.quality === '96kbps')?.url ||
      urlList[urlList.length - 1]?.url;

    res.json({
      streamUrl: bestUrl,
      duration: typeof song.duration === 'number' ? song.duration : 0,
    });
  } catch (error) {
    console.error('Stream error:', error.message);
    res.status(500).json({ error: 'Failed to get stream URL' });
  }
});

module.exports = router;
