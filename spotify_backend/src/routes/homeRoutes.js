const express = require('express');
const { searchSaavn, getPlaylistTracks } = require('../utils/saavn');
const DynamicPlaylist = require('../models/DynamicPlaylist');

const router = express.Router();

const CURATED_PLAYLISTS = [
  // 🌟 Your Custom Songs
  { id: 'global100',     title: 'Global 100',             saavnPlaylistId: '947987697', query: 'Global Top 100',      description: 'The most popular songs across the globe right now.', thumbnailUrl: 'https://i.ytimg.com/vi/kffacxfA7G4/hq720.jpg' },
  
  // 🎤 Famous Singers (Indian)
  { id: 'arijitsingh',   title: 'Best of Arijit Singh',   saavnPlaylistId: '1191141029', query: 'Arijit Singh Best Songs', description: 'Soulful melodies by Arijit Singh.', thumbnailUrl: 'https://i.ytimg.com/vi/nyuo9-OjNNg/hq720.jpg' },
  { id: 'shreyaghoshal', title: 'Shreya Ghoshal Hits',    saavnPlaylistId: '902531265', query: 'Shreya Ghoshal Hits',     description: 'The melodious voice of Shreya Ghoshal.', thumbnailUrl: 'https://i.ytimg.com/vi/5S5F-W02D5c/hq720.jpg' },
  { id: 'kishorekumar',  title: 'Kishore Kumar Classics', saavnPlaylistId: '902524769', query: 'Kishore Kumar Old Hits',  description: 'Golden hits from the legendary Kishore Kumar.', thumbnailUrl: 'https://i.ytimg.com/vi/5v-hWlVfJb8/hq720.jpg' },

  // 🌍 Famous Singers (Global)
  { id: 'taylorswift',   title: 'Taylor Swift Essentials',saavnPlaylistId: '280083933', query: 'Taylor Swift Top Tracks', description: 'The biggest hits from Taylor Swift.', thumbnailUrl: 'https://i.ytimg.com/vi/K-a8s8Dg-68/hq720.jpg' },
  { id: 'theweeknd',     title: 'The Weeknd Hits',        saavnPlaylistId: '1298998788', query: 'The Weeknd Best Songs',   description: 'Dark R&B and pop anthems.', thumbnailUrl: 'https://i.ytimg.com/vi/XXYlCGK8Q08/hq720.jpg' },
  { id: 'justinbieber',  title: 'Justin Bieber Pop',      saavnPlaylistId: '52312344', query: 'Justin Bieber Hits',      description: 'Global pop hits by Justin Bieber.', thumbnailUrl: 'https://i.ytimg.com/vi/tQ0yjYUFKAE/hq720.jpg' },

  // 🎵 Categories
  { id: 'pophits',       title: 'Pop Hits 2024',          saavnPlaylistId: '1219734885', query: 'Pop Hits 2024',           description: 'The biggest pop anthems right now.', thumbnailUrl: 'https://i.ytimg.com/vi/h2-xVjB3HFE/hq720.jpg' },
  { id: 'indianclassic', title: 'Indian Classical Vibes', saavnPlaylistId: '112761792', query: 'Indian Classical Sitar Flute',description: 'Relaxing traditional Indian classical music.', thumbnailUrl: 'https://i.ytimg.com/vi/Oqf9X055kZ4/hq720.jpg' },
  { id: 'globalclassic', title: 'Classical Masterpieces', saavnPlaylistId: '112761792', query: 'Beethoven Mozart Classical',description: 'Timeless global classical music.', thumbnailUrl: 'https://i.ytimg.com/vi/4Tr0otuiQuU/hq720.jpg' },
  { id: 'oldbollywood',  title: '90s Bollywood Classics', saavnPlaylistId: '1167751266', query: '90s Bollywood Hits',      description: 'Nostalgic hits from the 90s.', thumbnailUrl: 'https://i.ytimg.com/vi/L7sq3bWl4zU/hq720.jpg' },
  { id: 'oldglobal',     title: '80s & 90s Retro Global', saavnPlaylistId: '1261294941', query: '80s 90s Retro Pop Hits',  description: 'The best throwbacks of the 80s and 90s.', thumbnailUrl: 'https://i.ytimg.com/vi/djV11Xbc914/hq720.jpg' },
  
  // 🔥 Trending / New
  { id: 'newhindi',      title: 'New Releases (Hindi)',   saavnPlaylistId: '1219706044', query: 'New Hindi Songs 2024',    description: 'Fresh Bollywood and Indie tracks.', thumbnailUrl: 'https://i.ytimg.com/vi/NX5yDs_TLqA/hq720.jpg' },
  { id: 'newglobal',     title: 'New Releases (Global)',  saavnPlaylistId: '1219734666', query: 'New English Songs 2024',  description: 'The hottest new music around the world.', thumbnailUrl: 'https://i.ytimg.com/vi/kffacxfA7G4/hq720.jpg' },
  { id: 'punjabihits',   title: 'Trending Punjabi',       saavnPlaylistId: '1219735384', query: 'Punjabi Hits 2024',       description: 'High energy Punjabi bangers.', thumbnailUrl: 'https://i.ytimg.com/vi/1zNlsL1E10w/hq720.jpg' },
];

