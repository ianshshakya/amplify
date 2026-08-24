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
