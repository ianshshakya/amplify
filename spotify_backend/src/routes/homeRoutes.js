const express = require('express');
const MusicProvider = require('../services/MusicProvider');
const PlaylistIntelligence = require('../services/PlaylistIntelligence');
const DynamicPlaylist = require('../models/DynamicPlaylist');
const UserMusicProfile = require('../models/UserMusicProfile');
const SongStatistic = require('../models/SongStatistic');
const CURATED_PLAYLISTS = require('../config/playlists');
const optionalAuth = require('../middleware/optionalAuth');

const router = express.Router();

// ─── Helper: score a playlist config against a user profile ──────────────────
function scorePlaylistForUser(playlist, languageAffinity, artistAffinity) {
  let score = 0;

  // Language match
  const langs = (playlist.intent && playlist.intent.languages) ? playlist.intent.languages : [];
  for (const lang of langs) {
    if (languageAffinity[lang]) score += languageAffinity[lang] * 10;
  }

  // Artist match (for artist spotlight playlists)
  if (playlist.searchQuery && artistAffinity) {
    const safeKey = playlist.searchQuery.replace(/[^a-zA-Z0-9]/g, '_').toLowerCase();
    if (artistAffinity[safeKey]) score += artistAffinity[safeKey] * 20;
  }

  // Always show top charts and trending (baseline)
  if (playlist.type === 'Top Charts') score += 5;
  if (playlist.type === 'Trending Playlists') score += 3;

  return score;
}

