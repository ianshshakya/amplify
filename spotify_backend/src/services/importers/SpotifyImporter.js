/**
 * SpotifyImporter
 * ===============
 * Implements MusicLibraryImporter for the Spotify Web API.
 *
 * OAuth flow: PKCE (server-side) or Authorization Code
 * Required scopes:
 *   - user-library-read        → Saved tracks
 *   - playlist-read-private    → Private playlists
 *   - playlist-read-collaborative → Collaborative playlists
 *   - user-read-recently-played → Last 50 recently played
 *   - user-top-read            → Top artists/tracks
 *
 * ⚠️  IMPORTANT: Spotify's Web API does NOT expose full historical
 *     listening data. Only the last 50 recently-played tracks are available.
 *     For full history, users must use "Request Your Data" on Spotify's
 *     privacy page and import the resulting JSON files via parseHistoryFile().
 *
 * API docs: https://developer.spotify.com/documentation/web-api
 */

const axios = require('axios');
const { MusicLibraryImporter, ImporterError } = require('./MusicLibraryImporter');

const SPOTIFY_API_BASE = 'https://api.spotify.com/v1';
const SPOTIFY_TOKEN_URL = 'https://accounts.spotify.com/api/token';
const SPOTIFY_AUTH_URL = 'https://accounts.spotify.com/authorize';

// Required scopes for Amplify import functionality
const SPOTIFY_SCOPES = [
  'user-library-read',
  'playlist-read-private',
  'playlist-read-collaborative',
  'user-read-recently-played',
  'user-top-read',
  'user-read-private',
  'user-read-email',
].join(' ');

class SpotifyImporter extends MusicLibraryImporter {
  constructor(accessToken) {
    super();
    this.accessToken = accessToken;
    this._api = axios.create({
      baseURL: SPOTIFY_API_BASE,
      headers: { Authorization: `Bearer ${accessToken}` },
    });
  }

  // ─── Static OAuth helpers ────────────────────────────────────────────────

  /**
   * Build the Spotify OAuth authorization URL.
   * @param {string} state  - CSRF state token
   * @returns {string} Authorization URL to redirect the user to
   */
  static buildAuthUrl(state) {
    const params = new URLSearchParams({
      response_type: 'code',
      client_id: process.env.SPOTIFY_CLIENT_ID,
      scope: SPOTIFY_SCOPES,
      redirect_uri: process.env.SPOTIFY_REDIRECT_URI,
      state,
      show_dialog: 'true',
    });
    return `${SPOTIFY_AUTH_URL}?${params.toString()}`;
  }

