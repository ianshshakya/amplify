const User = require('../models/User');

const MAX_WATCH_HISTORY = 200; // keep this bounded so documents don't grow forever

async function getMe(req, res) {
  const user = await User.findById(req.userId);
  if (!user) return res.status(404).json({ message: 'User not found' });
  res.json(user.toSafeJSON());
}

async function toggleLikedSong(req, res) {
  const { track } = req.body;
  if (!track || !track.videoId) {
    return res.status(400).json({ message: 'A valid track is required' });
  }

  const user = await User.findById(req.userId);
  if (!user) return res.status(404).json({ message: 'User not found' });

  const existingIndex = user.likedSongs.findIndex((t) => t.videoId === track.videoId);

  if (existingIndex >= 0) {
    user.likedSongs.splice(existingIndex, 1);
  } else {
    user.likedSongs.push(track);
  }

  await user.save();
  res.json({ likedSongs: user.likedSongs });
}

async function addToWatchHistory(req, res) {
  const { track } = req.body;
  if (!track || !track.videoId) {
    return res.status(400).json({ message: 'A valid track is required' });
  }

  const user = await User.findById(req.userId);
  if (!user) return res.status(404).json({ message: 'User not found' });

  // Remove any earlier occurrence of this track so it moves to the top
  // instead of appearing twice in history.
  user.watchHistory = user.watchHistory.filter(
    (entry) => entry.track.videoId !== track.videoId
  );

  user.watchHistory.unshift({ track, playedAt: new Date() });

  // Trim to the most recent N plays.
  if (user.watchHistory.length > MAX_WATCH_HISTORY) {
    user.watchHistory = user.watchHistory.slice(0, MAX_WATCH_HISTORY);
  }

  await user.save();
  res.json({ watchHistory: user.watchHistory });
}

async function getWatchHistory(req, res) {
  const user = await User.findById(req.userId);
  if (!user) return res.status(404).json({ message: 'User not found' });
  res.json({ watchHistory: user.watchHistory });
}

module.exports = { getMe, toggleLikedSong, addToWatchHistory, getWatchHistory };
