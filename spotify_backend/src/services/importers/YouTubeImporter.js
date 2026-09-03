/**
 * YouTubeImporter
 * ===============
 * Implements MusicLibraryImporter for the YouTube Data API v3.
 *
 * ⚠️  IMPORTANT LIMITATIONS:
 *     YouTube Music does not have a dedicated public API.
 *     This importer accesses only the official YouTube Data API v3,
 *     which exposes playlists and playlist items.
 *
 *     What IS available:
 *     ✅ User's YouTube playlists (including Music library playlists if shared)
 *     ✅ Playlist metadata and tracks
 *     ✅ Video/song metadata available through the API
 *
 *     What is NOT available:
 *     ❌ YouTube Music-specific "Liked music" (different from YouTube likes)
 *     ❌ YouTube Music listening history (only via Google Takeout export)
 *     ❌ YouTube Music recommendations/radio
 *     ❌ Subscription music libraries
 *
 * This importer does NOT:
 *   - Download audio from YouTube
 *   - Stream YouTube content through Amplify
 *   - Scrape YouTube Music pages
 *   - Use unofficial APIs
 *
 * OAuth: Google OAuth 2.0
 * Scopes: youtube.readonly
 * API docs: https://developers.google.com/youtube/v3
 */

const axios = require('axios');
const { MusicLibraryImporter, ImporterError } = require('./MusicLibraryImporter');

const YOUTUBE_API_BASE = 'https://www.googleapis.com/youtube/v3';
const GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token';
const GOOGLE_AUTH_URL = 'https://accounts.google.com/o/oauth2/v2/auth';

const YOUTUBE_SCOPES = [
  'https://www.googleapis.com/auth/youtube.readonly',
  'https://www.googleapis.com/auth/userinfo.profile',
  'https://www.googleapis.com/auth/userinfo.email',
].join(' ');

class YouTubeImporter extends MusicLibraryImporter {
  constructor(accessToken) {
    super();
    this.accessToken = accessToken;
    this._api = axios.create({
      baseURL: YOUTUBE_API_BASE,
      params: { key: process.env.GOOGLE_API_KEY },
      headers: { Authorization: `Bearer ${accessToken}` },
    });
  }

  // ─── Static OAuth helpers ────────────────────────────────────────────────

  static buildAuthUrl(state) {
    const params = new URLSearchParams({
      response_type: 'code',
      client_id: process.env.GOOGLE_CLIENT_ID,
      redirect_uri: process.env.GOOGLE_REDIRECT_URI,
      scope: YOUTUBE_SCOPES,
      state,
      access_type: 'offline',
      prompt: 'consent',
    });
    return `${GOOGLE_AUTH_URL}?${params.toString()}`;
  }

  static async exchangeCode(code) {
    try {
      const res = await axios.post(GOOGLE_TOKEN_URL, {
        grant_type: 'authorization_code',
        code,
        redirect_uri: process.env.GOOGLE_REDIRECT_URI,
        client_id: process.env.GOOGLE_CLIENT_ID,
        client_secret: process.env.GOOGLE_CLIENT_SECRET,
      });

      return {
        accessToken:  res.data.access_token,
        refreshToken: res.data.refresh_token,
        expiresIn:    res.data.expires_in,
        scope:        res.data.scope,
      };
    } catch (err) {
      const detail = err.response?.data?.error_description || err.message;
      throw new ImporterError('OAUTH_ERROR', `Google token exchange failed: ${detail}`);
    }
  }

  static async refreshToken(refreshToken) {
    try {
      const res = await axios.post(GOOGLE_TOKEN_URL, {
        grant_type: 'refresh_token',
        refresh_token: refreshToken,
        client_id: process.env.GOOGLE_CLIENT_ID,
        client_secret: process.env.GOOGLE_CLIENT_SECRET,
      });

      return {
        accessToken: res.data.access_token,
        expiresIn:   res.data.expires_in,
      };
    } catch (err) {
      throw new ImporterError('TOKEN_EXPIRED', 'YouTube connection expired. Please reconnect your Google account.');
    }
  }

  // ─── Interface implementation ────────────────────────────────────────────

  async authenticate() {
    try {
      const res = await axios.get('https://www.googleapis.com/oauth2/v2/userinfo', {
        headers: { Authorization: `Bearer ${this.accessToken}` },
      });
      return {
        valid: true,
        userId: res.data.id,
        displayName: res.data.name || res.data.email,
        email: res.data.email,
      };
    } catch (err) {
      if (err.response?.status === 401) {
        throw new ImporterError('TOKEN_EXPIRED', 'YouTube connection expired. Please reconnect.');
      }
      throw new ImporterError('AUTH_ERROR', `YouTube authentication failed: ${err.message}`);
    }
  }

  async getPlaylists(cursor = null, limit = 50) {
    try {
      const params = {
        part: 'snippet,contentDetails',
        mine: true,
        maxResults: Math.min(limit, 50),
      };
      if (cursor) params.pageToken = cursor;

      const res = await this._api.get('/playlists', { params });

      const playlists = res.data.items.map(p => ({
        id:           p.id,
        name:         p.snippet.title,
        description:  p.snippet.description || '',
        thumbnailUrl: p.snippet.thumbnails?.high?.url || p.snippet.thumbnails?.default?.url || '',
        sourceUrl:    `https://www.youtube.com/playlist?list=${p.id}`,
        totalTracks:  p.contentDetails?.itemCount || 0,
        isPublic:     p.snippet.privacyStatus === 'public',
      }));

      return {
        playlists,
        nextCursor: res.data.nextPageToken || null,
      };
    } catch (err) {
      this._handleApiError(err, 'getPlaylists');
    }
  }

