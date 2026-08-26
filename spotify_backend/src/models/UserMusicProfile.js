const mongoose = require('mongoose');

const userMusicProfileSchema = new mongoose.Schema({
  userId: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'User', 
    required: true, 
    unique: true 
  },
  
  // Object maps containing normalized affinity scores (0.0 to 1.0)
  // Example: { "Arijit Singh": 0.95, "The Weeknd": 0.82 }
  artistAffinity: { 
    type: Map, 
    of: Number,
    default: {}
  },
  
  // Example: { "Pop": 0.88, "Hip-Hop": 0.74 }
  genreAffinity: { 
    type: Map, 
    of: Number,
    default: {}
  },
  
  // Example: { "Hindi": 0.9, "English": 0.7 }
  languageAffinity: {
    type: Map,
    of: Number,
    default: {}
  },

  // Example: { "happy": 0.8, "sad": 0.5, "chill": 0.9, "party": 0.2 }
  moodAffinity: {
    type: Map,
    of: Number,
    default: {}
  },

  // Example: { "low": 0.3, "medium": 0.6, "high": 0.8 }
  energyAffinity: {
    type: Map,
    of: Number,
    default: {}
  },

  // Example: { "1990s": 0.4, "2000s": 0.7, "2010s": 0.9, "2020s": 0.95 }
  eraAffinity: {
    type: Map,
    of: Number,
    default: {}
  },

  // Number between 0.0 (Mostly Familiar) to 1.0 (Highly Adventurous/Discovery)
  discoveryPreference: { 
    type: Number, 
    default: 0.2 
  },

  averageCompletionRate: {
    type: Number,
    default: 0.0
  },
  
  lastCalculatedAt: { 
    type: Date, 
    default: Date.now 
  }
});

module.exports = mongoose.model('UserMusicProfile', userMusicProfileSchema);
