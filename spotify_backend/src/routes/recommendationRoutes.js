const express = require('express');
const requireAuth = require('../middleware/requireAuth');
const RecommendationEngine = require('../services/RecommendationEngine');
const PlaylistIntelligence = require('../services/PlaylistIntelligence');
const { parseIntent } = require('../services/PlaylistIntentEngine');
const UserMusicProfile = require('../models/UserMusicProfile');
const MusicProvider = require('../services/MusicProvider');

const router = express.Router();
router.use(requireAuth);

/**
 * @route GET /api/recommendations/daily-mix
 * @desc Get a personalized mix for the authenticated user
 */
router.get('/daily-mix', async (req, res) => {
  try {
    const songs = await RecommendationEngine.getDailyMix(req.userId);
    res.json({
      id: 'daily-mix',
      title: 'Daily Mix',
      description: 'Made for you.',
      thumbnailUrl: songs.length > 0 ? songs[0].thumbnailUrl : '',
      songs,
    });
  } catch (error) {
    console.error('Daily Mix route error:', error.message);
    res.status(500).json({ error: 'Failed to generate recommendations' });
  }
});

/**
 * @route GET /api/recommendations/made-for-you
 * @desc Get multiple curated playlists based on user's language and artist affinities
 */
router.get('/made-for-you', async (req, res) => {
  try {
    const profile = await UserMusicProfile.findOne({ userId: req.userId });
    if (!profile) return res.json([]);

    const languageAffinity = Object.entries(profile.languageAffinity || {}).sort((a, b) => b[1] - a[1]);
    const artistAffinity = Object.entries(profile.artistAffinity || {}).sort((a, b) => b[1] - a[1]);
    
    let playlists = [];

    // 1. Daily Mix (Always present if they have profile)
    playlists.push({
      id: 'daily_mix',
      title: 'Daily Mix',
      type: 'Made For You',
      strategy: 'mix',
      searchQuery: '',
      description: 'A mix of your favorite tracks and new discoveries.',
      thumbnailUrl: ''
    });

    // 2. Discover Weekly (High discovery)
    playlists.push({
      id: 'discover_weekly',
      title: 'Discover Weekly',
      type: 'Made For You',
      strategy: 'discover',
      searchQuery: '',
      description: 'Fresh music tailored to your taste, updated every week.',
      thumbnailUrl: ''
    });

    // 3. Artist Mix (If they have favorite artists)
    if (artistAffinity.length > 0) {
      const topArtist = artistAffinity[0][0];
      playlists.push({
        id: `artist_mix_${topArtist.toLowerCase().replace(/[^a-z0-9]/g, '_')}`,
        title: `${topArtist} Mix`,
        type: 'Made For You',
        strategy: 'artist',
        searchQuery: topArtist,
        description: `Music from ${topArtist} and similar artists.`,
        thumbnailUrl: ''
      });
    }

    // 4. Language Hits (If they have favorite languages)
    if (languageAffinity.length > 0) {
      const topLang = languageAffinity[0][0];
      playlists.push({
        id: `language_mix_${topLang.toLowerCase()}`,
        title: `${topLang} Hits Mix`,
        type: 'Made For You',
        strategy: 'language',
        searchQuery: `${topLang} best songs`,
        description: `The best of ${topLang} music, curated for you.`,
        thumbnailUrl: ''
      });
    }

    res.json(playlists);
  } catch (error) {
    console.error('Made For You route error:', error.message);
    res.status(500).json({ error: 'Failed to fetch made-for-you' });
  }
});

/**
 * @route GET /api/recommendations/top-artists
 * @desc Get user's top artists with their profile images
 */
router.get('/top-artists', async (req, res) => {
  try {
    const profile = await UserMusicProfile.findOne({ userId: req.userId });
    if (!profile || !profile.artistAffinity) return res.json([]);

    const sortedArtists = Object.entries(profile.artistAffinity)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 8)
      .map(entry => entry[0]);

    if (sortedArtists.length === 0) return res.json([]);

    // Fetch images for each artist from JioSaavn
    const artistPromises = sortedArtists.map(async (artistName) => {
      try {
        const results = await MusicProvider.searchArtist(artistName, 1);
        if (results && results.length > 0) {
          return {
            name: artistName,
            thumbnailUrl: results[0].imageUrl
          };
        }
      } catch (e) {
        console.error(`Error fetching artist image for ${artistName}:`, e.message);
      }
      return { name: artistName, thumbnailUrl: '' };
    });

    const artistsWithImages = await Promise.all(artistPromises);
    res.json(artistsWithImages);

  } catch (error) {
    console.error('Top Artists route error:', error.message);
    res.status(500).json({ error: 'Failed to fetch top-artists' });
  }
});

