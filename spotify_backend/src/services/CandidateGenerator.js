/**
 * CandidateGenerator
 * ==================
 * Generates a large candidate pool for a playlist request by pulling from
 * multiple sources and deduplicating the results.
 *
 * Sources (in priority order):
 *   1. Primary intent-driven searches (from PlaylistIntentEngine queries)
 *   2. Pre-seeded DynamicPlaylist database (near-instant, no API calls)
 *   3. User's top affinity artists (personalized candidates)
 *   4. JioSaavn playlist by ID (for 'playlist' strategy configs)
 *   5. Spotify cross-reference (for 'spotify' strategy configs)
 *   6. Mainstream fallback (last resort, always returns something)
 *
 * The goal is to produce 60–200 candidates so the scoring engine
 * has enough material to find the best 20–50 songs.
 */

const MusicProvider = require('./MusicProvider');
const { deduplicateTracks } = require('./AmplifyNormalizer');
const { generateSearchQueries } = require('./PlaylistIntentEngine');
const DynamicPlaylist = require('../models/DynamicPlaylist');
const { normalizeTrack } = require('./AmplifyNormalizer');

const TARGET_POOL_SIZE = 150; // Aim for this many candidates before scoring

class CandidateGenerator {
  /**
   * Generate a candidate pool for a given PlaylistIntent.
   *
   * @param {PlaylistIntent} intent - From PlaylistIntentEngine.parseIntent()
   * @param {object} playlistConfig - Optional: the full playlist config from playlists.js
   * @param {object} userProfile - Optional: UserMusicProfile for personalization
   * @param {object} sessionContext - Optional: { recentArtists: [], recentSongIds: [] }
   * @returns {Promise<AmplifyTrack[]>}
   */
  static async generatePool(intent, playlistConfig = null, userProfile = null, sessionContext = null) {
    const allCandidates = [];

    // ── Source 1: Pre-seeded DynamicPlaylist database ───────────────────────
    // This is the fastest source — already in MongoDB, no API call needed
    try {
      const dbTracks = await this._getFromDatabase(intent, playlistConfig);
      if (dbTracks.length > 0) {
        allCandidates.push(...dbTracks);
        if (process.env.NODE_ENV !== 'production') console.log(`[CandidateGen] DB source: ${dbTracks.length} tracks`);
      }
    } catch (e) {
      console.warn('[CandidateGen] DB source failed:', e.message);
    }

    // ── Source 2: Intent-driven JioSaavn search ──────────────────────────────
    if (allCandidates.length < TARGET_POOL_SIZE) {
      try {
        const searchTracks = await this._searchByIntent(intent, playlistConfig);
        allCandidates.push(...searchTracks);
        if (process.env.NODE_ENV !== 'production') console.log(`[CandidateGen] Search source: ${searchTracks.length} tracks`);
      } catch (e) {
        console.warn('[CandidateGen] Search source failed:', e.message);
      }
    }

    // ── Source 3: Personalized artist searches ────────────────────────────────
    if (userProfile && allCandidates.length < TARGET_POOL_SIZE) {
      try {
        const personalTracks = await this._getPersonalizedCandidates(userProfile, intent);
        allCandidates.push(...personalTracks);
        if (process.env.NODE_ENV !== 'production') console.log(`[CandidateGen] Personal source: ${personalTracks.length} tracks`);
      } catch (e) {
        console.warn('[CandidateGen] Personal source failed:', e.message);
      }
    }

    // ── Source 4: Mainstream fallback (ensure enough songs) ──────────────────
    if (allCandidates.length < 20) {
      if (process.env.NODE_ENV !== 'production') console.log(`[CandidateGen] Low candidate count (${allCandidates.length}), using mainstream fallback`);
      try {
        const lang = intent.languages.length > 0 ? intent.languages[0] : 'Hindi';
        const fallback = await MusicProvider.getMainstreamFallback(lang, 40);
        allCandidates.push(...fallback);
      } catch (e) {
        console.warn('[CandidateGen] Mainstream fallback failed:', e.message);
      }
    }

    // ── Deduplicate and return ────────────────────────────────────────────────
    const deduplicated = deduplicateTracks(allCandidates);
    if (process.env.NODE_ENV !== 'production') console.log(`[CandidateGen] Final pool: ${deduplicated.length} unique candidates`);
    return deduplicated;
  }

