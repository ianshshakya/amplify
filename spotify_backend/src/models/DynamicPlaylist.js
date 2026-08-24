const mongoose = require('mongoose');
const trackSchema = require('./trackSchema');

const dynamicPlaylistSchema = new mongoose.Schema({
  playlistId: { type: String, required: true, unique: true },
  title: { type: String, required: true },
  description: { type: String },
  thumbnailUrl: { type: String },
  songs: [trackSchema],
  updatedAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('DynamicPlaylist', dynamicPlaylistSchema);