/**
 * @route GET /api/recommendations/radio/song/:id
 * @desc Get a radio queue from a seed song. Supports session context via query params.
 */
router.get('/radio/song/:id', async (req, res) => {
  try {
    // Parse optional session context from query string
    // e.g. ?recentArtists=Arijit+Singh,Taylor+Swift&recentIds=songId1,songId2
    const recentArtists = req.query.recentArtists
      ? req.query.recentArtists.split(',').map(s => s.trim())
      : [];
    const recentSongIds = req.query.recentIds
      ? req.query.recentIds.split(',').map(s => s.trim())
      : [];

    const sessionContext = { recentArtists, recentSongIds };
    const songs = await RecommendationEngine.getSongRadio(
      req.params.id, req.userId, 15, sessionContext
    );
    res.json(songs);
  } catch (error) {
    console.error('Song Radio route error:', error.message);
    res.status(500).json({ error: 'Failed to generate radio' });
  }
});

/**
 * @route GET /api/recommendations/radio/artist/:name
 * @desc Get a radio stream for an artist
 */
router.get('/radio/artist/:name', async (req, res) => {
  try {
    const songs = await RecommendationEngine.getArtistRadio(req.params.name, req.userId);
    res.json(songs);
  } catch (error) {
    console.error('Artist Radio route error:', error.message);
    res.status(500).json({ error: 'Failed to generate artist radio' });
  }
});

/**
 * @route GET /api/recommendations/one-song-away
 * @desc Get a single high-confidence discovery track
 */
router.get('/one-song-away', async (req, res) => {
  try {
    const song = await RecommendationEngine.getOneSongAway(req.userId);
    if (!song) return res.status(404).json({ error: 'No discovery track found right now' });
    res.json(song);
  } catch (error) {
    console.error('One Song Away route error:', error.message);
    res.status(500).json({ error: 'Failed to fetch discovery track' });
  }
});

/**
 * @route POST /api/recommendations/playlist
 * @desc Generate a playlist from a natural language intent or playlist config.
 *       Body: { intent: string | object, targetCount?: number, debug?: boolean }
 */
router.post('/playlist', async (req, res) => {
  try {
    const { intent, targetCount = 30, debug = false } = req.body;
    if (!intent) return res.status(400).json({ error: 'Missing intent field' });

    const result = await PlaylistIntelligence.generate(intent, req.userId, {
      targetCount,
      debugMode: debug,
      forceRefresh: true,
    });

    res.json({
      id: 'custom-playlist',
      title: typeof intent === 'string' ? intent : (intent.title || 'Custom Playlist'),
      description: 'Generated by Amplify Intelligence',
      songs: result.songs,
      meta: result.meta,
    });
  } catch (error) {
    console.error('Playlist generation error:', error.message);
    res.status(500).json({ error: 'Failed to generate playlist' });
  }
});

/**
 * @route POST /api/recommendations/next
 * @desc Get the next batch of tracks for dynamic autoplay.
 *       Body: { currentSong: Track, sessionHistory: string[], sessionArtists: string[] }
 */
router.post('/next', async (req, res) => {
  try {
    const { currentSong, sessionHistory = [], sessionArtists = [] } = req.body;
    if (!currentSong) return res.status(400).json({ error: 'Missing currentSong' });

    const sessionContext = {
      recentSongIds: sessionHistory,
      recentArtists: sessionArtists,
    };

    const tracks = await PlaylistIntelligence.getRadioTracks(
      currentSong, sessionContext, req.userId, 8
    );
    res.json(tracks);
  } catch (error) {
    console.error('Next tracks error:', error.message);
    res.status(500).json({ error: 'Failed to get next tracks' });
  }
});

/**
 * @route POST /api/recommendations/similar
 * @desc Get tracks similar to a given song.
 *       Body: { song: Track }
 */
router.post('/similar', async (req, res) => {
  try {
    const { song } = req.body;
    if (!song) return res.status(400).json({ error: 'Missing song field' });

    const tracks = await PlaylistIntelligence.getSimilar(song, req.userId, 20);
    res.json(tracks);
  } catch (error) {
    console.error('Similar tracks error:', error.message);
    res.status(500).json({ error: 'Failed to get similar tracks' });
  }
});