// ─── Home: return personalized playlist cards (metadata only, no tracks) ─────
router.get('/', optionalAuth, async (req, res) => {
  let languageAffinity = {};
  let artistAffinity = {};
  let hasProfile = false;
  let feed = [];

  if (req.userId) {
    try {
      const profile = await UserMusicProfile.findOne({ userId: req.userId });
      if (profile && profile.artistAffinity && profile.languageAffinity) {
        languageAffinity = profile.languageAffinity instanceof Map
          ? Object.fromEntries(profile.languageAffinity)
          : (profile.languageAffinity || {});
        artistAffinity = profile.artistAffinity instanceof Map
          ? Object.fromEntries(profile.artistAffinity)
          : (profile.artistAffinity || {});

        const hasLang = Object.keys(languageAffinity).length > 0;
        const hasArtist = Object.keys(artistAffinity).length > 0;
        hasProfile = hasLang || hasArtist;

        if (hasProfile) {
          const topLanguages = Object.entries(languageAffinity)
            .sort((a, b) => b[1] - a[1])
            .map(e => e[0])
            .slice(0, 3);
          
          const primaryLang = topLanguages[0] || 'English';

          const topArtists = Object.entries(artistAffinity)
            .sort((a, b) => b[1] - a[1])
            .map(e => e[0].replace(/_/g, ' '))
            .slice(0, 5);

          // 1. Top Charts (Dynamic by Language)
          for (const lang of topLanguages.slice(0, 2)) {
            feed.push({
              id: `top_charts_${lang.toLowerCase()}`,
              title: `${lang} Top 50`,
              type: 'Top Charts',
              strategy: 'multi',
              searchQuery: [`${lang} top 50`, `trending ${lang} songs`],
              description: `The biggest ${lang} hits trending today.`,
              thumbnailUrl: '',
              intent: { languages: [lang], popularity: 'very-high', discovery: 'low' },
            });
          }
          feed.push({
             id: 'global100',
             title: 'Global Top 100',
             type: 'Top Charts',
             strategy: 'spotify',
             spotifyUrl: ['https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M'],
             saavnPlaylistId: '103402903',
             description: 'The most popular songs across the globe right now.',
             thumbnailUrl: 'https://misc.scdn.co/liked-songs/liked-songs-640.png',
             intent: { languages: ['English'], popularity: 'very-high', discovery: 'low', energy: 'medium' },
          });

          // 2. Trending Now
          for (const lang of topLanguages.slice(0, 2)) {
            feed.push({
              id: `trending_${lang.toLowerCase()}`,
              title: `Trending in ${lang}`,
              type: 'Trending Now',
              strategy: 'multi',
              searchQuery: [`new viral ${lang} songs`, `trending ${lang}`],
              description: `Viral and rising tracks in ${lang}.`,
              thumbnailUrl: '',
              intent: { languages: [lang], popularity: 'high', discovery: 'medium' },
            });
          }

          // 3. Artist Spotlights
          for (const artist of topArtists) {
            feed.push({
              id: `dynamic_artist_${artist.replace(/\s+/g, '_').toLowerCase()}`,
              title: `Best of ${artist}`,
              type: 'Artist Spotlights',
              strategy: 'artist',
              searchQuery: artist,
              description: `Essential hits by ${artist}.`,
              thumbnailUrl: '',
              intent: { popularity: 'high', discovery: 'low' },
            });
          }

          // 4. Moods & Genres
          const moodOptions = ['Chill', 'Workout', 'Party', 'Romance', 'Sad', 'Focus'];
          // Deterministic shuffle based on user ID to keep moods consistent for a while
          const hash = req.userId.split('').reduce((a, b) => a + b.charCodeAt(0), 0);
          
          for (let i = 0; i < 3; i++) {
            const mood = moodOptions[(hash + i) % moodOptions.length];
            const lang = topLanguages[i % topLanguages.length] || primaryLang;
            
            feed.push({
              id: `mood_${mood.toLowerCase()}_${lang.toLowerCase()}`,
              title: `${lang} ${mood}`,
              type: 'Moods & Genres',
              strategy: 'multi',
              searchQuery: [`${lang} ${mood} songs`, `best ${lang} ${mood}`],
              description: `Perfect ${mood.toLowerCase()} vibes in ${lang}.`,
              thumbnailUrl: '',
              intent: { languages: [lang], popularity: 'high', discovery: 'medium' },
            });
          }

          // 5. Decades
          const decades = ['90s', '2000s', '2010s', '80s'];
          for (let i = 0; i < 2; i++) {
            const decade = decades[(hash + i) % decades.length];
            const lang = topLanguages[i % topLanguages.length] || primaryLang;
            
            feed.push({
                id: `decade_${decade}_${lang.toLowerCase()}`,
                title: `${decade} ${lang} Throwback`,
                type: 'Decades',
                strategy: 'multi',
                searchQuery: [`${decade} ${lang} hits`, `old ${lang} songs`],
                description: `Take a trip down memory lane.`,
                thumbnailUrl: '',
                intent: { languages: [lang], popularity: 'high', discovery: 'low' },
            });
          }
        }
      }
    } catch (err) {
      console.error('[HomeRoutes] Error building personalized feed:', err.message);
    }
  }

  // Cold Start Fallback
  if (!hasProfile || feed.length === 0) {
    feed = [...CURATED_PLAYLISTS];
  }


  try {
    const playlistIds = feed.map(p => p.id);
    const dbPlaylists = await DynamicPlaylist.find({ playlistId: { $in: playlistIds } }).select('playlistId thumbnailUrl');
    const dbMap = new Map(dbPlaylists.map(db => [db.playlistId, db.thumbnailUrl]));

    // Fetch missing thumbnails dynamically using JioSaavn search
    for (const p of feed) {
      if (!dbMap.has(p.id) && !p.thumbnailUrl) {
        try {
          // If there's a search query array, use the first one, else use the string
          const query = Array.isArray(p.searchQuery) ? p.searchQuery[0] : (p.searchQuery || p.title);
          
          if (p.strategy === 'artist') {
            const results = await MusicProvider.searchArtist(query, 1);
            if (results && results.length > 0) {
               dbMap.set(p.id, results[0].imageUrl || results[0].thumbnailUrl);
            }
          } else {
            const results = await MusicProvider.search(query, 1);
            if (results && results.length > 0) {
               dbMap.set(p.id, results[0].thumbnailUrl);
            }
          }
        } catch (e) {
          console.error(`[HomeRoutes] Error fetching dynamic thumbnail for ${p.id}:`, e.message);
        }
      }
    }

    res.json(feed.map(p => ({
      id: p.id,
      title: p.title,
      type: p.type,
      description: p.description,
      thumbnailUrl: dbMap.get(p.id) || p.thumbnailUrl || '',
    })));
  } catch (err) {
    console.error('[HomeRoutes] Error fetching DB thumbnails:', err.message);
    res.json(feed.map(p => ({
      id: p.id,
      title: p.title,
      type: p.type,
      description: p.description,
      thumbnailUrl: p.thumbnailUrl || '',
    })));
  }
});

