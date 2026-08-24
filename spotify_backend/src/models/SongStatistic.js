const mongoose = require('mongoose');
const trackSchema = require('./trackSchema');

const songStatisticSchema = new mongoose.Schema({
  songId: { 
    type: String, 
    required: true, 
    unique: true,
    index: true 
  },
  // We optionally store a snapshot of the track for fast display in charts
  song: { 
    type: trackSchema 
  },
  
  // Aggregate Metrics
  lifetimePlays: { type: Number, default: 0 },
  lifetimeLikes: { type: Number, default: 0 },
  lifetimeSkips: { type: Number, default: 0 },
  lifetimeCompletions: { type: Number, default: 0 },
  
  // Temporal Metrics (Updated via Background Job)
  dailyPlays: { type: Number, default: 0 },
  weeklyPlays: { type: Number, default: 0 },
  monthlyPlays: { type: Number, default: 0 },
  
  // Calculated Engine Scores (Phase 2 & 6)
  popularityScore: { type: Number, default: 0 },
  trendScore: { type: Number, default: 0 },
  
  lastUpdatedAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('SongStatistic', songStatisticSchema);
