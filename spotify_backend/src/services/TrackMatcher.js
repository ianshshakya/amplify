/**
 * TrackMatcher
 * ============
 * Matches imported tracks against the Amplify catalog using a multi-level
 * strategy from exact identifiers down to fuzzy text similarity.
 *
 * Match levels (in priority order):
 *   1. ISRC exact match          → very high confidence
 *   2. External ID mapping       → exact (if we've seen this track before)
 *   3. Exact title + artist      → high confidence
 *   4. Fuzzy weighted similarity → configurable confidence thresholds
 *
 * Confidence thresholds (configurable via MATCH_CONFIG):
 *   >= 85 → MATCHED (automatic)
 *   60-84 → REVIEW_REQUIRED (show user the candidates)
 *   < 60  → UNAVAILABLE
 */

const MusicProvider = require('./MusicProvider');
const { normalizeTracks } = require('./AmplifyNormalizer');

// ── Matching configuration ─────────────────────────────────────────────────
// These are deliberately configurable rather than magic numbers in the code.
const MATCH_CONFIG = {
  thresholds: {
    autoMatch:      85,  // >= this → MATCHED
    reviewRequired: 60,  // >= this & < autoMatch → REVIEW_REQUIRED
  },
  weights: {
    title:    0.40,
    artist:   0.30,
    album:    0.15,
    duration: 0.15,
  },
  // Max duration difference (ms) to be considered a potential match
  maxDurationDiff: 8000,  // 8 seconds
  // Max candidates to return for the review screen
  maxReviewCandidates: 5,
};

class TrackMatcher {
  /**
   * Match a single imported track against the Amplify catalog.
   *
   * @param {object} importedTrack  - Normalized ProviderTrack object
   * @returns {Promise<MatchResult>}
   */
  static async match(importedTrack) {
    const { title, artist, album, isrc, durationMs, sourceTrackId, source } = importedTrack;

    // ── Level 1: ISRC exact match ──────────────────────────────────────────
    if (isrc) {
      const isrcResult = await this._matchByIsrc(isrc);
      if (isrcResult) {
        return {
          matchStatus: 'MATCHED',
          confidenceScore: 100,
          amplifyVideoId: isrcResult.videoId,
          reviewCandidates: [],
        };
      }
    }

    // ── Level 2: External ID lookup (if we've imported this before) ────────
    const extResult = await this._matchByExternalId(source, sourceTrackId);
    if (extResult) {
      return {
        matchStatus: 'MATCHED',
        confidenceScore: 99,
        amplifyVideoId: extResult.videoId,
        reviewCandidates: [],
      };
    }

    // ── Level 3 & 4: Search + fuzzy scoring ───────────────────────────────
    const searchQuery = `${title} ${artist}`;
    const candidates = await MusicProvider.search(searchQuery, 10);

    if (!candidates || candidates.length === 0) {
      return {
        matchStatus: 'UNAVAILABLE',
        confidenceScore: 0,
        amplifyVideoId: null,
        reviewCandidates: [],
      };
    }

    // Score all candidates
    const scored = candidates.map(candidate => ({
      ...candidate,
      score: this._computeScore(importedTrack, candidate),
    })).sort((a, b) => b.score - a.score);

    const best = scored[0];
    const topCandidates = scored.slice(0, MATCH_CONFIG.maxReviewCandidates).map(c => ({
      videoId:         c.videoId,
      title:           c.title,
      artist:          c.artist,
      thumbnailUrl:    c.thumbnailUrl,
      durationMs:      c.durationMs,
      confidenceScore: Math.round(c.score),
    }));

    if (best.score >= MATCH_CONFIG.thresholds.autoMatch) {
      return {
        matchStatus: 'MATCHED',
        confidenceScore: Math.round(best.score),
        amplifyVideoId: best.videoId,
        reviewCandidates: [],
      };
    }

    if (best.score >= MATCH_CONFIG.thresholds.reviewRequired) {
      return {
        matchStatus: 'REVIEW_REQUIRED',
        confidenceScore: Math.round(best.score),
        amplifyVideoId: best.videoId, // tentative
        reviewCandidates: topCandidates,
      };
    }

    return {
      matchStatus: 'UNAVAILABLE',
      confidenceScore: Math.round(best.score),
      amplifyVideoId: null,
      reviewCandidates: topCandidates,
    };
  }

