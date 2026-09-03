const mongoose = require('mongoose');

// This mirrors the Track model in the Flutter app (videoId, title, artist,
// thumbnailUrl, duration) so data can be sent straight to/from the client
// without extra mapping.
const trackSchema = new mongoose.Schema(
  {
    videoId: { type: String, required: true },
    title: { type: String, required: true },
    artist: { type: String, required: true },
    thumbnailUrl: { type: String, required: true },
    durationMs: { type: Number, required: true },

    // ── Source metadata ────────────────────────────────────────────────────────
    source: { type: String, enum: ['saavn', 'archive'], default: 'saavn' },

    // ── JioSaavn enrichment fields ────────────────────────────────────────────
    // Preserved from raw JioSaavn API response for recommendation scoring
    language: { type: String },         // 'Hindi', 'English', 'Punjabi', etc.
    releaseYear: { type: Number },       // 1992, 2023, etc.
    album: { type: String },             // Album name
    primaryArtists: { type: String },    // Comma-separated primary artists
    isExplicit: { type: Boolean, default: false },

    // ── Amplify computed scores ───────────────────────────────────────────────
    // Derived by AmplifyNormalizer and stored for fast re-use during recommendations
    playCount: { type: Number, default: 0 },    // Raw JioSaavn play count
    popularityScore: { type: Number, default: 0 },   // 0-100 normalized
    mainstreamsScore: { type: Number, default: 0 },  // 0-100 mainstream signal
    recencyScore: { type: Number, default: 0 },      // 0-100 (100=very recent)
    isRemix: { type: Boolean, default: false },
    genre: { type: String },                          // optional, for future use

    // ── External ID mapping for import/matching ───────────────────────────────
    // Allows cross-referencing tracks with external providers without using
    // their IDs as Amplify's primary key.
    externalIds: {
      type: {
        spotify: { type: String },  // Spotify track ID
        youtube: { type: String },  // YouTube video ID
        isrc:    { type: String },  // International Standard Recording Code
      },
      default: {},
    },
  },
  { _id: false }
);

module.exports = trackSchema;
