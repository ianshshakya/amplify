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
  },
  { _id: false }
);

module.exports = trackSchema;
