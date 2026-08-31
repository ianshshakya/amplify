/**
 * MusicProvider
 * =============
 * Abstraction layer over JioSaavn (saavn.js).
 * All recommendation and playlist logic should call MusicProvider,
 * NOT saavn.js directly. This keeps JioSaavn internals isolated so
 * Amplify could support another licensed provider without touching
 * the recommendation engine.
 *
 * Every method returns normalized AmplifyTrack objects.
 */

const {
  searchSaavn,
  searchSaavnWithFilters,
  getPlaylistTracks,
  getRelatedTracks,
  fetchSpotifyPlaylistTracks,
} = require('../utils/saavn');

const { normalizeTracks, deduplicateTracks } = require('./AmplifyNormalizer');
const { metadataCache } = require('../utils/cache');

class MusicProvider {
  /**
   * Search for tracks by keyword query.
   * @param {string} query
   * @param {number} limit
   * @param {object} options - { language?, minYear?, maxYear? }
   * @returns {Promise<AmplifyTrack[]>}
   */
  static async search(query, limit = 20, options = {}) {
    const cacheKey = `search_${query}_${limit}_${JSON.stringify(options)}`;
    const cached = metadataCache.get(cacheKey);
    if (cached) return cached;

    try {
      let raw;
      if (options.language || options.minYear || options.maxYear) {
        raw = await searchSaavnWithFilters(query, limit, options);
      } else {
        raw = await searchSaavn(query, limit);
      }
      const normalized = normalizeTracks(raw);
      if (normalized.length > 0) metadataCache.set(cacheKey, normalized);
      return normalized;
    } catch (err) {
      if (process.env.NODE_ENV !== 'production') console.error(`[MusicProvider] search("${query}") failed:`, err.message);
      return [];
    }
  }

  /**
   * Run multiple search queries and merge results into a single deduplicated pool.
   * Useful for multi-strategy playlists (e.g., 80s & 90s Retro).
   * @param {string[]} queries
   * @param {number} limitPerQuery
   * @param {object} options
   * @returns {Promise<AmplifyTrack[]>}
   */
  static async multiSearch(queries, limitPerQuery = 30, options = {}) {
    const results = await Promise.all(
      queries.map(q => this.search(q, limitPerQuery, options).catch(() => []))
    );
    const merged = results.flat();
    return deduplicateTracks(merged);
  }

  /**
   * Get tracks from a JioSaavn playlist by numeric ID.
   * @param {string} playlistId
   * @param {number} limit
   * @returns {Promise<AmplifyTrack[]>}
   */
  static async getPlaylist(playlistId, limit = 50) {
    try {
      const raw = await getPlaylistTracks(playlistId, limit);
      return normalizeTracks(raw);
    } catch (err) {
      console.error(`[MusicProvider] getPlaylist(${playlistId}) failed:`, err.message);
      return [];
    }
  }

  /**
   * Get related tracks for a given JioSaavn song ID.
   * @param {string} songId
   * @param {number} limit
   * @returns {Promise<AmplifyTrack[]>}
   */
  static async getRelated(songId, limit = 20) {
    try {
      const raw = await getRelatedTracks(songId, limit);
      return normalizeTracks(raw);
    } catch (err) {
      console.error(`[MusicProvider] getRelated(${songId}) failed:`, err.message);
      return [];
    }
  }

  /**
   * Cross-reference a Spotify playlist URL and map tracks to JioSaavn.
   * @param {string|string[]} spotifyUrls - One or more Spotify playlist URLs
   * @param {number} limit
   * @param {string} fallbackSaavnId
   * @returns {Promise<AmplifyTrack[]>}
   */
  static async getSpotifyPlaylist(spotifyUrls, limit = 100, fallbackSaavnId = null) {
    const urls = Array.isArray(spotifyUrls) ? spotifyUrls : [spotifyUrls];
    const allTracks = [];

    for (const url of urls) {
      try {
        const raw = await fetchSpotifyPlaylistTracks(url, limit, fallbackSaavnId);
        allTracks.push(...normalizeTracks(raw));
      } catch (err) {
        console.error(`[MusicProvider] getSpotifyPlaylist(${url}) failed:`, err.message);
      }
    }

    return deduplicateTracks(allTracks).slice(0, limit);
  }

  /**
   * Mainstream fallback: returns well-known popular songs for a given language.
   * Used by the FallbackLadder when all other strategies fail.
   * @param {string} language - 'Hindi', 'English', 'Punjabi', etc.
   * @param {number} limit
   * @returns {Promise<AmplifyTrack[]>}
   */
  static async getMainstreamFallback(language = 'English', limit = 30) {
    const cacheKey = `fallback_${language}_${limit}`;
    const cached = metadataCache.get(cacheKey);
    if (cached) return cached;

    const queries = {
      Hindi: ['Arijit Singh top hits', 'Bollywood hits 2023 2024', 'Hindi top songs'],
      English: ['Top English hits 2024', 'Popular English songs', 'Billboard top songs'],
      Punjabi: ['Diljit Dosanjh hits', 'AP Dhillon top songs', 'Punjabi top hits'],
      Tamil: ['Tamil hits 2024', 'AR Rahman Tamil', 'Tamil top songs'],
      Telugu: ['Telugu hits 2024', 'Tollywood top songs'],
    };
    const searchQueries = queries[language] || queries['English'];
    const results = await this.multiSearch(searchQueries, Math.ceil(limit / searchQueries.length));
    
    if (results.length > 0) metadataCache.set(cacheKey, results);
    return results;
  }
}

module.exports = MusicProvider;