  /**
   * Get tracks from the pre-seeded DynamicPlaylist database.
   * Pulls from playlists that match the intent's language/purpose.
   */
  static async _getFromDatabase(intent, playlistConfig) {
    const results = [];

    // If we have a direct playlist config, use that playlist's DB entry
    if (playlistConfig && playlistConfig.id) {
      const dbPlaylist = await DynamicPlaylist.findOne({ playlistId: playlistConfig.id });
      if (dbPlaylist && dbPlaylist.songs && dbPlaylist.songs.length > 0) {
        const normalized = dbPlaylist.songs.map(s => normalizeTrack({
          ...s.toObject(),
          duration: s.durationMs ? Math.round(s.durationMs / 1000) : 0,
        }));
        results.push(...normalized);
        return results;
      }
    }

    // Also pull from semantically related playlists based on intent
    const relatedIds = this._getRelatedPlaylistIds(intent);
    for (const id of relatedIds) {
      const dbPlaylist = await DynamicPlaylist.findOne({ playlistId: id });
      if (dbPlaylist && dbPlaylist.songs) {
        const normalized = dbPlaylist.songs.map(s => normalizeTrack({
          ...s.toObject(),
          duration: s.durationMs ? Math.round(s.durationMs / 1000) : 0,
        }));
        results.push(...normalized);
      }
    }

    return results;
  }

  /**
   * Search JioSaavn using queries derived from the intent.
   */
  static async _searchByIntent(intent, playlistConfig) {
    const queries = generateSearchQueries(intent, playlistConfig);
    const limitPerQuery = Math.ceil(TARGET_POOL_SIZE / Math.max(queries.length, 1));
    const options = {
      language: intent.languages.length === 1 ? intent.languages[0] : null,
      minYear: intent.eraYears ? intent.eraYears.min : null,
      maxYear: intent.eraYears ? intent.eraYears.max : null,
    };

    // Run primary queries in parallel (up to 4 at once)
    const primaryQueries = queries.slice(0, 4);
    const results = await Promise.all(
      primaryQueries.map(q => MusicProvider.search(q, limitPerQuery, options).catch(() => []))
    );

    const merged = results.flat();

    // Run secondary queries sequentially if pool is still small
    if (merged.length < 40 && queries.length > 4) {
      for (const q of queries.slice(4)) {
        const extra = await MusicProvider.search(q, limitPerQuery, options).catch(() => []);
        merged.push(...extra);
        if (merged.length >= TARGET_POOL_SIZE) break;
      }
    }

    return merged;
  }

  /**
   * Generate personalized candidate tracks from user's artist affinities.
   */
  static async _getPersonalizedCandidates(userProfile, intent) {
    if (!userProfile || !userProfile.artistAffinity) return [];

    // Get top 3 artists by affinity score
    const affinityMap = userProfile.artistAffinity instanceof Map
      ? Object.fromEntries(userProfile.artistAffinity)
      : userProfile.artistAffinity;

    const topArtists = Object.entries(affinityMap)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 3)
      .map(e => e[0]);

    const results = [];
    for (const artist of topArtists) {
      const tracks = await MusicProvider.search(`${artist} best songs`, 20).catch(() => []);
      results.push(...tracks);
    }

