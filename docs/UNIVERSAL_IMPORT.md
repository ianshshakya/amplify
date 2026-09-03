# Universal Music Library Import — Architecture & Setup

Amplify's Universal Music Import system allows users to seamlessly transition from Spotify or YouTube Music without losing their playlists, saved library, or personalized recommendations.

## Core Principles

1. **No Audio Scraping**: The system does NOT download audio or video files from other platforms. It imports metadata (titles, artists, albums, ISRC) and intelligently matches it against Amplify's own music catalog.
2. **Recommendation Preservation**: Imported listening history is injected into Amplify's `TasteEngine` to bootstrap personalized recommendations immediately.
3. **Idempotency**: Import jobs can be run multiple times safely. Existing tracks in matched playlists are not duplicated.
4. **Resiliency**: The async `ImportWorker` runs in the background and saves cursors after every batch. If an import fails midway, it can be resumed.

---

## 1. Environment Setup

To enable the import features, you must configure OAuth credentials for Spotify and Google in your backend `.env` file. (See `spotify_backend/.env.example`).

### Generating the Encryption Key
The backend encrypts OAuth tokens at rest using AES-256-GCM. You must provide a 32-byte key:
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```
Copy the output into `ENCRYPTION_KEY=` in your `.env`.

---

## 2. Setting Up Spotify

1. Go to the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard) and create a new App.
2. Under App Settings, find your **Client ID** and **Client Secret**. Add these to your `.env` as `SPOTIFY_CLIENT_ID` and `SPOTIFY_CLIENT_SECRET`.
3. In the Redirect URIs section, add your backend callback URL exactly as follows:
   `https://amplifysaas.onrender.com/api/import/spotify/callback`
   *(If testing locally, also add `http://localhost:5000/api/import/spotify/callback`)*

**Spotify Limitations:**
The Spotify API only exposes the last 50 recently played tracks. Full listening history requires the user to request a data export from Spotify and upload the `StreamingHistory.json` file in the Amplify app.

---

## 3. Setting Up YouTube Music

1. Go to the [Google Cloud Console](https://console.cloud.google.com/) and create a project.
2. Enable the **YouTube Data API v3** for your project.
3. Go to "APIs & Services" -> "Credentials" and create an **OAuth 2.0 Client ID** (Web application).
4. Add your **Client ID** and **Client Secret** to your `.env` as `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET`.
5. Under Authorized redirect URIs, add:
   `https://amplifysaas.onrender.com/api/import/youtube/callback`

**YouTube Limitations:**
YouTube Music does not have a dedicated public API. This importer uses the YouTube Data API to fetch YouTube playlists (which includes Music library playlists if they are saved).
Full listening history is only available via Google Takeout export (watch-history.json).

---

## 4. How the Matching Engine Works

The `TrackMatcher` service (`spotify_backend/src/services/TrackMatcher.js`) uses a multi-level strategy:

1. **ISRC Match (100% confidence)**: If the provider supplies an International Standard Recording Code, we look for it in our existing catalog database (`SongStatistic`).
2. **External ID Map (99% confidence)**: If we've imported this track before, we use the stored provider ID mapping.
3. **Exact Search Match (>85% confidence)**: We search the catalog and use a weighted fuzzy algorithm (Levenshtein distance) on title, artist, album, and duration to score candidates. If the top candidate scores >= 85, it's automatically `MATCHED`.
4. **Review Required (60-84% confidence)**: If the top candidate is uncertain, it's marked `REVIEW_REQUIRED`. The user is prompted in the app to manually select the correct match from the top 5 candidates.
5. **Unavailable (<60% confidence)**: If no suitable match is found, the track is skipped.

---

## 5. Adding a New Provider (e.g. Apple Music)

1. Create a new class extending `MusicLibraryImporter` (e.g., `AppleMusicImporter.js`).
2. Implement `authenticate()`, `getPlaylists()`, and `getPlaylistTracks()`.
3. If supported, implement `getLibrary()` and `getListeningHistory()`.
4. Register the provider in `importRoutes.js` (add it to the `/providers` list and `getImporterClass`).
5. Update the Flutter `import_models.dart` `ImportProvider` enum and `bring_your_music_screen.dart` UI.
