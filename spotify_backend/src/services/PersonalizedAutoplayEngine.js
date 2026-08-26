/**
 * PersonalizedAutoplayEngine
 * ==========================
 * The core engine for "Next Song" true continuous personalized playback.
 * 
 * Formula:
 * NEXT_SONG_SCORE =
 *    CURRENT_SONG_SIMILARITY
 *  + USER_TASTE_AFFINITY
 *  + SESSION_AFFINITY
 *  + NOVELTY
 *  + QUALITY / POPULARITY_BONUS
 *  - PENALTIES (recently played, skip repetition, artist repetition)
 */

const CandidateGenerator = require('./CandidateGenerator');
const TasteEngine = require('./TasteEngine');
const { normalizeTrack } = require('./AmplifyNormalizer');

class PersonalizedAutoplayEngine {
  /**
   * Get the next recommended tracks for continuous autoplay.
   * 
   * @param {object} currentSong - The seed track currently playing
   * @param {object|null} userProfile - UserMusicProfile from MongoDB
   * @param {object} sessionContext - { recentSongIds: [], recentArtists: [] }
   * @param {number} limit - Target number of tracks to return
   * @returns {Promise<object[]>} - Ranked, formatted tracks
   */
  static async getNextTracks(currentSong, userProfile, sessionContext, limit = 8) {
    const normalizedSeed = normalizeTrack({
      ...currentSong,
      duration: currentSong.durationMs ? Math.round(currentSong.durationMs / 1000) : (currentSong.duration || 0),
    });

    // 1. Generate large diverse pool (up to 150 candidates)
    const candidates = await CandidateGenerator.generateAutoplayPool(normalizedSeed, userProfile, sessionContext);

    // 2. Score each candidate
    const scored = this._scoreCandidates(candidates, normalizedSeed, userProfile, sessionContext);

    // 3. Apply Diversity Controller (avoid 5 The Weeknd songs in a row)
    const diverse = this._enforceDiversity(scored, limit);

    // 4. Format for client and return
    return this._formatForClient(diverse);
  }

  static _scoreCandidates(candidates, seedTrack, userProfile, sessionContext) {
    const artistAffinity = this._getMap(userProfile, 'artistAffinity');
    const moodAffinity = this._getMap(userProfile, 'moodAffinity');
    const eraAffinity = this._getMap(userProfile, 'eraAffinity');
    
    const sessionArtists = new Set(sessionContext.recentArtists || []);
    const recentIds = new Set(sessionContext.recentSongIds || []);

    const seedMood = TasteEngine._inferMood(seedTrack);
    const seedEra = TasteEngine._inferEra(seedTrack.releaseYear);
    const seedArtist = seedTrack.primaryArtist || (seedTrack.artist || '').split(',')[0].trim();

    const scored = candidates.map(track => {
      let score = 0;
      const reasons = [];

      // ── A. Current Song Similarity (0 - 30)
      const trackMood = TasteEngine._inferMood(track);
      const trackEra = TasteEngine._inferEra(track.releaseYear);
      let similarityScore = 0;
      if (trackMood === seedMood && seedMood) similarityScore += 15;
      if (trackEra === seedEra && seedEra) similarityScore += 5;
      const trackArtist = track.primaryArtist || (track.artist || '').split(',')[0].trim();
      if (trackArtist === seedArtist) similarityScore += 10;
      score += similarityScore;
      if (similarityScore > 15) reasons.push(`Similar to current song`);

      // ── B. User Taste Affinity (0 - 40)
      let tasteScore = 0;
      const aff = artistAffinity.get(trackArtist) || 0;
      if (aff > 0) {
        tasteScore += (aff * 25);
        if (aff > 0.7) reasons.push(`You love ${trackArtist}`);
      }
      const moodAff = moodAffinity.get(trackMood) || 0;
      if (moodAff > 0) {
        tasteScore += (moodAff * 10);
      }
      const eraAff = eraAffinity.get(trackEra) || 0;
      if (eraAff > 0) {
        tasteScore += (eraAff * 5);
      }
      score += tasteScore;

      // ── C. Session Affinity (0 - 15)
      let sessionScore = 0;
      if (sessionArtists.has(trackArtist)) {
        sessionScore += 15;
        reasons.push(`Matches current session`);
      }
      score += sessionScore;

      // ── D. Quality & Popularity Bonus (0 - 10)
      // We don't want popularity to dominate personalization, so it's a small bonus
      const pop = track.popularityScore || 0;
      const popBonus = (pop / 100) * 10;
      score += popBonus;

      // ── E. Novelty (0 - 5)
      const novelty = track.discoveryScore || (100 - pop);
      score += (novelty / 100) * 5;

      // ── F. Penalties
      let penalty = 0;
      if (recentIds.has(track.videoId)) {
        penalty += 100; // Almost never recommend a song just played
        reasons.push(`Recently played`);
      }
      if (track.isRemix) {
        penalty += 15;
      }
      score -= penalty;

      return {
        ...track,
        _autoplayScore: {
          total: score,
          similarity: similarityScore,
          taste: tasteScore,
          session: sessionScore,
          reasons
        }
      };
    });

    return scored.sort((a, b) => b._autoplayScore.total - a._autoplayScore.total);
  }

  static _enforceDiversity(scoredTracks, limit) {
    const selected = [];
    const artistCounts = new Map();
    
    // We want some discovery. We will pick top items, but enforce artist limits.
    for (const track of scoredTracks) {
      if (selected.length >= limit) break;

      const artist = track.primaryArtist || (track.artist || '').split(',')[0].trim();
      const count = artistCounts.get(artist) || 0;

      // Max 2 songs per artist in the next 8-15 queue
      if (count >= 2) continue;
      
      // Prevent consecutive same-artist
      if (selected.length > 0) {
        const lastArtist = selected[selected.length - 1].primaryArtist || selected[selected.length - 1].artist;
        if (lastArtist === artist && count >= 1) {
            continue; // Can't be consecutive if we already have one
        }
      }

      artistCounts.set(artist, count + 1);
      selected.push(track);
    }
    
    return selected;
  }

  static _getMap(profile, key) {
    if (!profile || !profile[key]) return new Map();
    if (profile[key] instanceof Map) return profile[key];
    return new Map(Object.entries(profile[key]));
  }

  static _formatForClient(tracks) {
    return tracks.map(t => {
      return {
        videoId: t.videoId,
        title: t.title,
        artist: t.artist,
        thumbnailUrl: t.thumbnailUrl,
        durationMs: t.durationMs || (t.duration ? t.duration * 1000 : 0),
        source: t.source || 'saavn',
        language: t.language || undefined,
        releaseYear: t.releaseYear || undefined,
        _debug: t._autoplayScore,
      };
    });
  }
}

module.exports = PersonalizedAutoplayEngine;
