const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const trackSchema = require('./trackSchema');
const playlistSchema = require('./playlistSchema');

const watchHistoryEntrySchema = new mongoose.Schema(
  {
    track: { type: trackSchema, required: true },
    playedAt: { type: Date, default: Date.now },
  },
  { _id: false }
);

const userSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
    },
    passwordHash: { type: String, required: true },

    likedSongs: { type: [trackSchema], default: [] },
    playlists: { type: [playlistSchema], default: [] },

    // Capped watch history — we trim this in the controller so it never
    // grows unbounded; it's what powers "recently played" and the
    // recommendation / reels feed later.
    watchHistory: { type: [watchHistoryEntrySchema], default: [] },
  },
  { timestamps: true }
);

// Hash the password automatically whenever it's set/changed.
userSchema.pre('save', async function (next) {
  if (!this.isModified('passwordHash')) return next();
  const salt = await bcrypt.genSalt(10);
  this.passwordHash = await bcrypt.hash(this.passwordHash, salt);
  next();
});

userSchema.methods.comparePassword = function (candidate) {
  return bcrypt.compare(candidate, this.passwordHash);
};

// Never send the password hash back to the client.
userSchema.methods.toSafeJSON = function () {
  const obj = this.toObject();
  delete obj.passwordHash;
  delete obj.__v;
  return obj;
};

module.exports = mongoose.model('User', userSchema);
