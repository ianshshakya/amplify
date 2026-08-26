const express = require('express');
const router = express.Router();

router.get('/config', (req, res) => {
  res.json({
    latestVersion: process.env.LATEST_APP_VERSION || '1.0.0',
    downloadUrl: process.env.APP_UPDATE_URL || 'https://anshshakya.com/amplify'
  });
});

module.exports = router;
