const express = require('express');
const saavn = require('saavnapi').default;

const router = express.Router();

// Helper: map a full song object (from getSongByIds) to our Track format
function songToTrack(song) {
  const thumbnail =
    (song.image || []).find(img => img.quality === '500x500')?.url ||
    (song.image || []).slice(-1)[0]?.url ||
    '';

  const artist =
    (song.artists?.primary || []).map(a => a.name).join(', ') ||
    song.primaryArtists ||
    'Unknown Artist';

  return {
    videoId: song.id,
    title: song.name || song.title || 'Unknown',
    artist,
    thumbnailUrl: thumbnail,
    duration: typeof song.duration === 'number' ? song.duration : null,
  };
}

// Helper: map a search result (from searchAll.songs.results) to our Track format
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

// 1. Search using JioSaavn
router.get('/search', async (req, res) => {
  try {
    const query = req.query.q;
    if (!query) {
      return res.status(400).json({ error: 'Missing search query' });
    }

    // searchAll returns: { topQuery, songs, albums, artists, playlists }
    // (no .data wrapper — the object IS the data)
    const response = await saavn.search.searchAll({ query });
    const songs = response?.songs?.results || [];

    const results = songs.map(searchResultToTrack);
    res.json(results);
  } catch (error) {
    console.error('Search error:', error);
    res.status(500).json({ error: 'Failed to search for songs.' });
  }
});

// 2. Stream using JioSaavn
router.get('/stream/:songId', async (req, res) => {
  try {
    const { songId } = req.params;
    if (!songId) {
      return res.status(400).json({ error: 'Missing songId' });
    }

    // getSongByIds returns an array directly (no .data wrapper)
    const songArray = await saavn.songs.getSongByIds({ songIds: [songId] });
    const song = Array.isArray(songArray) ? songArray[0] : null;

    if (!song || !song.downloadUrl || song.downloadUrl.length === 0) {
      return res.status(404).json({ error: 'Song not found or no download URL available' });
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
    console.error('Stream error:', error);
    res.status(500).json({ error: 'Failed to get stream URL' });
  }
});

module.exports = router;
