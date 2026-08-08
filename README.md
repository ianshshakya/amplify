# Spotify Clone (Flutter + YouTube audio)

A Spotify-style music player built with Flutter that streams audio from
YouTube instead of using the Spotify API — so it's completely free to run,
with no API keys or paid accounts required.

## Features

- Search songs (powered by YouTube, via `youtube_explode_dart`)
- Audio-only playback (no video shown) using `just_audio`
- Background playback with lock-screen / notification controls
  (`just_audio_background`)
- Full player screen: play/pause, next/previous, seek, shuffle, repeat
  (off / repeat-all / repeat-one)
- Mini player bar persistent across Home / Search / Library tabs
- Playlists: create, delete, add/remove tracks — all stored locally with
  Hive (no backend/database needed)
- Built-in "Liked Songs" playlist (heart icon on any track)
- Spotify-style dark theme

## Backend integration (login, playlists, liked songs, watch history)

This app now talks to the companion backend (`spotify_clone_backend`).
Before running:

1. Get the backend running locally or deployed (see its own README).
2. Open `lib/services/api_client.dart` and set `baseUrl` to point at it:
   - Android emulator + backend on your own machine → `http://10.0.2.2:5000/api`
     (already the default)
   - iOS simulator → `http://localhost:5000/api`
   - Physical device → your machine's LAN IP, e.g. `http://192.168.1.5:5000/api`
   - Deployed backend (Render/Railway) → its public HTTPS URL

The app now requires login. On first launch it shows a login/sign-up
screen; the JWT is stored in the device's secure storage
(`flutter_secure_storage`) and reused on future launches until it
expires or the user logs out.

Playlists and liked songs are no longer stored on-device — they live
in MongoDB via the backend, so they'll follow the user across devices
once they log in with the same account. Every track play also pings
`/api/users/watch-history`, which sets up the data needed for
recommendations and the reels-style feed later.

## Getting started

1. **Install Flutter** (if you haven't): https://docs.flutter.dev/get-started/install
2. From the project folder, install dependencies:
   ```
   flutter pub get
   ```
3. Run on a connected device or emulator:
   ```
   flutter run
   ```

That's it — no `.env` file, no API keys, no signup required to run the app.

## Project structure

```
lib/
  models/        Track, Playlist (Hive-backed data models)
  services/       YoutubeService — search + audio stream extraction
  providers/      PlayerProvider (playback state), PlaylistProvider (Hive)
  screens/        Home, Search, Library, Playlist detail, Full player
  widgets/        TrackTile, MiniPlayer
  theme/          Centralized colors/typography
```

## How playback works

1. `YoutubeService.search()` queries YouTube and maps results into the
   app's own `Track` model (title, artist/channel, thumbnail, duration).
2. When a track is tapped, `YoutubeService.getAudioStreamUrl()` resolves
   the highest-bitrate **audio-only** stream for that video.
3. That stream URL is handed to `just_audio`, which plays it like any
   other audio file — no video is ever rendered.
4. `just_audio_background` wraps this so playback survives the app being
   backgrounded and shows proper media controls on the lock screen.

## Known limitations (worth mentioning in interviews / your README)

- **`youtube_explode_dart` is unofficial.** It works by parsing YouTube's
  internal page/player data rather than calling a documented public API
  for stream extraction. It's widely used for personal and portfolio
  projects, but YouTube can change internals and occasionally break it —
  a real production app would need a more resilient/licensed approach.
- **No user accounts / auth yet.** Playlists are stored per-device via
  Hive. Adding a backend (Node + Express + MongoDB, e.g.) with JWT auth
  would let playlists sync across devices — a natural "next step" to
  mention if asked how you'd extend this.
- **This project only embeds/streams via the official player pathway
  conceptually** (audio-only extraction, not downloading/redistributing
  files), which keeps it aligned with acceptable personal-project use.
  It is not intended for distribution or commercial use.

## Possible extensions

- Backend + MongoDB so playlists sync across devices (great tie-in if
  you're also applying to full-stack roles)
- Lyrics display
- "Recently played" and basic recommendations
- Offline caching of recently played tracks
