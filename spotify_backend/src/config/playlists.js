/**
 * Amplify Curated Playlist Configuration
 * ========================================
 * Single source of truth. Used by:
 *   - homeRoutes.js (serving playlist metadata to frontend)
 *   - seedPlaylists.js (populating MongoDB)
 *   - PlaylistIntentEngine (deriving intent from playlist ID)
 *
 * strategy:
 *   'playlist'  → fetch from JioSaavn playlist by saavnPlaylistId
 *   'artist'    → search JioSaavn for artist tracks
 *   'spotify'   → cross-reference a Spotify playlist via spotify-url-info
 *   'multi'     → combine multiple queries (array of searchQueries)
 *
 * intent: structured hint for the PlaylistIntentEngine
 */

const CURATED_PLAYLISTS = [
  // ─── 🌟 Top Charts ──────────────────────────────────────────────────────────
  {
    id: 'global100',
    title: 'Global Top 100',
    type: 'Top Charts',
    strategy: 'spotify',
    spotifyUrl: [
      'https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M', // Today's Top Hits
      'https://open.spotify.com/playlist/37i9dQZF1DX0b1hHYQtJso', // Top Hits English
    ],
    saavnPlaylistId: '103402903',
    description: 'The most popular songs across the globe right now.',
    thumbnailUrl: 'https://misc.scdn.co/liked-songs/liked-songs-640.png',
    intent: { languages: ['English'], popularity: 'very-high', discovery: 'low', energy: 'medium' },
  },
  {
    id: 'indiantop50',
    title: 'Indian Top 50',
    type: 'Top Charts',
    strategy: 'playlist',
    saavnPlaylistId: '110858205',
    description: 'The biggest Indian hits trending today.',
    thumbnailUrl: 'https://c.saavncdn.com/694/Saathiya-Hindi-2026-20260220193432-500x500.jpg',
    intent: { languages: ['Hindi', 'Punjabi'], popularity: 'very-high', discovery: 'low' },
  },

  // ─── 🎤 Artist Spotlights (Indian) ──────────────────────────────────────────
  {
    id: 'arijitsingh',
    title: 'Best of Arijit Singh',
    type: 'Artist Spotlights',
    strategy: 'artist',
    searchQuery: 'Arijit Singh',
    description: 'Soulful melodies by Arijit Singh.',
    thumbnailUrl: 'https://c.saavncdn.com/840/Best-Of-Arijit-Singh-Collection-Of-Romantic-Songs-Hindi-2025-20251203161112-500x500.jpg',
    intent: { languages: ['Hindi'], popularity: 'high', energy: 'low-medium', mood: 'romance' },
  },
  {
    id: 'shreyaghoshal',
    title: 'Shreya Ghoshal Hits',
    type: 'Artist Spotlights',
    strategy: 'artist',
    searchQuery: 'Shreya Ghoshal',
    description: 'The melodious voice of Shreya Ghoshal.',
    thumbnailUrl: 'https://c.saavncdn.com/540/Humpty-Sharma-Ki-Dulhania-Hindi-2014-20190618095042-500x500.jpg',
    intent: { languages: ['Hindi'], popularity: 'high', energy: 'low-medium', mood: 'romance' },
  },
  {
    id: 'kishorekumar',
    title: 'Kishore Kumar Classics',
    type: 'Artist Spotlights',
    strategy: 'artist',
    searchQuery: 'Kishore Kumar',
    description: 'Golden hits from the legendary Kishore Kumar.',
    thumbnailUrl: 'https://c.saavncdn.com/086/Mere-Jeevan-Saathi-Hindi-1972-20200901153944-500x500.jpg',
    intent: { languages: ['Hindi'], era: '1960s-1990s', popularity: 'high', discovery: 'low' },
  },

  // ─── 🌍 Artist Spotlights (Global) ──────────────────────────────────────────
  {
    id: 'taylorswift',
    title: 'Taylor Swift Essentials',
    type: 'Artist Spotlights',
    strategy: 'artist',
    searchQuery: 'Taylor Swift',
    description: 'The biggest hits from Taylor Swift.',
    thumbnailUrl: 'https://c.saavncdn.com/519/Fifty-Shades-Darker-English-2017-500x500.jpg',
    intent: { languages: ['English'], popularity: 'very-high', energy: 'medium', mood: 'pop' },
  },
  {
    id: 'theweeknd',
    title: 'The Weeknd Hits',
    type: 'Artist Spotlights',
    strategy: 'artist',
    searchQuery: 'The Weeknd',
    description: 'Dark R&B and pop anthems.',
    thumbnailUrl: 'https://c.saavncdn.com/372/Starboy-English-2016-500x500.jpg',
    intent: { languages: ['English'], popularity: 'very-high', energy: 'medium-high', mood: 'rnb' },
  },
  {
    id: 'justinbieber',
    title: 'Justin Bieber Pop',
    type: 'Artist Spotlights',
    strategy: 'artist',
    searchQuery: 'Justin Bieber',
    description: 'Global pop hits by Justin Bieber.',
    thumbnailUrl: 'https://c.saavncdn.com/273/Encore-English-2016-20190419221937-500x500.jpg',
    intent: { languages: ['English'], popularity: 'very-high', energy: 'medium', mood: 'pop' },
  },

  // ─── 📅 Decades & Moods ──────────────────────────────────────────────────────
  {
    id: 'pophits',
    title: 'Pop Hits 2024',
    type: 'Trending Playlists',
    strategy: 'playlist',
    saavnPlaylistId: '158220556',
    description: 'The biggest pop anthems right now.',
    thumbnailUrl: 'https://c.saavncdn.com/178/Anpadh-1961-500x500.jpg',
    intent: { languages: ['English', 'Hindi'], popularity: 'very-high', era: '2020s', energy: 'medium-high' },
  },
  {
    id: 'indianclassic',
    title: 'Indian Classical Vibes',
    type: 'Decades & Moods',
    strategy: 'playlist',
    saavnPlaylistId: '112761792',
    description: 'Relaxing traditional Indian classical music.',
    thumbnailUrl: 'https://c.saavncdn.com/853/Air-India-presenting-India-Takes-Flight-Hindi-2024-20240229093248-500x500.jpg',
    intent: { languages: ['Hindi', 'Instrumental'], energy: 'low', mood: 'focus', discovery: 'medium' },
  },
  {
    id: 'globalclassic',
    title: 'Classical Masterpieces',
    type: 'Decades & Moods',
    strategy: 'playlist',
    saavnPlaylistId: '109673895',
    description: 'Timeless global classical music.',
    thumbnailUrl: 'https://c.saavncdn.com/259/I-m-the-One-English-2017-500x500.jpg',
    intent: { languages: ['Instrumental'], energy: 'low', mood: 'focus', discovery: 'medium' },
  },
  {
    id: 'oldbollywood',
    title: '90s Bollywood Classics',
    type: 'Decades & Moods',
    strategy: 'multi',
    searchQueries: [
      'Kumar Sanu 90s hits',
      'Udit Narayan 90s hits',
      'Lata Mangeshkar 90s',
      'Asha Bhosle 90s',
      'Bollywood 1990s hits',
      'Alka Yagnik 90s',
    ],
    description: 'Nostalgic hits from the 90s.',
    thumbnailUrl: 'https://c.saavncdn.com/blob/461/Saajan-Hindi-1991-20220616044407-500x500.jpg',
    intent: { languages: ['Hindi'], era: '1990s', popularity: 'high', discovery: 'low' },
  },
  {
    id: 'oldglobal',
    title: '80s & 90s Retro Global',
    type: 'Decades & Moods',
    strategy: 'multi',
    searchQueries: [
      'Michael Jackson greatest hits',
      'Madonna 80s pop hits',
      'Whitney Houston classics',
      'Bon Jovi 80s rock hits',
      'Backstreet Boys 90s hits',
      'Spice Girls hits',
      'Celine Dion 90s',
      'Bryan Adams 80s 90s',
    ],
    description: 'The best throwbacks of the 80s and 90s.',
    thumbnailUrl: 'https://c.saavncdn.com/757/Anand-Shinde-Milind-Shinde-Marathi-1986-20230508071410-500x500.jpg',
    intent: { languages: ['English'], era: '1980s-1990s', popularity: 'high', discovery: 'low' },
  },

  // ─── 🔥 Trending / New ──────────────────────────────────────────────────────
  {
    id: 'newhindi',
    title: 'New Releases (Hindi)',
    type: 'Trending Playlists',
    strategy: 'multi',
    searchQueries: [
      'New Hindi Songs 2025',
      'Bollywood New 2025',
      'New Hindi Hits 2024',
    ],
    description: 'Fresh Bollywood and Indie tracks.',
    thumbnailUrl: 'https://c.saavncdn.com/373/Stree-2-Hindi-2024-20240828083834-500x500.jpg',
    intent: { languages: ['Hindi'], era: '2020s', popularity: 'high', discovery: 'medium' },
  },
  {
    id: 'newglobal',
    title: 'New Releases (Global)',
    type: 'Trending Playlists',
    strategy: 'playlist',
    saavnPlaylistId: '110858205',
    description: 'The hottest new music around the world.',
    thumbnailUrl: 'https://c.saavncdn.com/694/Saathiya-Hindi-2026-20260220193432-500x500.jpg',
    intent: { purpose: 'charts', languages: ['English'], era: '2020s', popularity: 'high', discovery: 'medium' },
  },
  {
    id: 'punjabihits',
    title: 'Trending Punjabi',
    type: 'Trending Playlists',
    strategy: 'multi',
    searchQueries: [
      'Diljit Dosanjh hits',
      'AP Dhillon songs',
      'Sidhu Moosewala hits',
      'Punjabi Hits 2024',
      'Shubh Punjabi songs',
    ],
    description: 'High energy Punjabi bangers.',
    thumbnailUrl: 'https://c.saavncdn.com/706/Kya-Baat-Ay-Punjabi-2018-20180921123124-500x500.jpg',
    intent: { languages: ['Punjabi'], popularity: 'high', energy: 'high', mood: 'party' },
  },

  // ─── 🎧 Moods ────────────────────────────────────────────────────────────────
  {
    id: 'workout',
    title: 'Workout',
    type: 'Moods',
    strategy: 'playlist',
    saavnPlaylistId: '156710699',
    description: 'Energetic workout hits.',
    thumbnailUrl: 'https://c.saavncdn.com/575/Bhaag-Milkha-Bhaag-Hindi-2013-20260120201340-500x500.jpg',
    intent: { purpose: 'workout', energy: 'high', popularity: 'high', discovery: 'low', languages: ['Hindi', 'English'] },
  },
  {
    id: 'chill',
    title: 'Chill',
    type: 'Moods',
    strategy: 'playlist',
    saavnPlaylistId: '1079336813',
    description: 'Relaxing chill tracks.',
    thumbnailUrl: 'https://c.saavncdn.com/709/Apna-Bana-Le-Lofi-Mix-by-Artist-L3AD-Hindi-2023-20231018174428-500x500.jpg',
    intent: { purpose: 'chill', energy: 'low-medium', popularity: 'medium', discovery: 'medium' },
  },
  {
    id: 'party',
    title: 'Party',
    type: 'Moods',
    strategy: 'playlist',
    saavnPlaylistId: '932189657',
    description: 'Ultimate party songs.',
    thumbnailUrl: 'https://c.saavncdn.com/624/Abrar-s-Entry-Jamal-Kudu-From-ANIMAL-Hindi-2023-20231206121002-500x500.jpg',
    intent: { purpose: 'party', energy: 'high', popularity: 'very-high', discovery: 'low' },
  },
  {
    id: 'hip-hop',
    title: 'Hip-hop',
    type: 'Moods',
    strategy: 'playlist',
    saavnPlaylistId: '320912763',
    description: 'Top hip-hop tracks.',
    thumbnailUrl: 'https://c.saavncdn.com/714/Machayenge-Hindi-2019-20230228064934-500x500.jpg',
    intent: { languages: ['English', 'Hindi'], mood: 'hip-hop', popularity: 'high', energy: 'high' },
  },
  {
    id: 'relax',
    title: 'Relax',
    type: 'Moods',
    strategy: 'multi',
    searchQueries: [
      'relaxing chill songs',
      'soft pop chill hits',
      'relaxing Bollywood songs',
      'calm acoustic songs',
    ],
    description: 'Unwind and relax.',
    thumbnailUrl: 'https://c.saavncdn.com/958/Yaar-Anmulle-Punjabi-2000-500x500.jpg',
    intent: { purpose: 'relax', energy: 'low', popularity: 'medium', discovery: 'medium' },
  },
  {
    id: 'romance',
    title: 'Romance',
    type: 'Moods',
    strategy: 'playlist',
    saavnPlaylistId: '903166403',
    description: 'Love and romance.',
    thumbnailUrl: 'https://c.saavncdn.com/191/Kesariya-From-Brahmastra-Hindi-2022-20220717092820-500x500.jpg',
    intent: { purpose: 'romance', energy: 'low-medium', popularity: 'high', mood: 'romance' },
  },
  {
    id: 'focus',
    title: 'Focus',
    type: 'Moods',
    strategy: 'multi',
    searchQueries: [
      'focus music for studying',
      'study music instrumental',
      'lo-fi hip hop study beats',
      'deep focus piano music',
    ],
    description: 'Deep focus music.',
    thumbnailUrl: 'https://c.saavncdn.com/398/Focus-Music-for-Students-Expand-Your-Mind-Keep-the-Stress-Under-Control-with-Concentration-Music-Instrumental-New-Age-Background--English-2017-20171004221815-500x500.jpg',
    intent: { purpose: 'focus', energy: 'low-medium', popularity: 'medium', discovery: 'medium' },
  },
];

module.exports = CURATED_PLAYLISTS;
