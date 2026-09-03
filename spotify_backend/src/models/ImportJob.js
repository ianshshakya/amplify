const mongoose = require('mongoose');

/**
 * ImportJob
 * =========
 * Tracks the lifecycle of a music library import from an external provider.
 * 
 * Statuses:
 *   QUEUED         → Job created, waiting to start
 *   AUTHORIZING    → Verifying OAuth token with provider
 *   FETCHING       → Pulling data from provider API
 *   MATCHING       → Matching imported tracks against Amplify catalog
 *   IMPORTING      → Writing playlists/library to database
 *   PROCESSING_HISTORY → Seeding TasteEngine with import history
 *   COMPLETED      → Import finished successfully
 *   PARTIAL        → Finished but with some failures
 *   FAILED         → Fatal error
 *   CANCELLED      → User cancelled
 */
const importJobSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },

  provider: {
    type: String,
    enum: ['spotify', 'youtube', 'spotify_file', 'youtube_file'],
    required: true,
  },

  status: {
    type: String,
    enum: [
      'QUEUED', 'AUTHORIZING', 'FETCHING', 'MATCHING',
      'IMPORTING', 'PROCESSING_HISTORY', 'COMPLETED',
      'PARTIAL', 'FAILED', 'CANCELLED',
    ],
    default: 'QUEUED',
    index: true,
  },

  // Progress counters
  totalItems:        { type: Number, default: 0 },
  processedItems:    { type: Number, default: 0 },
  matchedItems:      { type: Number, default: 0 },
  reviewItems:       { type: Number, default: 0 },    // Uncertain matches needing review
  unavailableItems:  { type: Number, default: 0 },    // No match found
  playlistsImported: { type: Number, default: 0 },
  historyRecords:    { type: Number, default: 0 },

  // Resumability: store last processed cursor so the job can be restarted
  cursor: { type: mongoose.Schema.Types.Mixed, default: null },

  // Error tracking
  error:     { type: String },
  errorStack:{ type: String },

  startedAt:   { type: Date, default: Date.now },
  completedAt: { type: Date },

  // Auto-delete completed jobs after 30 days
  expiresAt: {
    type: Date,
    default: () => new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
    index: { expires: 0 },
  },
}, { timestamps: true });

module.exports = mongoose.model('ImportJob', importJobSchema);
