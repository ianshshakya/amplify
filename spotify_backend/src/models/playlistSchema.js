const mongoose = require('mongoose');
const trackSchema = require('./trackSchema');

const playlistSchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true },
  tracks: { type: [trackSchema], default: [] },
  createdAt: { type: Date, default: Date.now },
});

module.exports = playlistSchema;
