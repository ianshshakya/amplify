const express = require('express');
const requireAuth = require('../middleware/requireAuth');
const {
  getMe,
  toggleLikedSong,
  addToWatchHistory,
  getWatchHistory,
} = require('../controllers/userController');

const router = express.Router();

router.use(requireAuth); // everything below requires a valid token

router.get('/me', getMe);
router.post('/liked-songs/toggle', toggleLikedSong);
router.post('/watch-history', addToWatchHistory);
router.get('/watch-history', getWatchHistory);

module.exports = router;
