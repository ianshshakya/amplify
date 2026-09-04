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
  // YouTube music videos often have 20-60s intros/outros/skits, so this needs to be generous
  maxDurationDiff: 60000, 
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

    // ── Log the raw data coming in from the provider ──
    console.log(`[TrackMatcher] ► RAW from ${source || 'unknown'}:`);
    console.log(`  title:  "${title}"`);
    console.log(`  artist: "${artist}"`);
    console.log(`  durationMs: ${durationMs}`);

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
    let cleanTitle = title || '';
    let cleanArtist = artist || '';
    
    if (source === 'youtube') {
      cleanTitle = cleanTitle
        .split('|')[0]            // strip everything after first pipe (cast/crew)
        // Removed aggressive hyphen stripping which broke "Artist - Song" formats
        .replace(/\(.*?(official|lyric|audio|video|music|visualizer).*?\)/gi, '')
        .replace(/\[.*?(official|lyric|audio|video|music|visualizer).*?\]/gi, '')
        .trim();
      cleanArtist = cleanArtist
        .replace(/vevo/gi, '')
        .replace(/ - Topic/gi, '')
        .trim();

      // If title is "Artist - Song", smartly extract just the song
      if (cleanTitle.includes('-')) {
        const parts = cleanTitle.split('-');
        const possibleArtist = parts[0].trim().toLowerCase();
        const artistLower = cleanArtist.toLowerCase();
        // If the part before the hyphen is the channel name or contains the artist name
        if (possibleArtist.includes(artistLower) || artistLower.includes(possibleArtist) || possibleArtist.length < 3) {
          cleanTitle = parts.slice(1).join('-').trim();
        }
      }
    }
    
    // Create a cleaned track for scoring.
    // rawTitle carries the original full YouTube title so the artist/title
    // boost in _computeScore can still look up singer names inside it.
    const cleanImported = {
      ...importedTrack,
      title:    cleanTitle || title,
      artist:   cleanArtist || artist,
      rawTitle: title,   // keep original for boost lookups
    };

    // ── Log the cleaned format going into the search + scorer ──
    console.log(`[TrackMatcher] ► CLEANED for search:`);
    console.log(`  cleanTitle:  "${cleanImported.title}"`);
    console.log(`  cleanArtist: "${cleanImported.artist}"`);
    
    const searchQuery = `${cleanTitle} ${cleanArtist}`.substring(0, 60).trim();
    console.log(`  searchQuery: "${searchQuery}"`);

    // Wrap search in a timeout to prevent hanging on slow JioSaavn responses
    const searchWithTimeout = (q, n) => Promise.race([
      MusicProvider.search(q, n),
      new Promise((_, reject) => setTimeout(() => reject(new Error('search timeout')), 10000)),
    ]).catch(err => {
      console.warn(`[TrackMatcher] search("${q}") failed/timed out: ${err.message}`);
      return [];
    });

    let candidates = await searchWithTimeout(searchQuery, 10);

    // ── Fallback search strategies if primary returns nothing ─────────────
    if (!candidates || candidates.length === 0) {
      console.log(`[TrackMatcher] Primary search returned 0, trying title-only fallback...`);
      // Try title-only (drop the noisy YouTube channel name as artist)
      candidates = await searchWithTimeout(cleanTitle.substring(0, 50), 10);
    }
    if (!candidates || candidates.length === 0) {
      // Last resort: just the first significant word of the title
      const firstWord = cleanTitle.split(/\s+/).find(w => w.length > 3);
      if (firstWord) {
        console.log(`[TrackMatcher] Title-only returned 0, trying first-word fallback: "${firstWord}"...`);
        candidates = await searchWithTimeout(firstWord, 10);
      }
    }

    console.log(`[TrackMatcher] ► JioSaavn candidates: ${candidates?.length || 0}`);
    if (candidates && candidates.length > 0) {
      console.log(`  top: "${candidates[0].title}" by "${candidates[0].artist}"`);
    }

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
      score: this._computeScore(cleanImported, candidate),
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
      console.log(`[TrackMatcher] ✅ MATCHED  score=${Math.round(best.score)}  → "${best.title}" by "${best.artist}"`);
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
    let titleSim   = this._stringSimilarity(imported.title, candidate.title);
    
    // ── YouTube specific boosts ──
    // YouTube titles contain extreme fluff (movie names, actors).
    // Use rawTitle (the original full YouTube title) for boost lookups.
    const lookupTitle = imported.rawTitle || imported.title;
    if (titleSim < 0.85 && lookupTitle) {
      const rawTitleLower = lookupTitle.toLowerCase();
      const candTitleLower = candidate.title.toLowerCase();
      // If candidate title is exactly in the YouTube title
      if (candTitleLower.length > 2 && rawTitleLower.includes(candTitleLower)) {
        titleSim = Math.max(titleSim, 0.9);
      }
    }
    
    let artistSim  = this._stringSimilarity(imported.artist, candidate.artist);
    // ── YouTube specific boost ──
    // YouTube often puts the record label as the artist (e.g., T-Series, Sony Music)
    // and puts the actual singers in the video title.
    if (artistSim < 0.8 && lookupTitle) {
      const rawTitleLower = lookupTitle.toLowerCase();
      // Candidate artist can be comma-separated like "Pritam, Arijit Singh"
      const candidateArtists = candidate.artist.split(',').map(a => a.trim().toLowerCase());
      for (const ca of candidateArtists) {
        if (ca && rawTitleLower.includes(ca)) {
          artistSim = 0.9; // Singer found in the original video title
          break;
        }
      }
    }
    
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
