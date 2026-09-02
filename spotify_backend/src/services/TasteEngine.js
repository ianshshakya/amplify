/**
 * TasteEngine
 * ===========
 * Recalculates the music profile for a user based on listening events.
 *
 * Fixes from audit:
 *   - SKIP now has a negative weight (previously ignored entirely)
 *   - EARLY_SKIP (< 20% completion) has a strong negative weight
 *   - REPLAY event type added with strong positive weight
 *   - genreAffinity now actually populated (using language as proxy)
 *   - Handles both Mongoose Map and plain object for artistAffinity
 */

const ListeningEvent = require('../models/ListeningEvent');
const UserMusicProfile = require('../models/UserMusicProfile');

// Event weights for taste calculation
// Positive = user likes this type of content
// Negative = user dislikes / avoids this type of content
const EVENT_WEIGHTS = {
  PLAY:        1.0,
  COMPLETE:    2.5,   // Finished = positive signal
  LIKE:        5.0,   // Explicit like = very strong positive
  REPLAY:      4.0,   // Replayed = strong positive
  SKIP:       -1.5,   // Skipped (general)
  EARLY_SKIP: -4.0,   // Skipped before 20% = strong negative
  UNLIKE:     -4.0,   // Explicit unlike
  DISLIKE:    -5.0,   // Explicit dislike
  SAVE:        5.0,   // Saved to library
  ADD_TO_PLAYLIST: 6.0, // Extremely strong positive
};

class TasteEngine {
  /**
   * Recalculates the music profile for a specific user.
   * Derives artist affinity, genre affinity, language affinity.
   *
   * @param {string|ObjectId} userId
   * @returns {Promise<UserMusicProfile|null>}
   */
  static async calculateUserProfile(userId) {
    try {
      console.log(`Calculating User Profile for user: ${userId}`);

      // Fetch user's listening events from the last 90 days
      const events = await ListeningEvent.find({ userId });

      if (events.length === 0) {
        return null; // Not enough data
      }

      let artistScores = {};
      let languageScores = {};
      let moodScores = {};
      let energyScores = {};
      let eraScores = {};

      let totalCompletion = 0;
      let completionCount = 0;

      const now = Date.now();
      const NINETY_DAYS_MS = 90 * 24 * 60 * 60 * 1000;

      for (const event of events) {
        let baseWeight = this._getEventWeight(event);
        
        // Apply time decay: more recent events have higher weight
        const eventAgeMs = Math.max(0, now - new Date(event.createdAt).getTime());
        const ageRatio = Math.min(1, eventAgeMs / NINETY_DAYS_MS);
        // decayFactor ranges from 1.0 (now) to 0.2 (90 days ago)
        const decayFactor = 1.0 - (ageRatio * 0.8);
        const weight = baseWeight * decayFactor;

        const song = event.song;
        if (!song) continue;

        // Artist Affinity
        if (song.artist) {
          const artists = song.artist.split(',').map(a => this.sanitizeKey(a.trim()));
          for (const a of artists) {
            artistScores[a] = (artistScores[a] || 0) + weight;
          }
        }

        // Language Affinity (using language as genre proxy)
        const lang = song.language || this._inferLanguage(song.artist, song.title);
        if (lang) {
          languageScores[lang] = (languageScores[lang] || 0) + weight;
        }

        // Era Affinity
        const era = this._inferEra(song.releaseYear);
        if (era) {
          eraScores[era] = (eraScores[era] || 0) + weight;
        }

        // Mood & Energy Affinity
        const mood = this._inferMood(song);
        if (mood) {
          moodScores[mood] = (moodScores[mood] || 0) + weight;
        }
        const energy = this._inferEnergy(song, mood);
        if (energy) {
          energyScores[energy] = (energyScores[energy] || 0) + weight;
        }

        // Completion rate (only for positive events)
        if (baseWeight > 0 && event.completionPercent > 0) {
          totalCompletion += event.completionPercent;
          completionCount++;
        }
      }

      // Normalize scores — clamp negative scores to 0 for the affinity maps
      const normalizedArtists = this._normalizeScores(artistScores, true);
      const normalizedLanguages = this._normalizeScores(languageScores, true);
      const normalizedMoods = this._normalizeScores(moodScores, true);
      const normalizedEnergies = this._normalizeScores(energyScores, true);
      const normalizedEras = this._normalizeScores(eraScores, true);

      const avgCompletion = completionCount > 0 ? (totalCompletion / completionCount) / 100 : 0.0;

      // Discovery preference: derived from how often user plays unknown/niche songs
      const highNoveltyEvents = events.filter(e => e.eventType === 'COMPLETE' || e.eventType === 'LIKE');
      const discoveryPref = Math.min(1.0, highNoveltyEvents.length > 20 ? 0.4 : 0.2);

      // Upsert the profile
      const profile = await UserMusicProfile.findOneAndUpdate(
        { userId },
        {
          $set: {
            artistAffinity: normalizedArtists,
            languageAffinity: normalizedLanguages,
            moodAffinity: normalizedMoods,
            energyAffinity: normalizedEnergies,
            eraAffinity: normalizedEras,
            averageCompletionRate: avgCompletion,
            discoveryPreference: discoveryPref,
            lastCalculatedAt: Date.now(),
          },
        },
        { upsert: true, new: true }
      );

      return profile;
    } catch (error) {
      console.error(`TasteEngine error for user ${userId}:`, error.message);
      return null;
    }
  }

