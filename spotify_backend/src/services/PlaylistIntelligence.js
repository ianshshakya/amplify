/**
 * PlaylistIntelligence
 * ====================
 * The main orchestrator for Amplify's music recommendation pipeline.
 *
 * Architecture:
 *   Intent → CandidatePool → HardFilter → Scoring → Diversity → Sequence → Validation → Fallback → Result
 *
 * Public API:
 *   PlaylistIntelligence.generate(input, userId?, options?)     → playlist with songs
 *   PlaylistIntelligence.getRadioTracks(seedTrack, sessionCtx) → radio queue
 *   PlaylistIntelligence.getSimilar(seedTrack, userId?)        → similar songs
 *   PlaylistIntelligence.discover(userId)                       → discovery playlist
 */

const { parseIntent, generateSearchQueries } = require('./PlaylistIntentEngine');
const CandidateGenerator = require('./CandidateGenerator');
const ScoringEngine = require('./ScoringEngine');
const { DiversityController, SequenceBuilder } = require('./DiversityController');
const { QualityValidator, FallbackLadder } = require('./QualityValidator');
const MusicProvider = require('./MusicProvider');
const { deduplicateTracks, normalizeTrack } = require('./AmplifyNormalizer');
const UserMusicProfile = require('../models/UserMusicProfile');
const DynamicPlaylist = require('../models/DynamicPlaylist');
const PersonalizedAutoplayEngine = require('./PersonalizedAutoplayEngine');

// In-memory recommendation cache (TTL: 30 min per user+intent)
const recommendationCache = new Map();
const CACHE_TTL_MS = 30 * 60 * 1000;

function getCacheKey(userId, intentKey) {
  return `${userId || 'anon'}::${intentKey}`;
}

function getCached(key) {
  const item = recommendationCache.get(key);
  if (!item) return null;
  if (Date.now() > item.expiry) {
    recommendationCache.delete(key);
    return null;
  }
  return item.value;
}

function setCache(key, value) {
  recommendationCache.set(key, { value, expiry: Date.now() + CACHE_TTL_MS });
}

/**
 * Strip _scoring debug fields from tracks before sending to client.
 * In debug mode, keep them.
 */
function formatForClient(tracks, debugMode = false) {
  return tracks.map(t => {
    const formatted = {
      videoId: t.videoId,
      title: t.title,
      artist: t.artist,
      thumbnailUrl: t.thumbnailUrl,
      durationMs: t.durationMs || (t.duration ? t.duration * 1000 : 0),
      source: t.source || 'saavn',
      language: t.language || undefined,
      releaseYear: t.releaseYear || undefined,
    };
    if (debugMode && t._scoring) {
      formatted._debug = t._scoring;
    }
    return formatted;
  });
}