  /**
   * Match a batch of tracks and return results with stats.
   * @param {ProviderTrack[]} tracks
   * @param {Function} onProgress  - Called after each track: onProgress(processed, total)
   * @returns {Promise<BatchMatchResult>}
   */
  static async matchBatch(tracks, onProgress = null) {
    const results = [];
    let matched = 0, review = 0, unavailable = 0;

    for (let i = 0; i < tracks.length; i++) {
      try {
        const result = await this.match(tracks[i]);
        results.push({ track: tracks[i], ...result });

        if (result.matchStatus === 'MATCHED') matched++;
        else if (result.matchStatus === 'REVIEW_REQUIRED') review++;
        else unavailable++;

        // Rate limiting: small delay between searches to avoid hammering JioSaavn
        if (i > 0 && i % 10 === 0) await this._sleep(200);

        if (onProgress) onProgress(i + 1, tracks.length);
      } catch (err) {
        console.error(`[TrackMatcher] Failed to match "${tracks[i]?.title}":`, err.message);
        results.push({
          track: tracks[i],
          matchStatus: 'UNAVAILABLE',
          confidenceScore: 0,
          amplifyVideoId: null,
          reviewCandidates: [],
        });
        unavailable++;
      }
    }

    return { results, matched, review, unavailable };
  }

  // ─── Private matching helpers ───────────────────────────────────────────

  static async _matchByIsrc(isrc) {
    // Search the catalog for a track with this ISRC in its externalIds
    // This uses a direct MongoDB query via SongStatistic or a dedicated catalog lookup
    try {
      const { SongStatistic } = require('../models/SongStatistic');
      // SongStatistic stores song snapshots; search externalIds.isrc
      const found = await SongStatistic.findOne({ 'song.externalIds.isrc': isrc }).lean();
      return found?.song || null;
    } catch (e) {
      return null;
    }
  }

  static async _matchByExternalId(source, sourceTrackId) {
    if (!source || !sourceTrackId) return null;
    try {
      const SongStatistic = require('../../models/SongStatistic');
      const field = `song.externalIds.${source}`;
      const found = await SongStatistic.findOne({ [field]: sourceTrackId }).lean();
      return found?.song || null;
    } catch (e) {
      return null;
    }
  }

  /**
   * Weighted similarity score (0-100).
   */
  static _computeScore(imported, candidate) {
    const titleSim   = this._stringSimilarity(imported.title, candidate.title);
    const artistSim  = this._stringSimilarity(imported.artist, candidate.artist);
    const albumSim   = imported.album && candidate.album
      ? this._stringSimilarity(imported.album, candidate.album)
      : 0.5; // neutral if no album info
    const durationSim = this._durationSimilarity(imported.durationMs, candidate.durationMs);

    const { title, artist, album, duration } = MATCH_CONFIG.weights;
    const score = (
      titleSim   * title   * 100 +
      artistSim  * artist  * 100 +
      albumSim   * album   * 100 +
      durationSim * duration * 100
    );

    return Math.min(100, Math.max(0, score));
  }

  /**
   * Normalized Levenshtein-based string similarity (0-1).
   * Returns 1 for identical strings (case-insensitive, punctuation-stripped).
   */
  static _stringSimilarity(a, b) {
    if (!a || !b) return 0;
    const na = this._normalizeStr(a);
    const nb = this._normalizeStr(b);
    if (na === nb) return 1;
    if (!na || !nb) return 0;

    const dist = this._levenshtein(na, nb);
    const maxLen = Math.max(na.length, nb.length);
    return 1 - dist / maxLen;
  }

  static _normalizeStr(str) {
    return str
      .toLowerCase()
      .normalize('NFD').replace(/[\u0300-\u036f]/g, '') // remove diacritics
      .replace(/\s+\(feat\..*?\)/gi, '')    // remove featuring info
      .replace(/\s+ft\..*$/gi, '')
      .replace(/\s+-\s+(radio edit|remaster|remastered|acoustic|live|remix|version|edit)/gi, '')
      .replace(/[^\w\s]/g, '')              // remove punctuation
      .replace(/\s+/g, ' ')
      .trim();
  }

  static _durationSimilarity(msA, msB) {
    if (!msA || !msB) return 0.5; // neutral if unknown
    const diff = Math.abs(msA - msB);
    if (diff > MATCH_CONFIG.maxDurationDiff) return 0;
    return 1 - diff / MATCH_CONFIG.maxDurationDiff;
  }

  static _levenshtein(a, b) {
    const m = a.length, n = b.length;
    const dp = Array.from({ length: m + 1 }, (_, i) =>
      Array.from({ length: n + 1 }, (_, j) => (i === 0 ? j : j === 0 ? i : 0))
    );
    for (let i = 1; i <= m; i++) {
      for (let j = 1; j <= n; j++) {
        dp[i][j] = a[i-1] === b[j-1]
          ? dp[i-1][j-1]
          : 1 + Math.min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1]);
      }
    }
    return dp[m][n];
  }

  static _sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

/**
 * @typedef {Object} MatchResult
 * @property {'MATCHED'|'REVIEW_REQUIRED'|'UNAVAILABLE'} matchStatus
 * @property {number} confidenceScore  - 0-100
 * @property {string|null} amplifyVideoId
 * @property {Array} reviewCandidates
 */

module.exports = TrackMatcher;