// ─── Song of the Day: same for ALL users, date-seeded ────────────────────────
// Picks the top-trending song for today and caches it in MongoDB by date string.
// All users get the exact same song on the same calendar day.
router.get('/song-of-the-day', async (req, res) => {
  try {
    const today = new Date().toISOString().slice(0, 10); // e.g. "2026-09-05"
    const cacheKey = `sotd_${today}`;

    // Check if we already picked today's song
    let cached = await DynamicPlaylist.findOne({ playlistId: cacheKey });
    if (cached && cached.songs && cached.songs.length > 0) {
      return res.json(cached.songs[0]);
    }

    // Pick the top trending song of today (deterministic)
    // We use a date-based seed: sort by (trendScore * dateHash) to make it change daily
    const dateHash = today.split('-').reduce((acc, n) => acc + parseInt(n), 0);
    const candidates = await SongStatistic.find({ 'song.videoId': { $exists: true } })
      .sort({ trendScore: -1, popularityScore: -1 })
      .limit(50);

    if (!candidates || candidates.length === 0) {
      return res.status(404).json({ error: 'No song of the day available yet' });
    }

    // Seed selection: pick index based on date so it changes daily but is the same for all users
    const idx = dateHash % Math.min(candidates.length, 20);
    const sotd = candidates[idx]?.song;

    if (!sotd) return res.status(404).json({ error: 'No song of the day available' });

    // Cache in MongoDB for 24 hours
    await DynamicPlaylist.findOneAndUpdate(
      { playlistId: cacheKey },
      { playlistId: cacheKey, songs: [sotd], updatedAt: new Date() },
      { upsert: true }
    );

    res.json(sotd);
  } catch (err) {
    console.error('[HomeRoutes] Song of the Day error:', err.message);
    // Fallback: return any popular song
    try {
      const fallback = await SongStatistic.findOne({}).sort({ popularityScore: -1 });
      if (fallback?.song) return res.json(fallback.song);
    } catch (_) {}
    res.status(500).json({ error: 'Failed to fetch song of the day' });
  }
});

// ─── Playlist: return songs for a curated playlist ─────────────────────────────

