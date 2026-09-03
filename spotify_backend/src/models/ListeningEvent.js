const mongoose = require('mongoose');
const trackSchema = require('./trackSchema');

const listeningEventSchema = new mongoose.Schema({
  userId: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'User', 
    required: true, 
    index: true 
  },
  songId: { 
    type: String, 
    required: true, 
    index: true 
  },
  song: { 
    type: trackSchema, 
    required: true 
  },
  eventType: { 
    type: String, 
    enum: ['PLAY', 'PAUSE', 'SKIP', 'EARLY_SKIP', 'COMPLETE', 'LIKE', 'UNLIKE', 'REPLAY', 'DISLIKE', 'SAVE', 'ADD_TO_PLAYLIST'], 
    required: true 
  },
  sessionId: { 
    type: String 
  },
  durationPlayedMs: { 
    type: Number, 
    default: 0 
  },
  completionPercent: { 
    type: Number, 
    default: 0 
  },
  context: { 
    type: String 
  }, // e.g. 'home_trending', 'search', 'radio'

  // Source of this event — used by TasteEngine to weight imported history
  // less heavily than actual Amplify listening activity.
  sourceType: {
    type: String,
    enum: ['native_amplify', 'spotify_import', 'youtube_import'],
    default: 'native_amplify',
    index: true,
  },

  createdAt: { 
    type: Date, 
    default: Date.now, 
    expires: '90d' // Auto-delete events older than 90 days
  }
});

module.exports = mongoose.model('ListeningEvent', listeningEventSchema);