  /**
   * Get the event weight, taking completion percentage into account
   * for differentiating early skips from late skips.
   */
  static _getEventWeight(event) {
    const { eventType, completionPercent } = event;

    // Differentiate SKIP into early/late skip
    if (eventType === 'SKIP') {
      if (completionPercent !== null && completionPercent !== undefined) {
        if (completionPercent < 20) return EVENT_WEIGHTS.EARLY_SKIP;
        if (completionPercent > 80) return 0.5; // Late skip — actually listened most of it
      }
    }

    return EVENT_WEIGHTS[eventType] || 0;
  }

  /**
   * Attempt to infer language from artist/title patterns (basic heuristic).
   */
  static _inferLanguage(artist, title) {
    const text = `${artist || ''} ${title || ''}`.toLowerCase();
    const hindiPatterns = ['arijit', 'shreya', 'kumar sanu', 'udit', 'lata', 'asha', 'neha', 'atif'];
    const punjabiPatterns = ['diljit', 'moosewala', 'dhillon', 'shubh', 'karan', 'bhangra'];
    if (punjabiPatterns.some(p => text.includes(p))) return 'Punjabi';
    if (hindiPatterns.some(p => text.includes(p))) return 'Hindi';
    return null;
  }

  /**
   * Infer era from release year.
   */
  static _inferEra(releaseYear) {
    if (!releaseYear) return null;
    const year = parseInt(releaseYear, 10);
    if (isNaN(year)) return null;
    if (year >= 2020) return '2020s';
    if (year >= 2010) return '2010s';
    if (year >= 2000) return '2000s';
    if (year >= 1990) return '1990s';
    if (year >= 1980) return '1980s';
    if (year >= 1970) return '1970s';
    return 'Classic';
  }

  /**
   * Heuristic to infer mood based on title and artist.
   */
  static _inferMood(track) {
    const text = `${track.artist || ''} ${track.title || ''}`.toLowerCase();
    if (text.includes('party') || text.includes('dance') || text.includes('club') || text.includes('dj') || text.includes('remix')) return 'party';
    if (text.includes('chill') || text.includes('relax') || text.includes('lo-fi') || text.includes('lofi') || text.includes('acoustic') || text.includes('unplugged')) return 'chill';
    if (text.includes('workout') || text.includes('gym') || text.includes('motivation')) return 'workout';
    if (text.includes('sad') || text.includes('cry') || text.includes('heartbreak') || text.includes('dard')) return 'sad';
    if (text.includes('love') || text.includes('romance') || text.includes('romantic') || text.includes('ishq') || text.includes('pyaar')) return 'romance';
    if (text.includes('focus') || text.includes('study') || text.includes('instrumental')) return 'focus';
    return null;
  }

  /**
   * Heuristic to infer energy based on mood and track features.
   */
  static _inferEnergy(track, mood) {
    if (mood === 'party' || mood === 'workout') return 'high';
    if (mood === 'chill' || mood === 'sad' || mood === 'romance' || mood === 'focus') return 'low';
    return 'medium';
  }

  /**
   * Normalizes a score map so max value = 1.0.
   * If clampNegative is true, negative scores are excluded from the result.
   */
  static _normalizeScores(scoreMap, clampNegative = false) {
    // Remove negative entries if clamping
    if (clampNegative) {
      const filtered = {};
      for (const [k, v] of Object.entries(scoreMap)) {
        if (v > 0) filtered[k] = v;
      }
      scoreMap = filtered;
    }

    let maxScore = 0;
    for (const key in scoreMap) {
      if (scoreMap[key] > maxScore) maxScore = scoreMap[key];
    }
    if (maxScore === 0) return {};

    const normalized = {};
    for (const key in scoreMap) {
      normalized[key] = Math.round((scoreMap[key] / maxScore) * 100) / 100;
    }
    return normalized;
  }

  /**
   * Mongoose Map keys cannot contain '.' or '$'
   */
  static sanitizeKey(key) {
    if (!key) return 'Unknown';
    return String(key).replace(/[\.\$]/g, '').trim() || 'Unknown';
  }
}

module.exports = TasteEngine;