// Uses stale-while-revalidate from MongoDB, with PlaylistIntelligence as the
// live generation engine when cache is cold or stale.
router.get('/playlist/:id', optionalAuth, async (req, res) => {
  try {
    let playlistConfig = CURATED_PLAYLISTS.find(p => p.id === req.params.id);
    
    // Fallback for dynamic user-specific playlists
    if (!playlistConfig && req.params.id.startsWith('dynamic_artist_')) {
      const artist = req.params.id.replace('dynamic_artist_', '').replace(/_/g, ' ');
      playlistConfig = {
        id: req.params.id,
        title: `More of ${artist}`,
        strategy: 'artist',
        searchQuery: artist,
        intent: { popularity: 'high', discovery: 'low', purpose: 'artist' },
      };
    } else if (!playlistConfig && req.params.id.startsWith('top_charts_')) {
      const lang = req.params.id.replace('top_charts_', '').replace(/_/g, ' ');
      playlistConfig = {
        id: req.params.id,
        title: `${lang.charAt(0).toUpperCase() + lang.slice(1)} Top 50`,
        strategy: 'multi',
        searchQuery: [`${lang} top 50`, `trending ${lang} songs`],
        intent: { languages: [lang], popularity: 'very-high', discovery: 'low' },
      };
    } else if (!playlistConfig && req.params.id.startsWith('trending_')) {
      const lang = req.params.id.replace('trending_', '').replace(/_/g, ' ');
      playlistConfig = {
        id: req.params.id,
        title: `Trending in ${lang.charAt(0).toUpperCase() + lang.slice(1)}`,
        strategy: 'multi',
        searchQuery: [`new viral ${lang} songs`, `trending ${lang}`],
        intent: { languages: [lang], popularity: 'high', discovery: 'medium' },
      };
    } else if (!playlistConfig && req.params.id.startsWith('mood_')) {
      // id format: mood_{mood}_{lang}
      const parts = req.params.id.split('_');
      const lang = parts.pop() || 'english';
      const mood = parts.slice(1).join(' '); // in case mood has spaces
      playlistConfig = {
        id: req.params.id,
        title: `${lang.charAt(0).toUpperCase() + lang.slice(1)} ${mood.charAt(0).toUpperCase() + mood.slice(1)}`,
        strategy: 'multi',
        searchQuery: [`${lang} ${mood} songs`, `best ${lang} ${mood}`],
        intent: { languages: [lang], popularity: 'high', discovery: 'medium' },
      };
    } else if (!playlistConfig && req.params.id.startsWith('decade_')) {
      // id format: decade_{decade}_{lang}
      const parts = req.params.id.split('_');
      const lang = parts.pop() || 'english';
      const decade = parts.slice(1).join(' ');
      playlistConfig = {
        id: req.params.id,
        title: `${decade} ${lang.charAt(0).toUpperCase() + lang.slice(1)} Throwback`,
        strategy: 'multi',
        searchQuery: [`${decade} ${lang} hits`, `old ${lang} songs`],
        intent: { languages: [lang], popularity: 'high', discovery: 'low' },
      };
    }

    if (!playlistConfig) return res.status(404).json({ error: 'Playlist not found' });

    const fiveDaysAgo = new Date(Date.now() - 5 * 24 * 60 * 60 * 1000);
    // Since dynamic playlists are unique to the artist, not the user, we can safely cache them!
    let dbPlaylist = await DynamicPlaylist.findOne({ playlistId: playlistConfig.id });

    // Background refresh function using PlaylistIntelligence
    const refreshInBackground = async () => {
      try {
        console.log(`[HomeRoutes] Background refresh: ${playlistConfig.id} for user ${req.userId || 'anon'}`);
        const result = await PlaylistIntelligence.generate(playlistConfig, req.userId, {
          targetCount: 100,
          forceRefresh: true,
        });

        if (!result.songs || result.songs.length === 0) return;

        const formattedSongs = result.songs.map(s => ({
          videoId: s.videoId,
          title: s.title,
          artist: s.artist,
          thumbnailUrl: s.thumbnailUrl,
          durationMs: s.durationMs || 0,
          source: s.source || 'saavn',
          language: s.language,
          releaseYear: s.releaseYear,
        }));

        const firstThumb = formattedSongs[0]?.thumbnailUrl || playlistConfig.thumbnailUrl;

        await DynamicPlaylist.findOneAndUpdate(
          { playlistId: playlistConfig.id },
          {
            title: playlistConfig.title,
            description: playlistConfig.description,
            thumbnailUrl: firstThumb,
            songs: formattedSongs,
            updatedAt: new Date(),
          },
          { upsert: true, new: true }
        );
        console.log(`[HomeRoutes] Refreshed ${playlistConfig.id}: ${formattedSongs.length} songs`);
      } catch (err) {
        console.error(`[HomeRoutes] Background refresh failed for ${playlistConfig.id}:`, err.message);
      }
    };

    // Serve from cache if fresh
    if (dbPlaylist && dbPlaylist.songs && dbPlaylist.songs.length > 0) {
      const isStale = dbPlaylist.updatedAt < fiveDaysAgo;
      if (isStale) {
        refreshInBackground(); // non-blocking
      }

      return res.json({
        id: playlistConfig.id,
        title: playlistConfig.title,
        description: playlistConfig.description,
        thumbnailUrl: dbPlaylist.thumbnailUrl || playlistConfig.thumbnailUrl,
        songs: dbPlaylist.songs,
      });
    }

    // Cold cache — block and wait for initial generation
    await refreshInBackground();
    dbPlaylist = await DynamicPlaylist.findOne({ playlistId: playlistConfig.id });

    if (dbPlaylist && dbPlaylist.songs && dbPlaylist.songs.length > 0) {
      return res.json({
        id: playlistConfig.id,
        title: playlistConfig.title,
        description: playlistConfig.description,
        thumbnailUrl: dbPlaylist.thumbnailUrl || playlistConfig.thumbnailUrl,
        songs: dbPlaylist.songs,
      });
    }

    return res.status(500).json({ error: 'Failed to generate playlist' });
  } catch (error) {
    console.error('Playlist error:', error.message);
    res.status(500).json({ error: 'Failed to fetch playlist' });
  }
});

