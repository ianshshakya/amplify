const mongoose = require('mongoose');
const trackSchema = require('./trackSchema');

const playlistSchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true },
  tracks: { type: [trackSchema], default: [] },
  createdAt: { type: Date, default: Date.now },

  // ── Import provenance ─────────────────────────────────────────────────
  // Only populated when the playlist was imported from an external provider.
  importMeta: {
    source:        { type: String },  // 'spotify' | 'youtube' | null
    sourceId:      { type: String },  // External playlist ID (idempotency key)
    sourceUrl:     { type: String },  // Original URL if available
    importJobId:   { type: String },  // Reference to the ImportJob that created this
    description:   { type: String },  // Original description
    thumbnailUrl:  { type: String },  // Original cover art URL
    unavailableCount: { type: Number, default: 0 },  // Tracks that couldn't be matched
  },
});

module.exports = playlistSchema;
