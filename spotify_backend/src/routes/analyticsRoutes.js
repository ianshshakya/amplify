const express = require('express');
const requireAuth = require('../middleware/requireAuth');
const AnalyticsService = require('../services/AnalyticsService');
const ListeningEvent = require('../models/ListeningEvent');

const router = express.Router();

router.use(requireAuth); // Requires valid user token

/**
 * @route POST /api/analytics/events
 * @desc Ingest a batch or single listening event from the client
 */
router.post('/events', async (req, res) => {
  try {
    const events = Array.isArray(req.body) ? req.body : [req.body];
    
    // Process asynchronously, do not block the client response
    Promise.all(
      events.map(eventData => AnalyticsService.processEvent(eventData, req.userId))
    ).catch(err => console.error('Analytics batch error:', err.message));

    res.status(202).json({ success: true, message: 'Events accepted' });
  } catch (error) {
    console.error('Analytics route error:', error.message);
    res.status(500).json({ error: 'Failed to process events' });
  }
});

/**
 * @route GET /api/analytics/recent
 * @desc Get the 4 most recently played unique tracks by the user
 */
router.get('/recent', async (req, res) => {
  try {
    // We want the most recent tracks, deduplicated by songId
    const recentEvents = await ListeningEvent.find({
      userId: req.userId,
      eventType: { $in: ['PLAY', 'COMPLETE'] }
    })
    .sort({ createdAt: -1 })
    .limit(30) // fetch more to account for duplicates
    .lean();

    const uniqueTracks = [];
    const seenIds = new Set();
    
    for (const event of recentEvents) {
      if (!seenIds.has(event.songId) && event.song) {
        seenIds.add(event.songId);
        uniqueTracks.push(event.song);
      }
      if (uniqueTracks.length >= 4) break;
    }

    res.json(uniqueTracks);
  } catch (error) {
    console.error('Analytics recent route error:', error.message);
    res.status(500).json({ error: 'Failed to fetch recent tracks' });
  }
});

module.exports = router;
