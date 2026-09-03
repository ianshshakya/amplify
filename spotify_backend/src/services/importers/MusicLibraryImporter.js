/**
 * MusicLibraryImporter (Abstract Interface)
 * =========================================
 * Provider-independent interface for music library importers.
 * All provider implementations (Spotify, YouTube, etc.) must extend this class.
 *
 * If a provider doesn't support a method, it should throw:
 *   ImporterError('NOT_SUPPORTED', 'This provider does not support <feature>')
 *
 * Adding a new provider:
 *   1. Create a class that extends MusicLibraryImporter
 *   2. Implement all required methods (marked REQUIRED)
 *   3. Override optional methods if supported
 *   4. Register the new provider in importRoutes.js
 */

class ImporterError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'ImporterError';
    this.code = code;
  }
}

class MusicLibraryImporter {
  /**
   * REQUIRED: Validate the access token is still valid.
   * @returns {Promise<{ valid: boolean, userId: string, displayName: string }>}
   */
  async authenticate() {
    throw new ImporterError('NOT_IMPLEMENTED', 'authenticate() must be implemented');
  }

  /**
   * REQUIRED: Fetch all user playlists (paginated).
   * @param {string|null} cursor  - Pagination cursor from previous call
   * @param {number} limit        - Number of playlists per page (default 50)
   * @returns {Promise<{ playlists: ProviderPlaylist[], nextCursor: string|null }>}
   */
  async getPlaylists(cursor = null, limit = 50) {
    throw new ImporterError('NOT_IMPLEMENTED', 'getPlaylists() must be implemented');
  }

  /**
   * REQUIRED: Fetch all tracks within a specific playlist (paginated).
   * @param {string} playlistId   - Provider's playlist ID
   * @param {string|null} cursor
   * @param {number} limit
   * @returns {Promise<{ tracks: ProviderTrack[], nextCursor: string|null }>}
   */
  async getPlaylistTracks(playlistId, cursor = null, limit = 100) {
    throw new ImporterError('NOT_IMPLEMENTED', 'getPlaylistTracks() must be implemented');
  }

  /**
   * OPTIONAL: Fetch user's saved/liked library tracks.
   * @param {string|null} cursor
   * @param {number} limit
   * @returns {Promise<{ tracks: ProviderTrack[], nextCursor: string|null }>}
   */
  async getLibrary(cursor = null, limit = 50) {
    throw new ImporterError('NOT_SUPPORTED', `${this.constructor.name} does not support saved library import`);
  }

  /**
   * OPTIONAL: Fetch listening history records.
   * Note: Most providers restrict this via their API.
   * @param {string|null} cursor
   * @param {number} limit
   * @returns {Promise<{ events: HistoryEvent[], nextCursor: string|null }>}
   */
  async getListeningHistory(cursor = null, limit = 50) {
    throw new ImporterError('NOT_SUPPORTED', `${this.constructor.name} does not support listening history via API. Use file import instead.`);
  }

  /**
   * OPTIONAL: Parse an exported listening history file (JSON/CSV).
   * @param {Buffer|string} fileData  - Raw file contents
   * @param {string} format           - 'json' | 'csv'
   * @returns {Promise<HistoryEvent[]>}
   */
  async parseHistoryFile(fileData, format = 'json') {
    throw new ImporterError('NOT_SUPPORTED', `${this.constructor.name} does not support file-based history import`);
  }

  /**
   * Revoke stored tokens (for disconnect functionality).
   * @param {string} accessToken
   * @returns {Promise<void>}
   */
  async revokeToken(accessToken) {
    // Default: no-op (not all providers support server-side revocation)
    return;
  }
}

/**
 * @typedef {Object} ProviderPlaylist
 * @property {string} id           - Provider's playlist ID
 * @property {string} name         - Playlist name
 * @property {string} [description]
 * @property {string} [thumbnailUrl]
 * @property {string} [sourceUrl]
 * @property {number} totalTracks
 * @property {boolean} isPublic
 */

/**
 * @typedef {Object} ProviderTrack
 * @property {string} sourceTrackId - Provider's track ID
 * @property {string} title
 * @property {string} artist         - Primary artist name
 * @property {string[]} artists      - All artists
 * @property {string} [album]
 * @property {string} [isrc]
 * @property {number} [durationMs]
 * @property {string} [releaseDate]
 * @property {string} [thumbnailUrl]
 * @property {string} [sourceUrl]
 * @property {string[]} [playlistIds]
 * @property {number} [position]
 */

/**
 * @typedef {Object} HistoryEvent
 * @property {Date} playedAt        - When the track was played
 * @property {string} title
 * @property {string} artist
 * @property {string} [album]
 * @property {number} [durationMs]
 * @property {number} [msPlayed]    - How many ms were actually played
 */

module.exports = { MusicLibraryImporter, ImporterError };
