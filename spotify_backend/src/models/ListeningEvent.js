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
    enum: ['PLAY', 'PAUSE', 'SKIP', 'COMPLETE', 'LIKE', 'UNLIKE'], 
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
  createdAt: { 
    type: Date, 
    default: Date.now, 
    expires: '90d' // Auto-delete events older than 90 days
  }
});

module.exports = mongoose.model('ListeningEvent', listeningEventSchema);
