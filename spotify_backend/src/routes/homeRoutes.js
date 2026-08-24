const express = require('express');
const { searchSaavn, getPlaylistTracks, fetchSpotifyPlaylistTracks } = require('../utils/saavn');
const DynamicPlaylist = require('../models/DynamicPlaylist');

const router = express.Router();

const CURATED_PLAYLISTS = [
  // 🌟 Your Custom Songs
  { id: 'global100',     title: 'Global 100',             spotifyUrl: 'https://open.spotify.com/playlist/37i9dQZEVXbMDoHDwVN2tF', saavnPlaylistId: '947987697', description: 'The most popular songs across the globe right now.', thumbnailUrl: 'https://i.ytimg.com/vi/kffacxfA7G4/hq720.jpg' },
  
  // 🎤 Famous Singers (Indian)
  { id: 'arijitsingh',   title: 'Best of Arijit Singh',   spotifyUrl: 'https://open.spotify.com/playlist/37i9dQZF1DZ06evO05tE88', saavnPlaylistId: '1191141029', description: 'Soulful melodies by Arijit Singh.', thumbnailUrl: 'https://i.ytimg.com/vi/nyuo9-OjNNg/hq720.jpg' },
  { id: 'shreyaghoshal', title: 'Shreya Ghoshal Hits',    spotifyUrl: 'https://open.spotify.com/playlist/37i9dQZF1DZ06evO4pK1Vb', saavnPlaylistId: '902531265', description: 'The melodious voice of Shreya Ghoshal.', thumbnailUrl: 'https://i.ytimg.com/vi/5S5F-W02D5c/hq720.jpg' },
  { id: 'kishorekumar',  title: 'Kishore Kumar Classics', spotifyUrl: 'https://open.spotify.com/playlist/37i9dQZF1DZ06evO0E7uO4', saavnPlaylistId: '902524769', description: 'Golden hits from the legendary Kishore Kumar.', thumbnailUrl: 'https://i.ytimg.com/vi/5v-hWlVfJb8/hq720.jpg' },

  // 🌍 Famous Singers (Global)
  { id: 'taylorswift',   title: 'Taylor Swift Essentials',spotifyUrl: 'https://open.spotify.com/playlist/37i9dQZF1DX5KpP2LN299J', saavnPlaylistId: '280083933', description: 'The biggest hits from Taylor Swift.', thumbnailUrl: 'https://i.ytimg.com/vi/K-a8s8Dg-68/hq720.jpg' },
  { id: 'theweeknd',     title: 'The Weeknd Hits',        spotifyUrl: 'https://open.spotify.com/playlist/37i9dQZF1DX6bnzK9KPvrz', saavnPlaylistId: '1298998788', description: 'Dark R&B and pop anthems.', thumbnailUrl: 'https://i.ytimg.com/vi/XXYlCGK8Q08/hq720.jpg' },
  { id: 'justinbieber',  title: 'Justin Bieber Pop',      spotifyUrl: 'https://open.spotify.com/playlist/37i9dQZF1DXc2CEJUyDOaA', saavnPlaylistId: '52312344', description: 'Global pop hits by Justin Bieber.', thumbnailUrl: 'https://i.ytimg.com/vi/tQ0yjYUFKAE/hq720.jpg' },

  // 🎵 Categories
  { id: 'pophits',       title: 'Pop Hits 2024',          spotifyUrl: 'https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M', saavnPlaylistId: '1219734885', description: 'The biggest pop anthems right now.', thumbnailUrl: 'https://i.ytimg.com/vi/h2-xVjB3HFE/hq720.jpg' },
  { id: 'indianclassic', title: 'Indian Classical Vibes', spotifyUrl: 'https://open.spotify.com/playlist/37i9dQZF1DXcb6CQJbbALs', saavnPlaylistId: '112761792', description: 'Relaxing traditional Indian classical music.', thumbnailUrl: 'https://i.ytimg.com/vi/Oqf9X055kZ4/hq720.jpg' },
  { id: 'globalclassic', title: 'Classical Masterpieces', spotifyUrl: 'https://open.spotify.com/playlist/37i9dQZF1DWWEJlNEYEYUh', saavnPlaylistId: '112761792', description: 'Timeless global classical music.', thumbnailUrl: 'https://i.ytimg.com/vi/4Tr0otuiQuU/hq720.jpg' },
  { id: 'oldbollywood',  title: '90s Bollywood Classics', spotifyUrl: 'https://open.spotify.com/playlist/37i9dQZF1DX3I39a2v0U3N', saavnPlaylistId: '1167751266', description: 'Nostalgic hits from the 90s.', thumbnailUrl: 'https://i.ytimg.com/vi/L7sq3bWl4zU/hq720.jpg' },
  { id: 'oldglobal',     title: '80s & 90s Retro Global', spotifyUrl: 'https://open.spotify.com/playlist/37i9dQZF1DX4UtSsVN1Wsw', saavnPlaylistId: '1261294941', description: 'The best throwbacks of the 80s and 90s.', thumbnailUrl: 'https://i.ytimg.com/vi/djV11Xbc914/hq720.jpg' },
  
  // 🔥 Trending / New
  { id: 'newhindi',      title: 'New Releases (Hindi)',   spotifyUrl: 'https://open.spotify.com/playlist/37i9dQZF1DX0XUfTFmNBRM', saavnPlaylistId: '1219706044', description: 'Fresh Bollywood and Indie tracks.', thumbnailUrl: 'https://i.ytimg.com/vi/NX5yDs_TLqA/hq720.jpg' },
  { id: 'newglobal',     title: 'New Releases (Global)',  spotifyUrl: 'https://open.spotify.com/playlist/37i9dQZF1DX4JAvHpjipBk', saavnPlaylistId: '1219734666', description: 'The hottest new music around the world.', thumbnailUrl: 'https://i.ytimg.com/vi/kffacxfA7G4/hq720.jpg' },
  { id: 'punjabihits',   title: 'Trending Punjabi',       spotifyUrl: 'https://open.spotify.com/playlist/37i9dQZF1DX5cZuAHLNjGz', saavnPlaylistId: '1219735384', description: 'High energy Punjabi bangers.', thumbnailUrl: 'https://i.ytimg.com/vi/1zNlsL1E10w/hq720.jpg' },
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

    // 1. Stale-While-Revalidate Caching Pattern
    let dbPlaylist = await DynamicPlaylist.findOne({ playlistId: playlist.id });
    const fiveDaysAgo = new Date(Date.now() - 5 * 24 * 60 * 60 * 1000);
    
    // Background worker function to refresh the playlist without blocking the user
    const refreshPlaylistInBackground = async () => {
      try {
        let songs = [];
        if (playlist.spotifyUrl) {
          songs = await fetchSpotifyPlaylistTracks(playlist.spotifyUrl, 40, playlist.saavnPlaylistId);
        } else {
          songs = await getPlaylistTracks(playlist.saavnPlaylistId || '', 40);
        }
        
        if (!songs || songs.length === 0) return; // Fetch failed completely, keep old cache

        const formattedSongs = songs.map(s => ({
          videoId: s.videoId,
          title: s.title,
          artist: s.artist,
          thumbnailUrl: s.thumbnailUrl,
          durationMs: s.duration * 1000, 
          source: 'saavn'
        }));

        const firstThumb = formattedSongs.length > 0 ? formattedSongs[0].thumbnailUrl : playlist.thumbnailUrl;

        if (dbPlaylist) {
          dbPlaylist.songs = formattedSongs;
          dbPlaylist.thumbnailUrl = firstThumb;
          dbPlaylist.updatedAt = new Date();
          await dbPlaylist.save();
        } else {
          const newDb = new DynamicPlaylist({
            playlistId: playlist.id,
            title: playlist.title,
            description: playlist.description,
            thumbnailUrl: firstThumb,
            songs: formattedSongs
          });
          await newDb.save();
        }
      } catch (err) {
        console.error(`Background refresh failed for ${playlist.id}:`, err.message);
      }
    };

    if (dbPlaylist && dbPlaylist.songs && dbPlaylist.songs.length > 0) {
      const isStale = dbPlaylist.updatedAt < fiveDaysAgo;
      
      // If it's stale, fire the background worker but DO NOT wait for it!
      if (isStale) {
        refreshPlaylistInBackground();
      }

      // Immediately return the cached (or stale) data to the user for instant load times
      return res.json({
        id: playlist.id,
        title: playlist.title,
        description: playlist.description,
        thumbnailUrl: dbPlaylist.thumbnailUrl || playlist.thumbnailUrl,
        songs: dbPlaylist.songs,
      });
    }

    // 2. No cache at all - we MUST block and wait
    await refreshPlaylistInBackground();
    dbPlaylist = await DynamicPlaylist.findOne({ playlistId: playlist.id });
    
    if (dbPlaylist) {
      return res.json({
        id: playlist.id,
        title: playlist.title,
        description: playlist.description,
        thumbnailUrl: dbPlaylist.thumbnailUrl,
        songs: dbPlaylist.songs,
      });
    }
    
    return res.status(500).json({ error: 'Failed to fetch playlist initially' });
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
      // Spotify Top 50 Global as fallback
      const fallbackSongs = await fetchSpotifyPlaylistTracks('https://open.spotify.com/playlist/37i9dQZEVXbMDoHDwVN2tF', 20 - songs.length);
      
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
