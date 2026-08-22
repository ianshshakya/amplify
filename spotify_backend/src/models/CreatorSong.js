const mongoose = require('mongoose');

const creatorSongSchema = new mongoose.Schema(
  {
    videoId: { type: String, required: true, unique: true }, // Can be Archive.org item identifier + filename
    title: { type: String, required: true },
    artist: { type: String, required: true },
    thumbnailUrl: { type: String }, // optional, can be a default creator image
    streamUrl: { type: String, required: true }, // The direct .mp3 link
    duration: { type: Number }, // To match saavn api format
    createdAt: { type: Date, default: Date.now },
  }
);

module.exports = mongoose.model('CreatorSong', creatorSongSchema);
