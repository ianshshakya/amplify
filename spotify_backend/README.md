# Spotify Clone — Backend

Node.js + Express + MongoDB backend providing authentication and
per-user data (liked songs, playlists, watch history) for the Flutter
Spotify clone. This is what turns the app from "works on one device"
into "log in and get your own personalized experience."

## Setup

1. Install dependencies:
   ```
   npm install
   ```
2. Create a free MongoDB Atlas cluster: https://www.mongodb.com/cloud/atlas/register
   (free tier is plenty for a portfolio project)
3. Copy `.env.example` to `.env` and fill in:
   - `MONGO_URI` — your Atlas connection string
   - `JWT_SECRET` — any long random string (a command to generate one is
     in the `.env.example` comments)
4. Run the server:
   ```
   npm run dev    # with auto-reload (nodemon)
   npm start      # plain node
   ```
5. Server runs on `http://localhost:5000` by default.

Deploy for free on **Render** or **Railway** when you're ready to make it
publicly reachable from your phone/app.

## Auth flow

1. `POST /api/auth/register` or `/api/auth/login` → returns `{ token, user }`
2. Store `token` on the Flutter side (e.g. `flutter_secure_storage`)
3. Send it on every subsequent request:
   ```
   Authorization: Bearer <token>
   ```

## API reference

### Auth (public)
| Method | Route | Body |
|---|---|---|
| POST | `/api/auth/register` | `{ name, email, password }` |
| POST | `/api/auth/login` | `{ email, password }` |

### Users (requires auth)
| Method | Route | Body |
|---|---|---|
| GET | `/api/users/me` | — |
| POST | `/api/users/liked-songs/toggle` | `{ track }` |
| POST | `/api/users/watch-history` | `{ track }` |
| GET | `/api/users/watch-history` | — |

### Playlists (requires auth)
| Method | Route | Body |
|---|---|---|
| GET | `/api/playlists` | — |
| POST | `/api/playlists` | `{ name }` |
| DELETE | `/api/playlists/:playlistId` | — |
| POST | `/api/playlists/:playlistId/tracks` | `{ track }` |
| DELETE | `/api/playlists/:playlistId/tracks/:videoId` | — |

`track` shape (matches the Flutter `Track` model):
```json
{
  "videoId": "abc123",
  "title": "Song Title",
  "artist": "Artist Name",
  "thumbnailUrl": "https://...",
  "durationMs": 210000
}
```

## Why watch history is capped at 200 entries

Keeping it bounded avoids unbounded document growth in MongoDB (each
User document has a 16MB hard limit) and keeps "recently played" /
future recommendation queries fast. 200 recent plays is more than
enough to power personalization features.

## Security notes (good to mention in interviews)

- Passwords are hashed with **bcrypt** before storage — the plain
  password is never saved.
- **JWT** tokens are used for stateless auth instead of server-side
  sessions, so the API scales horizontally without a shared session store.
- **express-rate-limit** throttles auth endpoints to reduce brute-force
  login/registration attempts.
- `.env` (containing secrets) is git-ignored — never commit it.

## What's next

This backend is intentionally scoped to just auth + user data. The
next layer to add is a `/api/recommendations` route that reads a
user's `watchHistory`, picks recent artists/genres, and returns
YouTube search queries for "similar songs" and the reels-style feed —
a natural follow-up once this foundation is wired into the app.