// Home: return playlist cards instantly
router.get('/', (req, res) => {
  res.json(CURATED_PLAYLISTS);
});

// Playlist: return songs for a curated playlist
router.get('/playlist/:id', async (req, res) => {
  try {
    const playlist = CURATED_PLAYLISTS.find(p => p.id === req.params.id);
    if (!playlist) return res.status(404).json({ error: 'Playlist not found' });

    // 1. Check if playlist exists in DB and is fresh (< 5 days old)
    let dbPlaylist = await DynamicPlaylist.findOne({ playlistId: playlist.id });
    // TEMPORARY: Set expiration to future to force refresh of all playlists
    // (Overrides old cached playlists that were fetched using string search instead of playlist IDs)
    const fiveDaysAgo = new Date(Date.now() + 5000000); 

    if (dbPlaylist && dbPlaylist.updatedAt > fiveDaysAgo && dbPlaylist.songs && dbPlaylist.songs.length > 0) {
      return res.json({
        id: playlist.id,
        title: playlist.title,
        description: playlist.description,
        thumbnailUrl: dbPlaylist.thumbnailUrl || playlist.thumbnailUrl,
        songs: dbPlaylist.songs,
      });
    }

    // 2. Not found or stale, fetch new songs
    let songs = [];
    if (playlist.saavnPlaylistId) {
      songs = await getPlaylistTracks(playlist.saavnPlaylistId, 50);
    } else {
      songs = await searchSaavn(playlist.query, 30);
    }
    
    // Map Saavn 'duration' to 'durationMs' to fix Flutter 0-duration bug
    const formattedSongs = songs.map(s => ({
      videoId: s.videoId,
      title: s.title,
      artist: s.artist,
      thumbnailUrl: s.thumbnailUrl,
      durationMs: s.duration * 1000, 
      source: 'saavn'
    }));

    const firstThumb = formattedSongs.length > 0 ? formattedSongs[0].thumbnailUrl : playlist.thumbnailUrl;

    // 3. Save or Update in Database
    if (dbPlaylist) {
      dbPlaylist.songs = formattedSongs;
      dbPlaylist.thumbnailUrl = firstThumb;
      dbPlaylist.updatedAt = new Date();
      await dbPlaylist.save();
    } else {
      dbPlaylist = new DynamicPlaylist({
        playlistId: playlist.id,
        title: playlist.title,
        description: playlist.description,
        thumbnailUrl: firstThumb,
        songs: formattedSongs
      });
      await dbPlaylist.save();
    }

    res.json({
      id: playlist.id,
      title: playlist.title,
      description: playlist.description,
      thumbnailUrl: firstThumb,
      songs: formattedSongs,
    });
  } catch (error) {
    console.error('Playlist error:', error.message);
    res.status(500).json({ error: 'Failed to fetch playlist' });
  }
});

const SongStatistic = require('../models/SongStatistic');

// Charts / Trending (Dynamic)
router.get('/charts', async (req, res) => {
  try {
    // 1. Fetch top trending songs from our ML aggregation
    const trendingStats = await SongStatistic.find()
      .sort({ trendScore: -1, popularityScore: -1 })
      .limit(20);

    let songs = trendingStats.map(stat => stat.song).filter(s => s != null);

    // 2. Cold Start Fallback: If we don't have enough internal analytics yet,
    // pad the charts with global hits from Saavn to ensure a good UX.
    if (songs.length < 15) {
      // 1219706044 is "Chartbusters 2024 - Hindi"
      const fallbackSongs = await getPlaylistTracks('1219706044', 20 - songs.length);
      
      // Deduplicate fallback songs that might already be in our internal trending list
      const existingIds = new Set(songs.map(s => s.videoId));
      for (const fallback of fallbackSongs) {
        if (!existingIds.has(fallback.videoId)) {
          songs.push(fallback);
        }
      }
    }

    res.json(songs);
  } catch (error) {
    console.error('Charts error:', error.message);
    res.status(500).json({ error: 'Failed to fetch charts' });
  }
});

// Moods
router.get('/moods', async (req, res) => {
  // Return the fallback mood categories from the app directly, or empty to let app handle it.
  // The app will use fallbacks if it fails.
  res.status(500).json({ error: 'Use fallback moods' }); 
});

// Mood Playlist
router.get('/mood/:id', async (req, res) => {
  try {
    const songs = await searchSaavn(`${req.params.id} music`, 20);
    res.json({
      id: req.params.id,
      title: req.params.id,
      description: 'Mood playlist',
      thumbnailUrl: songs.length > 0 ? songs[0].thumbnailUrl : '',
      songs: songs,
    });
  } catch (error) {
    console.error('Mood playlist error:', error.message);
    res.status(500).json({ error: 'Failed to fetch mood' });
  }
});

module.exports = router;
