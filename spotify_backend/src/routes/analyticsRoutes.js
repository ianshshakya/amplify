const express = require('express');
const requireAuth = require('../middleware/requireAuth');
const AnalyticsService = require('../services/AnalyticsService');

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

module.exports = router;