    return results;
  }

  /**
   * Map an intent to semantically related pre-seeded playlist IDs.
   * This allows fast candidate retrieval from MongoDB without API calls.
   */
  static _getRelatedPlaylistIds(intent) {
    const { purpose, languages, era } = intent;
    const ids = [];

    // Language → related playlists
    if (languages.includes('Hindi')) ids.push('indiantop50', 'newhindi', 'oldbollywood', 'arijitsingh');
    if (languages.includes('English')) ids.push('global100', 'pophits', 'taylorswift', 'theweeknd', 'oldglobal');
    if (languages.includes('Punjabi')) ids.push('punjabihits');

    // Purpose → related mood playlists
    if (purpose === 'workout') ids.push('workout');
    if (purpose === 'party') ids.push('party', 'punjabihits');
    if (purpose === 'chill') ids.push('chill', 'relax');
    if (purpose === 'focus') ids.push('focus', 'indianclassic', 'globalclassic');
    if (purpose === 'relax') ids.push('relax', 'chill');
    if (purpose === 'romance') ids.push('romance', 'arijitsingh', 'shreyaghoshal');
    if (purpose === 'hip-hop') ids.push('hip-hop');
    if (purpose === 'charts') ids.push('global100', 'indiantop50');

    // Era → related playlists
    if (era && (era.includes('1990s') || era.includes('1980s'))) {
      ids.push('oldbollywood', 'oldglobal', 'kishorekumar');
    }

    // Remove duplicates
    return [...new Set(ids)];
  }

  /**
   * Generate candidates for "similar to this song" radio.
   * Uses JioSaavn's related tracks API + artist search.
   */
  static async generateRadioPool(seedTrack, userProfile = null, sessionContext = null) {
    const allCandidates = [];

    // Source 1: JioSaavn related tracks (station-based)
    const related = await MusicProvider.getRelated(seedTrack.videoId, 40).catch(() => []);
    allCandidates.push(...related);

    // Source 2: Same artist songs
    if (seedTrack.primaryArtist || seedTrack.artist) {
      const artistName = seedTrack.primaryArtist || seedTrack.artist.split(',')[0].trim();
      const artistTracks = await MusicProvider.search(`${artistName} best songs`, 30).catch(() => []);
      allCandidates.push(...artistTracks);
    }

    // Source 3: Session context — blend recent artists
    if (sessionContext && sessionContext.recentArtists && sessionContext.recentArtists.length > 0) {
      const recentArtist = sessionContext.recentArtists[0];
      if (recentArtist && recentArtist !== (seedTrack.primaryArtist || '')) {
        const contextTracks = await MusicProvider.search(`${recentArtist} best songs`, 20).catch(() => []);
        allCandidates.push(...contextTracks);
      }
    }

    // Filter out the seed song and recently played songs
    const recentIds = new Set(sessionContext ? (sessionContext.recentSongIds || []) : []);
    recentIds.add(seedTrack.videoId);

    const filtered = allCandidates.filter(t => !recentIds.has(t.videoId));
    return deduplicateTracks(filtered);
  }

  /**
   * Generate candidates for Personalized Autoplay (true continuous playback).
   * Pulls from multiple sources to build a diverse pool for the ScoringEngine.
   */
  static async generateAutoplayPool(seedTrack, userProfile = null, sessionContext = null) {
    const allCandidates = [];
    
    // Source 1: Similar to current song (JioSaavn related tracks)
    const related = await MusicProvider.getRelated(seedTrack.videoId, 40).catch(() => []);
    allCandidates.push(...related);

    // Source 2: Same artist as current song
    if (seedTrack.primaryArtist || seedTrack.artist) {
      const artistName = seedTrack.primaryArtist || seedTrack.artist.split(',')[0].trim();
      const artistTracks = await MusicProvider.search(`${artistName} best songs`, 30).catch(() => []);
      allCandidates.push(...artistTracks);
    }

    // Source 3: User's top artists
    if (userProfile && userProfile.artistAffinity) {
      const affinityMap = userProfile.artistAffinity instanceof Map
        ? Object.fromEntries(userProfile.artistAffinity)
        : userProfile.artistAffinity;
      
      const topArtists = Object.entries(affinityMap)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 3)
        .map(e => e[0]);
      
      for (const artist of topArtists) {
        if (artist !== (seedTrack.primaryArtist || '')) {
          const tracks = await MusicProvider.search(`${artist} hits`, 15).catch(() => []);
          allCandidates.push(...tracks);
        }
      }
    }

    // Source 4: Session Context (recent artists)
    if (sessionContext && sessionContext.recentArtists) {
      for (const recentArtist of sessionContext.recentArtists.slice(0, 2)) {
        if (recentArtist !== (seedTrack.primaryArtist || '')) {
          const contextTracks = await MusicProvider.search(`${recentArtist} best songs`, 15).catch(() => []);
          allCandidates.push(...contextTracks);
        }
      }
    }

    // Source 5: User's top language/genre fallback
    if (userProfile && userProfile.languageAffinity) {
      const langMap = userProfile.languageAffinity instanceof Map
        ? Object.fromEntries(userProfile.languageAffinity)
        : userProfile.languageAffinity;
        
      const topLang = Object.keys(langMap).sort((a, b) => langMap[b] - langMap[a])[0];
      if (topLang) {
        const fallback = await MusicProvider.getMainstreamFallback(topLang, 30).catch(() => []);
        allCandidates.push(...fallback);
      }
    }

    // Filter out the seed song and recently played songs
    const recentIds = new Set(sessionContext ? (sessionContext.recentSongIds || []) : []);
    recentIds.add(seedTrack.videoId);

    const filtered = allCandidates.filter(t => !recentIds.has(t.videoId));
    return deduplicateTracks(filtered);
  }
}

module.exports = CandidateGenerator;
