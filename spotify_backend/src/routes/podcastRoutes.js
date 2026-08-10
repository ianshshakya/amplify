const express = require('express');
const YTMusic = require('ytmusic-api');

const router = express.Router();
const ytmusic = new YTMusic();
let ytmusicInitialized = false;

async function initYTMusic() {
  if (!ytmusicInitialized) {
    await ytmusic.initialize();
    ytmusicInitialized = true;
  }
}

router.get('/search', async (req, res) => {
  try {
    const query = req.query.q;
    if (!query) return res.status(400).json({ error: 'Query is required' });
    await initYTMusic();
    const results = await ytmusic.searchSongs(query + ' podcast');
    const podcasts = results.slice(0, 20).map(p => ({
      id: p.videoId,
      title: p.name,
      author: p.artist?.name || 'Unknown',
      thumbnailUrl: p.thumbnails?.length ? p.thumbnails[p.thumbnails.length - 1].url : '',
      description: ''
    }));
    res.json(podcasts);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to search podcasts' });
  }
});

router.get('/:channelId', async (req, res) => {
  try {
    const { channelId } = req.params;
    await initYTMusic();
    const results = await ytmusic.searchSongs(channelId);
    if (!results || results.length === 0) return res.status(404).json({ error: 'Not found' });
    const episodes = results.map(song => ({
      videoId: song.videoId,
      title: song.name,
      podcastTitle: song.artist?.name || 'Unknown',
      thumbnailUrl: song.thumbnails?.length ? song.thumbnails[song.thumbnails.length - 1].url : '',
      durationSeconds: 1800
    }));
    res.json({
      id: channelId,
      title: channelId + ' Podcast',
      author: episodes[0]?.podcastTitle || 'Unknown',
      thumbnailUrl: episodes[0]?.thumbnailUrl || '',
      description: '',
      episodes
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to fetch podcast' });
  }
});

module.exports = router;