  /**
   * Exchange authorization code for access + refresh tokens.
   * @param {string} code
   * @returns {Promise<{ accessToken, refreshToken, expiresIn, scope }>}
   */
  static async exchangeCode(code) {
    const params = new URLSearchParams({
      grant_type: 'authorization_code',
      code,
      redirect_uri: process.env.SPOTIFY_REDIRECT_URI,
    });

    const credentials = Buffer.from(
      `${process.env.SPOTIFY_CLIENT_ID}:${process.env.SPOTIFY_CLIENT_SECRET}`
    ).toString('base64');

    try {
      const res = await axios.post(SPOTIFY_TOKEN_URL, params.toString(), {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': `Basic ${credentials}`,
        },
      });

      return {
        accessToken:  res.data.access_token,
        refreshToken: res.data.refresh_token,
        expiresIn:    res.data.expires_in, // seconds
        scope:        res.data.scope,
      };
    } catch (err) {
      const detail = err.response?.data?.error_description || err.message;
      throw new ImporterError('OAUTH_ERROR', `Spotify token exchange failed: ${detail}`);
    }
  }

  /**
   * Refresh an expired access token.
   * @param {string} refreshToken (encrypted at rest, decrypted before calling)
   * @returns {Promise<{ accessToken, expiresIn }>}
   */
  static async refreshToken(refreshToken) {
    const params = new URLSearchParams({
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
    });

    const credentials = Buffer.from(
      `${process.env.SPOTIFY_CLIENT_ID}:${process.env.SPOTIFY_CLIENT_SECRET}`
    ).toString('base64');

    try {
      const res = await axios.post(SPOTIFY_TOKEN_URL, params.toString(), {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': `Basic ${credentials}`,
        },
      });

      return {
        accessToken: res.data.access_token,
        expiresIn:   res.data.expires_in,
      };
    } catch (err) {
      throw new ImporterError('TOKEN_EXPIRED', 'Spotify connection expired. Please reconnect your Spotify account.');
    }
  }

  // ─── Interface implementation ────────────────────────────────────────────

  async authenticate() {
    try {
      const res = await this._api.get('/me');
      return {
        valid: true,
        userId: res.data.id,
        displayName: res.data.display_name || res.data.id,
        email: res.data.email,
      };
    } catch (err) {
      if (err.response?.status === 401) {
        throw new ImporterError('TOKEN_EXPIRED', 'Spotify connection expired. Please reconnect.');
      }
      throw new ImporterError('AUTH_ERROR', `Spotify authentication failed: ${err.message}`);
    }
  }

  async getPlaylists(cursor = null, limit = 50) {
    try {
      const offset = cursor ? parseInt(cursor, 10) : 0;
      const res = await this._api.get('/me/playlists', {
        params: { limit, offset },
      });

      const playlists = res.data.items.map(p => ({
        id:          p.id,
        name:        p.name,
        description: p.description || '',
        thumbnailUrl: p.images?.[0]?.url || '',
        sourceUrl:   p.external_urls?.spotify || '',
        totalTracks: p.tracks?.total || 0,
        isPublic:    p.public || false,
      }));

      const nextOffset = res.data.next ? offset + limit : null;
      return {
        playlists,
        nextCursor: nextOffset !== null ? String(nextOffset) : null,
      };
    } catch (err) {
      this._handleApiError(err, 'getPlaylists');
    }
  }

  async getPlaylistTracks(playlistId, cursor = null, limit = 100) {
    try {
      const offset = cursor ? parseInt(cursor, 10) : 0;
      const res = await this._api.get(`/playlists/${playlistId}/tracks`, {
        params: {
          limit,
          offset,
          fields: 'items(track(id,name,artists,album,duration_ms,external_ids,preview_url,external_urls)),next',
        },
      });

      const tracks = res.data.items
        .filter(item => item.track && item.track.id) // filter out null/podcast tracks
        .map((item, index) => this._normalizeTrack(item.track, playlistId, offset + index));

      const nextOffset = res.data.next ? offset + limit : null;
      return {
        tracks,
        nextCursor: nextOffset !== null ? String(nextOffset) : null,
      };
    } catch (err) {
      this._handleApiError(err, 'getPlaylistTracks');
    }
  }

  async getLibrary(cursor = null, limit = 50) {
    try {
      const offset = cursor ? parseInt(cursor, 10) : 0;
      const res = await this._api.get('/me/tracks', {
        params: { limit, offset },
      });

      const tracks = res.data.items
        .filter(item => item.track && item.track.id)
        .map((item, index) => this._normalizeTrack(item.track, 'library', offset + index));

      const nextOffset = res.data.next ? offset + limit : null;
      return {
        tracks,
        nextCursor: nextOffset !== null ? String(nextOffset) : null,
      };
    } catch (err) {
      this._handleApiError(err, 'getLibrary');
    }
  }

  /**
   * Returns last 50 recently played.
   * This is the maximum Spotify's API exposes without a data export.
   */
  async getListeningHistory(cursor = null, limit = 50) {
    try {
      const params = { limit: Math.min(limit, 50) };
      if (cursor) params.before = cursor; // Unix ms timestamp cursor

      const res = await this._api.get('/me/player/recently-played', { params });

      const events = res.data.items.map(item => ({
        playedAt:  new Date(item.played_at),
        title:     item.track.name,
        artist:    item.track.artists?.[0]?.name || 'Unknown',
        album:     item.track.album?.name,
        durationMs: item.track.duration_ms,
        msPlayed:   item.track.duration_ms, // Not available from this endpoint
        isrc:      item.track.external_ids?.isrc,
        sourceTrackId: item.track.id,
      }));

      const nextCursor = res.data.cursors?.before || null;
      return { events, nextCursor };
    } catch (err) {
      this._handleApiError(err, 'getListeningHistory');
    }
  }

  /**
   * Parse Spotify "Extended Streaming History" JSON export.
   * Users can request this from: spotify.com → Account → Privacy → Request Data
   * The resulting archive contains files named "Streaming_History_Audio_*.json"
   *
   * @param {string|Buffer} fileData - Contents of the JSON file
   * @returns {Promise<HistoryEvent[]>}
   */
  async parseHistoryFile(fileData) {
    try {
      const records = JSON.parse(fileData.toString());

      if (!Array.isArray(records)) {
        throw new ImporterError('INVALID_FILE', 'Expected a JSON array in the Spotify history file');
      }

      return records
        .filter(r => r.master_metadata_track_name) // Filter out podcasts/null
        .map(r => ({
          playedAt:  new Date(r.ts || r.endTime),
          title:     r.master_metadata_track_name || r.trackName,
          artist:    r.master_metadata_album_artist_name || r.artistName,
          album:     r.master_metadata_album_album_name || r.albumName,
          msPlayed:  r.ms_played || 0,
          durationMs: null, // Not in export
          sourceTrackId: null, // Spotify export doesn't include track IDs
        }))
        .filter(e => e.msPlayed >= 30000); // Only count plays >= 30 seconds
    } catch (err) {
      if (err instanceof ImporterError) throw err;
      throw new ImporterError('PARSE_ERROR', `Failed to parse Spotify history file: ${err.message}`);
    }
  }

  async revokeToken(accessToken) {
    // Spotify doesn't have a server-side revocation endpoint for Authorization Code flow.
    // Token naturally expires; we just delete it from our database.
    return;
  }

  // ─── Private helpers ─────────────────────────────────────────────────────

  _normalizeTrack(track, playlistId, position) {
    return {
      sourceTrackId: track.id,
      source:    'spotify',
      title:     track.name,
      artist:    track.artists?.[0]?.name || 'Unknown',
      artists:   (track.artists || []).map(a => a.name),
      album:     track.album?.name,
      isrc:      track.external_ids?.isrc,
      durationMs: track.duration_ms,
      releaseDate: track.album?.release_date,
      thumbnailUrl: track.album?.images?.[0]?.url || '',
      sourceUrl:  track.external_urls?.spotify || '',
      playlistIds: [playlistId],
      position,
    };
  }

  _handleApiError(err, method) {
    if (err instanceof ImporterError) throw err;
    if (err.response?.status === 401) {
      throw new ImporterError('TOKEN_EXPIRED', 'Spotify connection expired. Please reconnect.');
    }
    if (err.response?.status === 429) {
      const retryAfter = err.response.headers['retry-after'] || 5;
      throw new ImporterError('RATE_LIMITED', `Spotify rate limit hit. Retry after ${retryAfter}s`);
    }
    throw new ImporterError('API_ERROR', `Spotify ${method} failed: ${err.message}`);
  }
}

module.exports = SpotifyImporter;
