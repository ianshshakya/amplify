/**
 * ScoringEngine
 * =============
 * Scores every candidate AmplifyTrack against a PlaylistIntent and user profile.
 *
 * Formula (weights configurable per archetype):
 *
 *   score = (intentMatch   × intentWeight)
 *         + (popularity    × popularityWeight)
 *         + (userAffinity  × affinityWeight)
 *         + (recency       × recencyWeight)
 *         + (novelty       × noveltyWeight)
 *         + jitter (0–2, tie-breaking)
 *
 * All inputs are normalized to [0, 100] before weighting.
 * The final score is also [0, 100].
 *
 * Each scored track carries a `_scoring` debug object so developers
 * can inspect why a specific song was ranked the way it was.
 */

class ScoringEngine {
  /**
   * Score all candidates in a pool against the intent and user profile.
   *
   * @param {AmplifyTrack[]} candidates
   * @param {PlaylistIntent} intent
   * @param {object|null} userProfile - UserMusicProfile (from MongoDB)
   * @param {object|null} sessionContext - { recentArtists: [], recentGenres: [] }
   * @returns {ScoredTrack[]} - sorted descending by score, with _scoring debug info
   */
  static score(candidates, intent, userProfile = null, sessionContext = null) {
    const weights = intent.archetypeWeights;

    // Pre-build affinity lookup for O(1) access during scoring
    const artistAffinity = this._buildAffinityMap(userProfile);
    const sessionArtists = new Set((sessionContext && sessionContext.recentArtists) || []);

    const scored = candidates.map(track => {
      // ── 1. Intent Match Score (0–100) ───────────────────────────────────────
      const intentMatch = this._computeIntentMatch(track, intent);

      // ── 2. Popularity Score (already 0–100 in AmplifyTrack) ─────────────────
      const popularity = track.popularityScore || 0;

      // ── 3. User Affinity Score (0–100) ──────────────────────────────────────
      const userAffinity = this._computeUserAffinity(track, artistAffinity);

      // ── 4. Recency Score (already 0–100 in AmplifyTrack) ────────────────────
      const recency = track.recencyScore || 40;

      // ── 5. Novelty Score (inverse of popularity, 0–100) ────────────────────
      const novelty = track.discoveryScore || (100 - popularity);

      // ── 6. Session Affinity (0–100) — boost if artist matches recent session ─
      const sessionAffinity = sessionArtists.has(track.primaryArtist) ? 70 : 0;

      // ── 7. Remix penalty ────────────────────────────────────────────────────
      const remixPenalty = track.isRemix ? 15 : 0;

      // ── Weighted sum ─────────────────────────────────────────────────────────
      const raw =
        (intentMatch   * weights.intentWeight)    +
        (popularity    * weights.popularityWeight) +
        (userAffinity  * weights.affinityWeight)   +
        (recency       * weights.recencyWeight)    +
        (novelty       * weights.noveltyWeight)    +
        (sessionAffinity * 0.05)                   -
        remixPenalty                               +
        (Math.random() * 2); // Small jitter for tie-breaking

      const finalScore = Math.min(100, Math.max(0, raw));

      return {
        ...track,
        _scoring: {
          intentMatch,
          popularity,
          userAffinity,
          recency,
          novelty,
          sessionAffinity,
          remixPenalty,
          weights,
          finalScore,
          reasons: this._buildReasons({ intentMatch, popularity, userAffinity, recency, sessionAffinity, isRemix: track.isRemix }),
        },
      };
    });

    // Sort descending by final score
    return scored.sort((a, b) => b._scoring.finalScore - a._scoring.finalScore);
  }

  /**
   * Compute how well a track matches the playlist intent (0–100).
   * Checks: language, era, purpose/mood indicators.
   */
  static _computeIntentMatch(track, intent) {
    let score = 50; // Start at neutral

    // ── Language match ───────────────────────────────────────────────────────
    if (intent.languages && intent.languages.length > 0) {
      const trackLang = (track.language || '').toLowerCase();
      const matches = intent.languages.some(l => l.toLowerCase() === trackLang);
      if (matches) score += 25;
      else if (trackLang) score -= 20; // Language mismatch penalty
    }

    // ── Era match ─────────────────────────────────────────────────────────────
    if (intent.eraYears && track.releaseYear) {
      const { min, max } = intent.eraYears;
      if (track.releaseYear >= min && track.releaseYear <= max) {
        score += 25;
      } else {
        const distance = Math.min(
          Math.abs(track.releaseYear - min),
          Math.abs(track.releaseYear - max)
        );
        score -= Math.min(25, distance * 2); // Gradual penalty for off-era
      }
    }

    // ── Remix / cover penalty for mainstream playlists ────────────────────────
    if (track.isRemix && intent.archetypeWeights.popularityWeight > 0.30) {
      score -= 10;
    }

    return Math.min(100, Math.max(0, score));
  }

  /**
   * Build a Map from artist name → affinity score (0–1) from user profile.
   * Handles both Mongoose Map and plain objects.
   */
  static _buildAffinityMap(userProfile) {
    if (!userProfile || !userProfile.artistAffinity) return new Map();
    if (userProfile.artistAffinity instanceof Map) return userProfile.artistAffinity;
    return new Map(Object.entries(userProfile.artistAffinity));
  }

  /**
   * Compute user affinity for a track (0–100).
   */
  static _computeUserAffinity(track, artistAffinityMap) {
    if (!artistAffinityMap || artistAffinityMap.size === 0) return 0;

    const artists = (track.artist || '').split(',').map(a => a.trim());
    let maxAffinity = 0;

    for (const a of artists) {
      const aff = artistAffinityMap.get(a) || 0;
      if (aff > maxAffinity) maxAffinity = aff;
    }

    return Math.round(maxAffinity * 100);
  }

  /**
   * Build human-readable reasons for why a track was selected.
   */
  static _buildReasons({ intentMatch, popularity, userAffinity, recency, sessionAffinity, isRemix }) {
    const reasons = [];
    if (intentMatch >= 70) reasons.push(`${intentMatch}% intent match`);
    if (popularity >= 75) reasons.push(`mainstream (${popularity}% popularity)`);
    if (popularity >= 90) reasons.push('mega hit');
    if (userAffinity >= 70) reasons.push('matches your taste');
    if (recency >= 80) reasons.push('recently released');
    if (sessionAffinity >= 50) reasons.push('matches current session mood');
    if (isRemix) reasons.push('remix/cover version');
    return reasons;
  }
}

module.exports = ScoringEngine;
