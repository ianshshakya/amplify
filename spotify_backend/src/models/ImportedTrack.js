const mongoose = require('mongoose');

/**
 * ImportedTrack
 * =============
 * Records the result of matching a single imported track against the Amplify catalog.
 *
 * Match statuses:
 *   MATCHED          → High confidence automatic match (score >= 85)
 *   REVIEW_REQUIRED  → Uncertain match (score 60-84), user should review
 *   UNAVAILABLE      → No suitable match found (score < 60 or no results)
 */
const importedTrackSchema = new mongoose.Schema({
  importJobId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'ImportJob',
    required: true,
    index: true,
  },

  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },

  // ── Source metadata ────────────────────────────────────────────────────────
  source:        { type: String, required: true },  // 'spotify' | 'youtube'
  sourceTrackId: { type: String, required: true },  // Provider's native track ID
  sourcePlaylistIds: [{ type: String }],           // Which source playlists contain this
  positionInPlaylist: { type: Number, default: 0 },

  // Provider-supplied metadata
  title:     { type: String, required: true },
  artist:    { type: String, required: true },
  artists:   [{ type: String }],              // All artists (primary + featured)
  album:     { type: String },
  isrc:      { type: String, index: true },   // ISRC for high-confidence matching
  durationMs:{ type: Number },
  releaseDate:{ type: String },
  sourceUrl: { type: String },
  thumbnailUrl: { type: String },

  // Normalized versions (computed during normalization)
  normalizedTitle:  { type: String },
  normalizedArtist: { type: String },

  // ── Match result ───────────────────────────────────────────────────────────
  matchStatus: {
    type: String,
    enum: ['MATCHED', 'REVIEW_REQUIRED', 'UNAVAILABLE'],
    required: true,
    index: true,
  },
  confidenceScore: { type: Number, default: 0 }, // 0-100

  // The Amplify videoId matched to (null if UNAVAILABLE)
  amplifyVideoId: { type: String, index: true },

  // Top alternative matches for the review screen (up to 5)
  reviewCandidates: [{
    videoId:         { type: String },
    title:           { type: String },
    artist:          { type: String },
    thumbnailUrl:    { type: String },
    durationMs:      { type: Number },
    confidenceScore: { type: Number },
  }],

  // Whether the user manually reviewed and accepted this match
  userReviewed:   { type: Boolean, default: false },
  userSelection:  { type: String }, // videoId chosen by user during review

  // Auto-delete imported track records after 60 days
  createdAt: {
    type: Date,
    default: Date.now,
    expires: '60d',
  },
});

// Compound index for idempotency: prevent duplicate imports of same track per job
importedTrackSchema.index({ importJobId: 1, source: 1, sourceTrackId: 1 }, { unique: true });

module.exports = mongoose.model('ImportedTrack', importedTrackSchema);
