const User = require('../models/User');

async function getPlaylists(req, res) {
  const user = await User.findById(req.userId);
  if (!user) return res.status(404).json({ message: 'User not found' });
  res.json({ playlists: user.playlists });
}

async function createPlaylist(req, res) {
  const { name } = req.body;
  if (!name || !name.trim()) {
    return res.status(400).json({ message: 'Playlist name is required' });
  }

  const user = await User.findById(req.userId);
  if (!user) return res.status(404).json({ message: 'User not found' });

  user.playlists.push({ name: name.trim(), tracks: [] });
  await user.save();

  res.status(201).json({ playlists: user.playlists });
}

async function deletePlaylist(req, res) {
  const { playlistId } = req.params;

  const user = await User.findById(req.userId);
  if (!user) return res.status(404).json({ message: 'User not found' });

  user.playlists = user.playlists.filter((p) => p._id.toString() !== playlistId);
  await user.save();

  res.json({ playlists: user.playlists });
}

async function addTrackToPlaylist(req, res) {
  const { playlistId } = req.params;
  const { track } = req.body;

  if (!track || !track.videoId) {
    return res.status(400).json({ message: 'A valid track is required' });
  }

  const user = await User.findById(req.userId);
  if (!user) return res.status(404).json({ message: 'User not found' });

  const playlist = user.playlists.id(playlistId);
  if (!playlist) return res.status(404).json({ message: 'Playlist not found' });

  const alreadyExists = playlist.tracks.some((t) => t.videoId === track.videoId);
  if (!alreadyExists) {
    playlist.tracks.push(track);
    await user.save();
  }

  res.json({ playlist });
}

async function removeTrackFromPlaylist(req, res) {
  const { playlistId, videoId } = req.params;

  const user = await User.findById(req.userId);
  if (!user) return res.status(404).json({ message: 'User not found' });

  const playlist = user.playlists.id(playlistId);
  if (!playlist) return res.status(404).json({ message: 'Playlist not found' });

  playlist.tracks = playlist.tracks.filter((t) => t.videoId !== videoId);
  await user.save();

  res.json({ playlist });
}

module.exports = {
  getPlaylists,
  createPlaylist,
  deletePlaylist,
  addTrackToPlaylist,
  removeTrackFromPlaylist,
};
