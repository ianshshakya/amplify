const express = require('express');
const requireAuth = require('../middleware/requireAuth');
const RecommendationEngine = require('../services/RecommendationEngine');

const router = express.Router();

router.use(requireAuth);

/**
 * @route GET /api/recommendations/daily-mix
 * @desc Get a personalized mix of familiar and discovery tracks
 */
router.get('/daily-mix', async (req, res) => {
  try {
    const userId = req.user._id;
    const songs = await RecommendationEngine.getDailyMix(userId);
    
    res.json({
      id: 'daily-mix',
      title: 'Daily Mix',
      description: 'Made for you.',
      thumbnailUrl: songs.length > 0 ? songs[0].thumbnailUrl : '',
      songs: songs
    });
  } catch (error) {
    console.error('Daily Mix route error:', error.message);
    res.status(500).json({ error: 'Failed to generate recommendations' });
  }
});

/**
 * @route GET /api/recommendations/radio/song/:id
 * @desc Get an infinite radio stream starting from a song
 */
router.get('/radio/song/:id', async (req, res) => {
  try {
    const songs = await RecommendationEngine.getSongRadio(req.params.id, req.user._id);
    res.json(songs);
  } catch (error) {
    console.error('Song Radio route error:', error.message);
    res.status(500).json({ error: 'Failed to generate radio' });
  }
});

/**
 * @route GET /api/recommendations/radio/artist/:name
 * @desc Get an infinite radio stream for an artist
 */
router.get('/radio/artist/:name', async (req, res) => {
  try {
    const songs = await RecommendationEngine.getArtistRadio(req.params.name, req.user._id);
    res.json(songs);
  } catch (error) {
    console.error('Artist Radio route error:', error.message);
    res.status(500).json({ error: 'Failed to generate artist radio' });
  }
});

/**
 * @route GET /api/recommendations/one-song-away
 * @desc Get a single high-confidence discovery track
 */
router.get('/one-song-away', async (req, res) => {
  try {
    const song = await RecommendationEngine.getOneSongAway(req.user._id);
    if (!song) return res.status(404).json({ error: 'No discovery track found right now' });
    res.json(song);
  } catch (error) {
    console.error('One Song Away route error:', error.message);
    res.status(500).json({ error: 'Failed to fetch discovery track' });
  }
});

module.exports = router;