class PlaylistIntelligence {
  /**
   * Generate a playlist from a playlist config, name, or structured intent.
   *
   * @param {object|string} input - Playlist config (from playlists.js) or free-form string
   * @param {string|null} userId - For personalization
   * @param {object} options - { targetCount?, debugMode?, forceRefresh? }
   * @returns {Promise<{ songs: object[], meta: object }>}
   */
  static async generate(input, userId = null, options = {}) {
    const { targetCount = 30, debugMode = false, forceRefresh = false } = options;
    const playlistConfig = (typeof input === 'object') ? input : null;

    // ── Parse intent ─────────────────────────────────────────────────────────
    const intent = parseIntent(input);
    const intentKey = `${intent.purpose}::${intent.languages.join(',')}::${intent.era || ''}`;
    const cacheKey = getCacheKey(userId, intentKey);

    if (!forceRefresh) {
      const cached = getCached(cacheKey);
      if (cached) {
        console.log(`[PlaylistIntelligence] Cache hit for: ${intentKey}`);
        return cached;
      }
    }

    console.log(`[PlaylistIntelligence] Generating: ${intentKey} (target: ${targetCount})`);

    // ── Load user profile ─────────────────────────────────────────────────────
    let userProfile = null;
    if (userId) {
      try {
        userProfile = await UserMusicProfile.findOne({ userId });
      } catch (e) {
        console.warn('[PlaylistIntelligence] Failed to load user profile:', e.message);
      }
    }

    // ── Generate candidate pool ───────────────────────────────────────────────
    let candidates = await CandidateGenerator.generatePool(intent, playlistConfig, userProfile);

    // ── Hard filter: remove tracks that violate hard constraints ──────────────
    candidates = this._hardFilter(candidates, intent);
    console.log(`[PlaylistIntelligence] After hard filter: ${candidates.length} candidates`);

    // ── Score candidates ──────────────────────────────────────────────────────
    const scored = ScoringEngine.score(candidates, intent, userProfile);

    // ── Apply diversity rules ─────────────────────────────────────────────────
    const diverse = DiversityController.select(scored, intent, targetCount);
    console.log(`[PlaylistIntelligence] After diversity: ${diverse.length} tracks`);

    // ── Sequence the playlist ─────────────────────────────────────────────────
    const sequenced = SequenceBuilder.sequence(diverse, intent);

    // ── Validate result ───────────────────────────────────────────────────────
    const validation = QualityValidator.validate(sequenced, intent);
    console.log(`[PlaylistIntelligence] Validation: pass=${validation.pass}, score=${validation.score}`);
    if (validation.warnings.length > 0) {
      console.warn('[PlaylistIntelligence] Warnings:', validation.warnings.join('; '));
    }

    let finalTracks = sequenced;
    let fallbackLevel = 0;
    let fallbackReason = null;

    // ── Fallback if validation failed ─────────────────────────────────────────
    if (!validation.pass) {
      console.log(`[PlaylistIntelligence] Validation failed: ${validation.issues.join('; ')}. Running fallback...`);
      const fallback = await FallbackLadder.run(intent, targetCount, userProfile);
      finalTracks = fallback.tracks;
      fallbackLevel = fallback.fallbackLevel;
      fallbackReason = fallback.fallbackReason;
      console.log(`[PlaylistIntelligence] Fallback level ${fallbackLevel}: ${fallbackReason}`);
    }

    const result = {
      songs: formatForClient(finalTracks, debugMode),
      meta: {
        intentKey,
        purpose: intent.purpose,
        languages: intent.languages,
        era: intent.era,
        candidateCount: candidates.length,
        finalCount: finalTracks.length,
        validationScore: validation.score,
        validationIssues: validation.issues,
        validationWarnings: validation.warnings,
        fallbackLevel,
        fallbackReason,
      },
    };

    setCache(cacheKey, result);
    return result;
  }

  /**
   * Generate the next batch of radio tracks from a seed song.
   * Uses CandidateGenerator.generateRadioPool.
   *
   * @param {object} seedTrack - AmplifyTrack (with videoId, artist, etc.)
   * @param {object} sessionContext - { recentSongIds: [], recentArtists: [] }
   * @param {string|null} userId
   * @param {number} limit
   * @returns {Promise<object[]>}
   */
  static async getRadioTracks(seedTrack, sessionContext = {}, userId = null, limit = 15) {
    let userProfile = null;
    if (userId) {
      userProfile = await UserMusicProfile.findOne({ userId }).catch(() => null);
    }

    return PersonalizedAutoplayEngine.getNextTracks(seedTrack, userProfile, sessionContext, limit);
  }

  /**
   * Get songs similar to the given track.
   */
  static async getSimilar(seedTrack, userId = null, limit = 20) {
    return this.getRadioTracks(seedTrack, {}, userId, limit);
  }

  /**
   * Generate a personalised discovery playlist for a user.
   */
  static async discover(userId, limit = 25) {
    const discoveryInput = { id: 'discover', title: 'Discover New Music', intent: { purpose: 'discover', discovery: 'high' } };
    const result = await this.generate(discoveryInput, userId, { targetCount: limit });
    return result;
  }

  /**
   * Hard filter: remove candidates that clearly violate intent constraints.
   * This is different from scoring — these are binary YES/NO rejections.
   */
  static _hardFilter(candidates, intent) {
    return candidates.filter(track => {
      // Must have a valid videoId
      if (!track.videoId || track.videoId.trim() === '') return false;
      // Must have a title
      if (!track.title || track.title === 'Unknown Title') return false;
      return true;
      // Note: We do NOT hard-filter on language/era here — those are handled
      // via scoring penalties and the quality validator. Hard filtering too
      // aggressively causes empty playlists for edge-case requests.
    });
  }
}

module.exports = PlaylistIntelligence;
