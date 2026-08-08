const express = require('express');
const requireAuth = require('../middleware/requireAuth');
const {
  getPlaylists,
  createPlaylist,
  deletePlaylist,
  addTrackToPlaylist,
  removeTrackFromPlaylist,
} = require('../controllers/playlistController');

const router = express.Router();

router.use(requireAuth);

router.get('/', getPlaylists);
router.post('/', createPlaylist);
router.delete('/:playlistId', deletePlaylist);
router.post('/:playlistId/tracks', addTrackToPlaylist);
router.delete('/:playlistId/tracks/:videoId', removeTrackFromPlaylist);

module.exports = router;