  async getPlaylistTracks(playlistId, cursor = null, limit = 50) {
    try {
      // Step 1: Get playlist items (video IDs + positions)
      const itemParams = {
        part: 'snippet,contentDetails',
        playlistId,
        maxResults: Math.min(limit, 50),
      };
      if (cursor) itemParams.pageToken = cursor;

      const itemsRes = await this._api.get('/playlistItems', { params: itemParams });

      // Filter out deleted/private videos
      const validItems = itemsRes.data.items.filter(
        item => item.snippet?.resourceId?.videoId &&
                item.snippet.title !== 'Deleted video' &&
                item.snippet.title !== 'Private video'
      );

      if (validItems.length === 0) {
        return { tracks: [], nextCursor: itemsRes.data.nextPageToken || null };
      }

      // Step 2: Batch-fetch video details for richer metadata (duration, channel)
      const videoIds = validItems.map(i => i.snippet.resourceId.videoId).join(',');
      const videoRes = await this._api.get('/videos', {
        params: { part: 'snippet,contentDetails', id: videoIds },
      });

      const videoMap = {};
      for (const v of videoRes.data.items) {
        videoMap[v.id] = v;
      }

      const tracks = validItems.map((item, idx) => {
        const videoId = item.snippet.resourceId.videoId;
        const video = videoMap[videoId];
        const durationMs = video ? this._parseIsoDuration(video.contentDetails?.duration) : null;

        return {
          sourceTrackId: videoId,
          title:     item.snippet.title,
          artist:    video?.snippet?.channelTitle || item.snippet.videoOwnerChannelTitle || 'Unknown',
          artists:   [video?.snippet?.channelTitle || 'Unknown'],
          album:     null, // YouTube doesn't expose album info via API
          isrc:      null, // Not available through YouTube API
          durationMs,
          releaseDate: video?.snippet?.publishedAt,
          thumbnailUrl: item.snippet.thumbnails?.high?.url || item.snippet.thumbnails?.default?.url || '',
          sourceUrl:  `https://www.youtube.com/watch?v=${videoId}`,
          playlistIds: [playlistId],
          position:   item.snippet.position || idx,
        };
      });

      return {
        tracks,
        nextCursor: itemsRes.data.nextPageToken || null,
      };
    } catch (err) {
      this._handleApiError(err, 'getPlaylistTracks');
    }
  }

  /**
   * YouTube Music "Liked Songs" lives in a special playlist called "LL".
   * However, accessing it requires the youtube.force-ssl scope and may
   * not always be available. We attempt it but handle gracefully.
   */
  async getLibrary(cursor = null, limit = 50) {
    // YouTube Music liked songs are in the "LL" (Liked Videos) playlist
    return this.getPlaylistTracks('LL', cursor, limit);
  }

  /**
   * Parse Google Takeout YouTube history (watch-history.json).
   * Users can export from: myaccount.google.com → Data & Privacy → Download your data
   * Select "YouTube and YouTube Music" → "history" → "watch-history.json"
   *
   * @param {string|Buffer} fileData
   * @returns {Promise<HistoryEvent[]>}
   */
  async parseHistoryFile(fileData) {
    try {
      const records = JSON.parse(fileData.toString());

      if (!Array.isArray(records)) {
        throw new ImporterError('INVALID_FILE', 'Expected a JSON array in the YouTube Takeout file');
      }

      return records
        .filter(r => r.titleUrl && r.title && !r.title.startsWith('Watched ')) // Filter non-music
        .filter(r => r.subtitles?.length > 0) // Must have channel info
        .map(r => {
          const videoId = r.titleUrl?.split('v=')?.[1];
          return {
            playedAt:  new Date(r.time),
            title:     r.title.replace(/^Watched\s+/, ''),
            artist:    r.subtitles?.[0]?.name || 'Unknown',
            album:     null,
            msPlayed:  null, // Not in Takeout data
            durationMs: null,
            sourceTrackId: videoId || null,
          };
        })
        .filter(e => e.playedAt && !isNaN(e.playedAt.getTime()));
    } catch (err) {
      if (err instanceof ImporterError) throw err;
      throw new ImporterError('PARSE_ERROR', `Failed to parse YouTube Takeout file: ${err.message}`);
    }
  }

  // ─── Private helpers ─────────────────────────────────────────────────────

  /**
   * Parse ISO 8601 duration (PT4M33S) to milliseconds.
   */
  _parseIsoDuration(iso) {
    if (!iso) return null;
    const match = iso.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/);
    if (!match) return null;
    const [, h = 0, m = 0, s = 0] = match.map(Number);
    return ((h * 3600) + (m * 60) + s) * 1000;
  }

  _handleApiError(err, method) {
    if (err instanceof ImporterError) throw err;
    if (err.response?.status === 401) {
      throw new ImporterError('TOKEN_EXPIRED', 'YouTube connection expired. Please reconnect.');
    }
    if (err.response?.status === 403) {
      const reason = err.response?.data?.error?.errors?.[0]?.reason;
      if (reason === 'quotaExceeded') {
        throw new ImporterError('RATE_LIMITED', 'YouTube API quota exceeded. Import will resume tomorrow.');
      }
      throw new ImporterError('FORBIDDEN', 'YouTube access denied. Check that required scopes were granted.');
    }
    if (err.response?.status === 404) {
      throw new ImporterError('NOT_FOUND', `YouTube playlist not found: ${err.message}`);
    }
    throw new ImporterError('API_ERROR', `YouTube ${method} failed: ${err.message}`);
  }
}

module.exports = YouTubeImporter;
