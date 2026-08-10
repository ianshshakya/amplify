const express = require('express');

const router = express.Router();

router.get('/search', async (req, res) => {
  try {
    // Podcasts are temporarily disabled in the JioSaavn backend migration
    // to prevent server crashes since saavnapi doesn't natively support podcasts.
    res.json([]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to search podcasts' });
  }
});

router.get('/:channelId', async (req, res) => {
  try {
    const { channelId } = req.params;
    res.json({
      id: channelId,
      title: channelId + ' Podcast',
      author: 'Unknown',
      thumbnailUrl: '',
      description: 'Podcasts are currently unavailable.',
      episodes: []
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to fetch podcast' });
  }
});

module.exports = router;