// ─── Charts / Trending ────────────────────────────────────────────────────────
const jwt = require('jsonwebtoken');
const TasteEngine = require('../services/TasteEngine');

router.get('/charts', async (req, res) => {
  try {
    let userId = null;
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      try {
        const token = authHeader.split(' ')[1];
        const payload = jwt.verify(token, process.env.JWT_SECRET);
        userId = payload.sub;
      } catch (e) {
        // ignore invalid token for optional auth
      }
    }

    let trendingStats = await SongStatistic.find()
      .sort({ trendScore: -1, popularityScore: -1 })
      .limit(100);

    // Apply personalization if user has a profile
    if (userId) {
      const profile = await UserMusicProfile.findOne({ userId });
      if (profile) {
        const langAffinity = profile.languageAffinity instanceof Map 
          ? Object.fromEntries(profile.languageAffinity) 
          : (profile.languageAffinity || {});
          
        const artistAffinity = profile.artistAffinity instanceof Map
          ? Object.fromEntries(profile.artistAffinity)
          : (profile.artistAffinity || {});

        trendingStats.sort((a, b) => {
          let aScore = a.trendScore + (a.popularityScore * 0.1);
          let bScore = b.trendScore + (b.popularityScore * 0.1);

          // Boost based on language
          const aLang = a.song && a.song.language ? a.song.language : 'Unknown';
          const bLang = b.song && b.song.language ? b.song.language : 'Unknown';
          if (langAffinity[aLang]) aScore *= (1 + langAffinity[aLang]);
          if (langAffinity[bLang]) bScore *= (1 + langAffinity[bLang]);

          // Boost based on artist
          if (a.song && a.song.artist) {
            const aArtists = a.song.artist.split(',').map(ar => ar.trim());
            for (const ar of aArtists) {
              const safeAr = TasteEngine.sanitizeKey(ar);
              if (artistAffinity[safeAr]) aScore *= (1 + artistAffinity[safeAr] * 2);
            }
          }
          if (b.song && b.song.artist) {
            const bArtists = b.song.artist.split(',').map(br => br.trim());
            for (const br of bArtists) {
              const safeBr = TasteEngine.sanitizeKey(br);
              if (artistAffinity[safeBr]) bScore *= (1 + artistAffinity[safeBr] * 2);
            }
          }
          return bScore - aScore;
        });
      }
    }

    trendingStats = trendingStats.slice(0, 20);
    let songs = trendingStats.map(stat => stat.song).filter(s => s != null);

    if (songs.length < 15) {
      // Cold start: pull from Global Top 100 playlist DB
      const globalDb = await DynamicPlaylist.findOne({ playlistId: 'global100' });
      if (globalDb && globalDb.songs && globalDb.songs.length > 0) {
        const existingIds = new Set(songs.map(s => s.videoId));
        const extras = globalDb.songs
          .filter(s => !existingIds.has(s.videoId))
          .slice(0, 20 - songs.length);
        songs.push(...extras);
      } else {
        // Last resort: live mainstream fetch
        const fallback = await MusicProvider.getMainstreamFallback('English', 20 - songs.length);
        const existingIds = new Set(songs.map(s => s.videoId));
        songs.push(...fallback.filter(s => !existingIds.has(s.videoId)));
      }
    }

    res.json(songs);
  } catch (error) {
    console.error('Charts error:', error.message);
    res.status(500).json({ error: 'Failed to fetch charts' });
  }
});

