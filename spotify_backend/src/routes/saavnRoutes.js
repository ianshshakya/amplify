const express = require('express');
const saavn = require('saavnapi').default;

const router = express.Router();

// Search for songs
router.get('/search', async (req, res) => {
  try {
    const query = req.query.q;
    if (!query) {
      return res.status(400).json({ error: 'Missing search query' });
    }

    const response = await saavn.search.searchSongs({ query, page: 1, limit: 20 });
    const songs = response.results || [];

    // Map JioSaavn results to our expected format
    const results = songs.map(song => {
      // Find highest quality image
      const thumbnail = song.image?.find(img => img.quality === '500x500')?.url 
                     || (song.image && song.image.length > 0 ? song.image[song.image.length - 1].url : '');
                     
      // Get primary artist string
      const artist = song.artists?.primary?.map(a => a.name).join(', ') || 'Unknown Artist';

      return {
        videoId: song.id,
        title: song.name || song.title, // 'name' in searchSongs, 'title' in searchAll
        artist: artist,
        thumbnailUrl: thumbnail,
        duration: song.duration,
      };
    });

    res.json(results);
  } catch (error) {
    console.error('Search error:', error);
    res.status(500).json({ error: 'Failed to search for songs' });
  }
});

// Get stream URL (download URL from Saavn)
router.get('/stream/:songId', async (req, res) => {
  try {
    const { songId } = req.params;
    if (!songId) {
      return res.status(400).json({ error: 'Missing songId' });
    }

    const response = await saavn.songs.getSongByIds({ songIds: [songId] });
    const song = response[0];

    if (!song || !song.downloadUrl) {
      return res.status(404).json({ error: 'Song not found or no download URL available' });
    }

    // Find the 320kbps quality, fallback to 160kbps, then whatever is available
    const urlList = song.downloadUrl;
    const bestUrl = urlList.find(u => u.quality === '320kbps')?.url 
                 || urlList.find(u => u.quality === '160kbps')?.url
                 || urlList[urlList.length - 1].url;

    res.json({ streamUrl: bestUrl, duration: song.duration });
  } catch (error) {
    console.error('Stream error:', error);
    res.status(500).json({ error: 'Failed to get stream URL' });
  }
});

module.exports = router;
