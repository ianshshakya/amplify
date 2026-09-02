const express = require('express');
const MusicProvider = require('../services/MusicProvider');
const PlaylistIntelligence = require('../services/PlaylistIntelligence');
const DynamicPlaylist = require('../models/DynamicPlaylist');
const CURATED_PLAYLISTS = require('../config/playlists');

const router = express.Router();

// Home: return playlist cards instantly (metadata only, no tracks)
router.get('/', (req, res) => {
  res.json(CURATED_PLAYLISTS.map(p => ({
    id: p.id,
    title: p.title,
    type: p.type,
    description: p.description,
    thumbnailUrl: p.thumbnailUrl,
  })));
});

// ─── Playlist: return songs for a curated playlist ─────────────────────────────
// Uses stale-while-revalidate from MongoDB, with PlaylistIntelligence as the
// live generation engine when cache is cold or stale.
router.get('/playlist/:id', async (req, res) => {
  try {
    const playlistConfig = CURATED_PLAYLISTS.find(p => p.id === req.params.id);
    if (!playlistConfig) return res.status(404).json({ error: 'Playlist not found' });

    const fiveDaysAgo = new Date(Date.now() - 5 * 24 * 60 * 60 * 1000);
    let dbPlaylist = await DynamicPlaylist.findOne({ playlistId: playlistConfig.id });

    // Background refresh function using PlaylistIntelligence
    const refreshInBackground = async () => {
      try {
        console.log(`[HomeRoutes] Background refresh: ${playlistConfig.id}`);
        const result = await PlaylistIntelligence.generate(playlistConfig, null, {
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
const SongStatistic = require('../models/SongStatistic');

const jwt = require('jsonwebtoken');
const UserMusicProfile = require('../models/UserMusicProfile');

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
              if (artistAffinity[ar]) aScore *= (1 + artistAffinity[ar] * 2);
            }
          }
          if (b.song && b.song.artist) {
            const bArtists = b.song.artist.split(',').map(br => br.trim());
            for (const br of bArtists) {
              if (artistAffinity[br]) bScore *= (1 + artistAffinity[br] * 2);
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
router.get('/moods', (req, res) => {
  // Return mood playlists from curated config
  const moodPlaylists = CURATED_PLAYLISTS.filter(p => p.type === 'Moods');
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