// ─── Moods (static config response) ───────────────────────────────────────────
router.get('/moods', async (req, res) => {
  // Return mood playlists from curated config
  const moodPlaylists = CURATED_PLAYLISTS.filter(p => p.type === 'Moods');
  
  try {
    const playlistIds = moodPlaylists.map(p => p.id);
    const dbPlaylists = await DynamicPlaylist.find({ playlistId: { $in: playlistIds } }).select('playlistId thumbnailUrl');
    const dbMap = new Map(dbPlaylists.map(db => [db.playlistId, db.thumbnailUrl]));

    res.json([
      {
        title: 'Moods & Genres',
        playlists: moodPlaylists.map(p => ({
          playlistId: p.id,
          title: p.title,
          description: p.description,
          thumbnailUrl: dbMap.get(p.id) || p.thumbnailUrl,
        }))
      }
    ]);
  } catch (err) {
    console.error('[HomeRoutes] Error fetching Moods DB thumbnails:', err.message);
    res.json([
      {
        title: 'Moods & Genres',
        playlists: moodPlaylists.map(p => ({
          playlistId: p.id,
          title: p.title,
          description: p.description,
          thumbnailUrl: p.thumbnailUrl,
        }))
      }
    ]);
  }
});

// ─── Mood Playlist: on-demand via PlaylistIntelligence ───────────────────────
router.get('/mood/:id', async (req, res) => {
  try {
    const moodId = req.params.id;

    // First, check if this is a known curated playlist ID
    const playlistConfig = CURATED_PLAYLISTS.find(p => p.id === moodId);

    if (playlistConfig) {
      // Check MongoDB cache first
      const dbPlaylist = await DynamicPlaylist.findOne({ playlistId: moodId });
      if (dbPlaylist && dbPlaylist.songs && dbPlaylist.songs.length > 0) {
        return res.json({
          id: playlistConfig.id,
          title: playlistConfig.title,
          description: playlistConfig.description,
          thumbnailUrl: dbPlaylist.thumbnailUrl || playlistConfig.thumbnailUrl,
          songs: dbPlaylist.songs,
        });
      }

      // Generate on demand
      const result = await PlaylistIntelligence.generate(playlistConfig, null, { targetCount: 30 });
      return res.json({
        id: playlistConfig.id,
        title: playlistConfig.title,
        description: playlistConfig.description,
        thumbnailUrl: playlistConfig.thumbnailUrl,
        songs: result.songs,
      });
    }

    // Unknown mood ID — generate dynamically using PlaylistIntentEngine
    const result = await PlaylistIntelligence.generate(moodId, null, { targetCount: 25 });
    return res.json({
      id: moodId,
      title: moodId,
      description: `${moodId} playlist`,
      thumbnailUrl: result.songs.length > 0 ? result.songs[0].thumbnailUrl : '',
      songs: result.songs,
    });
  } catch (error) {
    console.error('Mood playlist error:', error.message);
    res.status(500).json({ error: 'Failed to fetch mood playlist' });
  }
});

module.exports = router;
