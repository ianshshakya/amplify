const express = require('express');
const saavn = require('saavnapi').default;

const router = express.Router();

// 1. Search using JioSaavn
router.get('/search', async (req, res) => {
  try {
    const query = req.query.q;
    if (!query) {
      return res.status(400).json({ error: 'Missing search query' });
    }

    const response = await saavn.search.searchAll({ query });
    const songs = response.data?.songs?.results || [];

    const results = songs.map(song => {
      // Find highest quality image
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

    const response = await saavn.songs.getSongByIds({ songIds: [songId] });
    const song = response.data[0];

    if (!song || !song.downloadUrl) {
      return res.status(404).json({ error: 'Song not found or no download URL available' });
    }

    // Find the 320kbps quality, fallback to 160kbps, then whatever is available
    const urlList = song.downloadUrl;
    const bestUrl = urlList.find(u => u.quality === '320kbps')?.url 
                 || urlList.find(u => u.quality === '160kbps')?.url
                 || urlList[urlList.length - 1]?.url;

    res.json({ 
      streamUrl: bestUrl, 
      duration: parseInt(song.duration || '0', 10)
    });
  } catch (error) {
    console.error('Stream error:', error);
    res.status(500).json({ error: 'Failed to get stream URL' });
  }
});

module.exports = router;
