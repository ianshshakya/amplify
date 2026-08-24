const ListeningEvent = require('../models/ListeningEvent');
const UserMusicProfile = require('../models/UserMusicProfile');

class TasteEngine {
  /**
   * Recalculates the music profile for a specific user.
   * Derives artist affinity, genre affinity, and general listening patterns.
   */
  static async calculateUserProfile(userId) {
    try {
      console.log(`Calculating User Profile for user: ${userId}`);
      
      // Fetch user's listening events from the last 90 days (the TTL limit)
      // Only care about events that signify positive interaction (PLAY, COMPLETE, LIKE)
      const events = await ListeningEvent.find({
        userId,
        eventType: { $in: ['PLAY', 'COMPLETE', 'LIKE'] }
      });

      if (events.length === 0) {
        return null; // Not enough data
      }

      let artistScores = {};
      let genreScores = {};
      let languageScores = {};
      
      let totalCompletion = 0;
      let completionCount = 0;

      for (const event of events) {
        const weight = this._getEventWeight(event.eventType);
        const song = event.song;
        
        // Artist Affinity
        if (song.artist) {
          // split by comma if multiple artists
          const artists = song.artist.split(',').map(a => a.trim());
          for (const a of artists) {
            artistScores[a] = (artistScores[a] || 0) + weight;
          }
        }

        // Language Affinity
        if (song.language) {
          languageScores[song.language] = (languageScores[song.language] || 0) + weight;
        }

        // Completion Rate Tracking
        if (event.completionPercent > 0) {
          totalCompletion += event.completionPercent;
          completionCount++;
        }
      }

      // Normalize scores between 0.0 and 1.0
      const normalizedArtists = this._normalizeScores(artistScores);
      const normalizedLanguages = this._normalizeScores(languageScores);
      
      const avgCompletion = completionCount > 0 ? (totalCompletion / completionCount) / 100 : 0.0;

      // Upsert the profile
      const profile = await UserMusicProfile.findOneAndUpdate(
        { userId },
        {
          $set: {
            artistAffinity: normalizedArtists,
            languageAffinity: normalizedLanguages,
            averageCompletionRate: avgCompletion,
            lastCalculatedAt: Date.now()
          }
        },
        { upsert: true, new: true }
      );

      return profile;
    } catch (error) {
      console.error(`TasteEngine error for user ${userId}:`, error.message);
      return null;
    }
  }

  static _getEventWeight(eventType) {
    switch (eventType) {
      case 'PLAY': return 1.0;
      case 'COMPLETE': return 2.0;
      case 'LIKE': return 3.0;
      default: return 0.0;
    }
  }

  /**
   * Takes a map of raw scores { "Arijit": 15, "Drake": 5 }
   * and normalizes them so the max value becomes 1.0
   * e.g., { "Arijit": 1.0, "Drake": 0.33 }
   */
  static _normalizeScores(scoreMap) {
    let maxScore = 0;
    for (const key in scoreMap) {
      if (scoreMap[key] > maxScore) maxScore = scoreMap[key];
    }

    if (maxScore === 0) return {};

    let normalized = {};
    for (const key in scoreMap) {
      // Keep two decimal places
      normalized[key] = Math.round((scoreMap[key] / maxScore) * 100) / 100;
    }
    return normalized;
  }
}

module.exports = TasteEngine;