/**
 * @route GET /api/recommendations/discover
 * @desc Get a personalised discovery playlist
 */
router.get('/discover', async (req, res) => {
  try {
    const result = await PlaylistIntelligence.discover(req.userId, 25);
    res.json({
      id: 'discover',
      title: 'Discover New Music',
      description: 'Songs you might not have heard yet.',
      thumbnailUrl: result.songs.length > 0 ? result.songs[0].thumbnailUrl : '',
      songs: result.songs,
    });
  } catch (error) {
    console.error('Discover error:', error.message);
    res.status(500).json({ error: 'Failed to generate discovery playlist' });
  }
});

/**
 * @route POST /api/recommendations/voice-intent
 * @desc Parse a raw voice text string into a structured VoiceCommand JSON.
 *       Uses the existing rule-based PlaylistIntentEngine — no LLM required.
 *       Body: { text, currentSong?, currentArtist?, sessionHistory?, sessionArtists? }
 */
router.post('/voice-intent', async (req, res) => {
  try {
    const { text, currentSong, currentArtist, sessionHistory = [], sessionArtists = [] } = req.body;
    if (!text || typeof text !== 'string') {
      return res.status(400).json({ error: 'Missing text field' });
    }

    const normalized = text.trim().toLowerCase();

    // ── AI NLP with Groq (if key is present) ─────────────────────────────────
    const groqKey = process.env.GROQ_API_KEY;
    if (groqKey) {
      try {
        const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${groqKey}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            model: 'llama-3.3-70b-versatile',
            messages: [
              {
                role: 'system',
                content: `You are Bingo, an advanced AI music assistant built into the Amplify music app.
Analyze the user's input and return ONLY a valid JSON object matching this schema:
{
  "intent": "play|pause|next|searchAndPlay|recommendation|openHome|openSearch|openLibrary|chat|unknown",
  "query": "string (for searchAndPlay - extract ONLY the core entity name, omitting words like 'by', 'songs from', e.g. 'play by taylor swift' -> 'taylor swift')",
  "mood": "string (for recommendation e.g. chill, energetic, sad)",
  "energy": "low|medium|high",
  "explanation": "short string explaining action",
  "suggestedSongs": [{"title": "Song Name", "artist": "Artist Name"}], // ONLY if intent is recommendation. Provide 5-8 exact songs that perfectly match the mood/vibe.
  "chatResponse": "string" // ONLY if intent is 'chat'. Provide a conversational, helpful, and concise answer to the user's general question.
}
Current song playing: ${currentSong || 'None'}.
Do not output markdown, do not output anything other than JSON.`
              },
              { role: 'user', content: text }
            ],
            response_format: { type: 'json_object' },
            temperature: 0.1
          })
        });

        if (response.ok) {
          const data = await response.json();
          const content = data.choices[0].message.content;
          return res.json(JSON.parse(content));
        }
      } catch (err) {
        console.error('Groq API error, falling back to local parsing:', err.message);
      }
    }

    // ── Map common voice phrases to structured commands (Fallback) ───────────

    // Simple playback (these are handled deterministically on the client,
    // but we keep them here as a fallback)
    if (/^(play|resume|unpause|continue)$/.test(normalized)) {
      return res.json({ intent: 'play', explanation: 'Resuming playback' });
    }
    if (/^(pause|stop)$/.test(normalized)) {
      return res.json({ intent: 'pause', explanation: 'Pausing' });
    }
    if (/^(next|skip|next song|next track)$/.test(normalized)) {
      return res.json({ intent: 'next', explanation: 'Skipping to next' });
    }

    // "Play [song/artist]" — anything that starts with "play" + content
    const playQueryMatch = normalized.match(/^(?:play|search for|find)(?:\s+(?:songs|something|music))?(?:\s+(?:by|from))?\s+(.+)$/);
    if (playQueryMatch) {
      const query = playQueryMatch[1];
      // Avoid treating mood requests as search queries
      const moodWords = ['something', 'some music', 'a song', 'me music', 'music'];
      const isMoodRequest = moodWords.some(w => query.startsWith(w)) || 
                            /\b(chill|relax|energet|happy|sad|calm|workout|party|focus|study)\b/.test(query);
      if (!isMoodRequest) {
        return res.json({ intent: 'searchAndPlay', query, explanation: `Searching for "${query}"` });
      }
    }

    // ── Mood / Energy / Recommendation requests ──────────────────────────────
    // Use the PlaylistIntentEngine to extract archetype
    const intent = parseIntent(normalized);

    const moodMap = {
      workout: { mood: 'energetic', energy: 'high' },
      party:   { mood: 'energetic', energy: 'high' },
      chill:   { mood: 'chill',     energy: 'low'  },
      relax:   { mood: 'chill',     energy: 'low'  },
      focus:   { mood: 'focus',     energy: 'medium' },
      romance: { mood: 'romantic',  energy: 'low'  },
      nostalgia: { mood: 'nostalgic', energy: 'medium' },
      discover: { mood: 'discover', energy: 'medium' },
      'hip-hop': { mood: 'hip-hop', energy: 'high' },
      charts:  { mood: 'popular',   energy: 'medium' },
    };

    const moodInfo = moodMap[intent.purpose] || { mood: intent.purpose || 'popular', energy: 'medium' };

    // Build a human-readable explanation
    let explanation = `Finding ${moodInfo.mood} music`;
    if (currentSong) explanation += ` based on "${currentSong}"`;

    return res.json({
      intent: 'recommendation',
      mood: moodInfo.mood,
      energy: moodInfo.energy,
      purpose: intent.purpose,
      explanation,
    });

  } catch (error) {
    console.error('Voice intent error:', error.message);
    res.status(500).json({ error: 'Failed to parse voice intent' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// NEW: Gap 3 — Made For You: multiple user-specific playlist stubs
// ─────────────────────────────────────────────────────────────────────────────
const UserMusicProfile = require('../models/UserMusicProfile');
const MusicProvider = require('../services/MusicProvider');

/**
 * @route GET /api/recommendations/made-for-you
 * @desc Returns 3-5 personalized playlist stubs + songs based on user taste dimensions
 */
router.get('/made-for-you', async (req, res) => {
  try {
    const profile = await UserMusicProfile.findOne({ userId: req.userId });

    // Cold-start: return the standard daily mix as a single stub
    if (!profile || (!profile.artistAffinity?.size && !profile.languageAffinity?.size)) {
      const dailySongs = await RecommendationEngine.getDailyMix(req.userId);
      return res.json([{
        id: 'daily-mix',
        title: 'Your Daily Mix',
        description: 'A personalized mix just for you.',
        thumbnailUrl: dailySongs[0]?.thumbnailUrl || '',
        songs: dailySongs.slice(0, 20),
      }]);
    }

    const artistAffinity = profile.artistAffinity instanceof Map
      ? Object.fromEntries(profile.artistAffinity) : (profile.artistAffinity || {});
    const languageAffinity = profile.languageAffinity instanceof Map
      ? Object.fromEntries(profile.languageAffinity) : (profile.languageAffinity || {});

    const playlists = [];

    // 1. General daily mix (always first)
    const dailySongs = await RecommendationEngine.getDailyMix(req.userId);
    if (dailySongs.length > 0) {
      playlists.push({
        id: 'daily-mix',
        title: 'Daily Mix',
        description: 'Your personalized everyday mix.',
        thumbnailUrl: dailySongs[0]?.thumbnailUrl || '',
        songs: dailySongs.slice(0, 20),
      });
    }

    // 2. Top artist mixes (up to 2)
    const topArtists = Object.entries(artistAffinity)
      .sort((a, b) => b[1] - a[1])
      .map(e => e[0].replace(/_/g, ' '))
      .slice(0, 2);

    for (const artist of topArtists) {
      try {
        const intentInput = {
          id: `mfy_${artist}`,
          title: `More of ${artist}`,
          description: `Because you love ${artist}`,
          intent: { popularity: 'high', discovery: 'low' },
        };
        const result = await PlaylistIntelligence.generate(intentInput, req.userId, {
          targetCount: 20,
          forceRefresh: false,
        });
        if (result.songs.length > 0) {
          playlists.push({
            id: `mfy_artist_${artist.replace(/\s+/g, '_').toLowerCase()}`,
            title: `More of ${artist}`,
            description: `Because you love ${artist}`,
            thumbnailUrl: result.songs[0]?.thumbnailUrl || '',
            songs: result.songs.slice(0, 20),
          });
        }
      } catch (e) {
        console.warn(`[MadeForYou] Artist mix failed for ${artist}:`, e.message);
      }
    }

    // 3. Top language mix
    const topLanguage = Object.entries(languageAffinity)
      .sort((a, b) => b[1] - a[1])
      .map(e => e[0])[0];

    if (topLanguage && topLanguage !== 'Unknown') {
      try {
        const intentInput = {
          id: `mfy_lang_${topLanguage}`,
          title: `${topLanguage} Hits for You`,
          description: `Your favorite ${topLanguage} songs`,
          intent: { languages: [topLanguage], popularity: 'high', discovery: 'medium' },
        };
        const result = await PlaylistIntelligence.generate(intentInput, req.userId, {
          targetCount: 20,
          forceRefresh: false,
        });
        if (result.songs.length > 0) {
          playlists.push({
            id: `mfy_lang_${topLanguage.toLowerCase()}`,
            title: `${topLanguage} Hits for You`,
            description: `Your favorite ${topLanguage} songs`,
            thumbnailUrl: result.songs[0]?.thumbnailUrl || '',
            songs: result.songs.slice(0, 20),
          });
        }
      } catch (e) {
        console.warn('[MadeForYou] Language mix failed:', e.message);
      }
    }

    res.json(playlists);
  } catch (error) {
    console.error('Made For You error:', error.message);
    res.status(500).json({ error: 'Failed to generate Made For You playlists' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// NEW: Gap 4 — Top Artists from user taste profile
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @route GET /api/recommendations/top-artists
 * @desc Returns top 8 artists from the user's taste profile with image URLs
 */
router.get('/top-artists', async (req, res) => {
  try {
    const profile = await UserMusicProfile.findOne({ userId: req.userId });

    let topArtistNames = [];

    if (profile && profile.artistAffinity) {
      const artistAffinity = profile.artistAffinity instanceof Map
        ? Object.fromEntries(profile.artistAffinity) : (profile.artistAffinity || {});
      topArtistNames = Object.entries(artistAffinity)
        .sort((a, b) => b[1] - a[1])
        .map(e => e[0].replace(/_/g, ' '))
        .slice(0, 8);
    }

    // Cold-start fallback: popular artists
    if (topArtistNames.length < 4) {
      const fallbackArtists = ['Arijit Singh', 'Taylor Swift', 'The Weeknd', 'Shreya Ghoshal', 'Justin Bieber', 'Diljit Dosanjh'];
      const existingSet = new Set(topArtistNames.map(a => a.toLowerCase()));
      for (const a of fallbackArtists) {
        if (!existingSet.has(a.toLowerCase())) topArtistNames.push(a);
        if (topArtistNames.length >= 8) break;
      }
    }

    // Fetch artist image URLs via JioSaavn search
    const artists = await Promise.all(topArtistNames.map(async (name) => {
      try {
        const results = await MusicProvider.search(`${name} songs`, 1);
        const imageUrl = results?.[0]?.thumbnailUrl || '';
        return { name, imageUrl };
      } catch (_) {
        return { name, imageUrl: '' };
      }
    }));

    res.json(artists);
  } catch (error) {
    console.error('Top Artists error:', error.message);
    res.status(500).json({ error: 'Failed to fetch top artists' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// NEW: Gap 5 — Discover: tracks from underexplored areas of user taste
// ─────────────────────────────────────────────────────────────────────────────

/**
 * @route GET /api/recommendations/discover
 * @desc Returns ~15 songs the user likely hasn't heard from unexplored areas
 */
router.get('/discover', async (req, res) => {
  try {
    const profile = await UserMusicProfile.findOne({ userId: req.userId });

    // Languages user has NOT explored much
    const allLanguages = ['Hindi', 'English', 'Punjabi', 'Tamil', 'Telugu', 'Bengali'];
    let underexploredLang = 'English';

    if (profile && profile.languageAffinity) {
      const langAffinity = profile.languageAffinity instanceof Map
        ? Object.fromEntries(profile.languageAffinity) : (profile.languageAffinity || {});

      const topLang = Object.entries(langAffinity)
        .sort((a, b) => b[1] - a[1])
        .map(e => e[0])[0];

      // Pick a language that's NOT the user's top language
      underexploredLang = allLanguages.find(l => l !== topLang) || 'English';
    }

    const intentInput = {
      id: 'discover',
      title: 'Discover Something New',
      description: 'Fresh finds you might love',
      intent: {
        languages: [underexploredLang],
        popularity: 'medium',
        discovery: 'high',
      },
    };

    const result = await PlaylistIntelligence.generate(intentInput, req.userId, {
      targetCount: 15,
      forceRefresh: true,
    });

    res.json(result.songs.slice(0, 15));
  } catch (error) {
    console.error('Discover error:', error.message);
    res.status(500).json({ error: 'Failed to fetch discover tracks' });
  }
});

module.exports = router;

