/**
 * PlaylistIntentEngine
 * ====================
 * Converts a playlist ID, name, or description into a structured PlaylistIntent.
 *
 * A PlaylistIntent drives all downstream decisions:
 *   - Which search queries to use for candidate generation
 *   - What language/era filters to apply
 *   - How to weight scoring dimensions
 *   - What diversity rules to apply
 *   - How to sequence the final playlist
 *
 * This is rule-based (fast, no LLM cost, works offline). It can match
 * playlist config `intent` hints, keyword patterns in the name/description,
 * and fall back to a safe "popular songs" intent.
 */

// ─── Archetype Profiles ────────────────────────────────────────────────────────
// Each archetype defines default scoring weights and behavioral rules.
// Weights are relative (they are normalized before use).
const ARCHETYPES = {
  workout: {
    purpose: 'workout',
    energyLevel: 'high',
    popularityWeight: 0.35,
    intentWeight: 0.30,
    noveltyWeight: 0.05,
    recencyWeight: 0.10,
    affinityWeight: 0.20,
    maxArtistRepeat: 3,
    maxAlbumRepeat: 2,
    preventConsecutiveSameArtist: true,
    mainstreamsDistribution: { mega: 0.25, mainstream: 0.35, popular: 0.25, niche: 0.10, deepDiscovery: 0.05 },
    sequenceStyle: 'energy-build',
    minSongs: 20,
  },
  party: {
    purpose: 'party',
    energyLevel: 'high',
    popularityWeight: 0.40,
    intentWeight: 0.25,
    noveltyWeight: 0.05,
    recencyWeight: 0.15,
    affinityWeight: 0.15,
    maxArtistRepeat: 2,
    maxAlbumRepeat: 2,
    preventConsecutiveSameArtist: true,
    mainstreamsDistribution: { mega: 0.30, mainstream: 0.40, popular: 0.20, niche: 0.08, deepDiscovery: 0.02 },
    sequenceStyle: 'peak-energy',
    minSongs: 20,
  },
  chill: {
    purpose: 'chill',
    energyLevel: 'low-medium',
    popularityWeight: 0.20,
    intentWeight: 0.25,
    noveltyWeight: 0.20,
    recencyWeight: 0.15,
    affinityWeight: 0.20,
    maxArtistRepeat: 3,
    maxAlbumRepeat: 2,
    preventConsecutiveSameArtist: false,
    mainstreamsDistribution: { mega: 0.10, mainstream: 0.30, popular: 0.35, niche: 0.20, deepDiscovery: 0.05 },
    sequenceStyle: 'smooth-flow',
    minSongs: 15,
  },
  focus: {
    purpose: 'focus',
    energyLevel: 'low-medium',
    popularityWeight: 0.15,
    intentWeight: 0.30,
    noveltyWeight: 0.20,
    recencyWeight: 0.10,
    affinityWeight: 0.25,
    maxArtistRepeat: 4,
    maxAlbumRepeat: 3,
    preventConsecutiveSameArtist: false,
    mainstreamsDistribution: { mega: 0.05, mainstream: 0.20, popular: 0.40, niche: 0.25, deepDiscovery: 0.10 },
    sequenceStyle: 'steady-state',
    minSongs: 15,
  },
  relax: {
    purpose: 'relax',
    energyLevel: 'low',
    popularityWeight: 0.15,
    intentWeight: 0.25,
    noveltyWeight: 0.20,
    recencyWeight: 0.10,
    affinityWeight: 0.30,
    maxArtistRepeat: 4,
    maxAlbumRepeat: 3,
    preventConsecutiveSameArtist: false,
    mainstreamsDistribution: { mega: 0.05, mainstream: 0.20, popular: 0.35, niche: 0.25, deepDiscovery: 0.15 },
    sequenceStyle: 'smooth-flow',
    minSongs: 15,
  },
  romance: {
    purpose: 'romance',
    energyLevel: 'low-medium',
    popularityWeight: 0.25,
    intentWeight: 0.30,
    noveltyWeight: 0.15,
    recencyWeight: 0.15,
    affinityWeight: 0.15,
    maxArtistRepeat: 3,
    maxAlbumRepeat: 2,
    preventConsecutiveSameArtist: true,
    mainstreamsDistribution: { mega: 0.15, mainstream: 0.35, popular: 0.30, niche: 0.15, deepDiscovery: 0.05 },
    sequenceStyle: 'smooth-flow',
    minSongs: 15,
  },
  nostalgia: {
    purpose: 'nostalgia',
    energyLevel: 'medium',
    popularityWeight: 0.30,
    intentWeight: 0.35,
    noveltyWeight: 0.05,
    recencyWeight: -0.10, // Negative — penalize recent songs
    affinityWeight: 0.40,
    maxArtistRepeat: 3,
    maxAlbumRepeat: 2,
    preventConsecutiveSameArtist: true,
    mainstreamsDistribution: { mega: 0.10, mainstream: 0.40, popular: 0.35, niche: 0.12, deepDiscovery: 0.03 },
    sequenceStyle: 'smooth-flow',
    minSongs: 20,
  },
  discover: {
    purpose: 'discover',
    energyLevel: 'medium',
    popularityWeight: 0.10,
    intentWeight: 0.20,
    noveltyWeight: 0.50,
    recencyWeight: 0.10,
    affinityWeight: 0.10,
    maxArtistRepeat: 2,
    maxAlbumRepeat: 1,
    preventConsecutiveSameArtist: true,
    mainstreamsDistribution: { mega: 0.05, mainstream: 0.15, popular: 0.30, niche: 0.30, deepDiscovery: 0.20 },
    sequenceStyle: 'gradual-discovery',
    minSongs: 15,
  },
  charts: {
    purpose: 'charts',
    energyLevel: 'medium',
    popularityWeight: 0.55,
    intentWeight: 0.10,
    noveltyWeight: 0.10,
    recencyWeight: 0.25,
    affinityWeight: 0.00,
    maxArtistRepeat: 3,
    maxAlbumRepeat: 2,
    preventConsecutiveSameArtist: true,
    mainstreamsDistribution: { mega: 0.35, mainstream: 0.40, popular: 0.20, niche: 0.04, deepDiscovery: 0.01 },
    sequenceStyle: 'peak-energy',
    minSongs: 25,
  },
  artist: {
    purpose: 'artist',
    energyLevel: 'medium',
    popularityWeight: 0.40,
    intentWeight: 0.20,
    noveltyWeight: 0.20,
    recencyWeight: 0.05,
    affinityWeight: 0.15,
    maxArtistRepeat: 50, // Artist playlists should allow many songs by same artist
    maxAlbumRepeat: 5,
    preventConsecutiveSameArtist: false,
    mainstreamsDistribution: { mega: 0.20, mainstream: 0.40, popular: 0.25, niche: 0.12, deepDiscovery: 0.03 },
    sequenceStyle: 'smooth-flow',
    minSongs: 15,
  },
  hiphop: {
    purpose: 'hip-hop',
    energyLevel: 'high',
    popularityWeight: 0.35,
    intentWeight: 0.25,
    noveltyWeight: 0.15,
    recencyWeight: 0.15,
    affinityWeight: 0.10,
    maxArtistRepeat: 3,
    maxAlbumRepeat: 2,
    preventConsecutiveSameArtist: true,
    mainstreamsDistribution: { mega: 0.20, mainstream: 0.35, popular: 0.25, niche: 0.15, deepDiscovery: 0.05 },
    sequenceStyle: 'energy-build',
    minSongs: 20,
  },
  default: {
    purpose: 'general',
    energyLevel: 'medium',
    popularityWeight: 0.30,
    intentWeight: 0.25,
    noveltyWeight: 0.15,
    recencyWeight: 0.10,
    affinityWeight: 0.20,
    maxArtistRepeat: 3,
    maxAlbumRepeat: 2,
    preventConsecutiveSameArtist: true,
    mainstreamsDistribution: { mega: 0.15, mainstream: 0.35, popular: 0.30, niche: 0.15, deepDiscovery: 0.05 },
    sequenceStyle: 'smooth-flow',
    minSongs: 15,
  },
};

// ─── Keyword → Archetype mappings ─────────────────────────────────────────────
const PURPOSE_KEYWORDS = {
  workout: ['workout', 'exercise', 'gym', 'running', 'fitness', 'energy', 'power', 'pump', 'train', 'sport', 'cardio'],
  party: ['party', 'dance', 'club', 'banger', 'rave', 'festival', 'night out', 'dj'],
  chill: ['chill', 'chillout', 'relax', 'lounge', 'easy', 'mellow', 'lazy', 'vibe', 'slow', 'cozy', 'sunday'],
  focus: ['focus', 'study', 'work', 'concentrate', 'productivity', 'deep work', 'coding', 'homework', 'brain', 'exam'],
  relax: ['sleep', 'relax', 'calm', 'peaceful', 'soothing', 'meditation', 'yoga', 'spa', 'ambient', 'nature', 'bedtime'],
  romance: ['romance', 'romantic', 'love', 'date', 'valentine', 'wedding', 'couple', 'sad love', 'heartbreak'],
  nostalgia: ['classic', 'classics', 'nostalgia', 'retro', 'throwback', 'old', '80s', '90s', '2000s', 'golden', 'vintage'],
  discover: ['discover', 'new', 'indie', 'underground', 'fresh', 'hidden', 'rare', 'unknown', 'emerging'],
  hiphop: ['hip-hop', 'hiphop', 'hip hop', 'rap', 'trap', 'drill', 'r&b', 'rnb'],
  charts: ['top', 'chart', 'trending', 'popular', 'hits', 'best', 'global', '100', '50', 'ranking'],
};

// ─── Keyword → Language mappings ───────────────────────────────────────────────
const LANGUAGE_KEYWORDS = {
  Hindi: ['hindi', 'bollywood', 'desi', 'filmi', 'arijit', 'shreya', 'kumar sanu', 'atif', 'udit'],
  Punjabi: ['punjabi', 'bhangra', 'diljit', 'ap dhillon', 'sidhu', 'moosewala'],
  English: ['english', 'global', 'international', 'pop', 'rock', 'western', 'taylor', 'weeknd', 'bieber', 'drake', 'ed sheeran'],
  Tamil: ['tamil', 'kollywood', 'ar rahman', 'ilayaraja'],
  Telugu: ['telugu', 'tollywood'],
};

// ─── Keyword → Era mappings ────────────────────────────────────────────────────
const ERA_KEYWORDS = {
  '1960s': ['60s', '1960s', 'sixties'],
  '1970s': ['70s', '1970s', 'seventies'],
  '1980s': ['80s', '1980s', 'eighties'],
  '1990s': ['90s', '1990s', 'nineties'],
  '2000s': ['2000s', 'noughties', '00s', 'y2k'],
  '2010s': ['2010s', 'tens', '10s'],
  '2020s': ['2020s', '2024', '2025', 'latest', 'new'],
};

// Era → Year ranges
const ERA_YEARS = {
  '1960s': { min: 1960, max: 1969 },
  '1970s': { min: 1970, max: 1979 },
  '1980s': { min: 1980, max: 1989 },
  '1990s': { min: 1990, max: 1999 },
  '2000s': { min: 2000, max: 2009 },
  '2010s': { min: 2010, max: 2019 },
  '2020s': { min: 2020, max: 2099 },
};

function detectFromText(text, keywordMap) {
  const lower = text.toLowerCase();
  for (const [key, keywords] of Object.entries(keywordMap)) {
    if (keywords.some(kw => lower.includes(kw))) {
      return key;
    }
  }
  return null;
}

function detectLanguages(text) {
  const lower = text.toLowerCase();
  const detected = [];
  for (const [lang, keywords] of Object.entries(LANGUAGE_KEYWORDS)) {
    if (keywords.some(kw => lower.includes(kw))) detected.push(lang);
  }
  return detected;
}

function detectEra(text) {
  const lower = text.toLowerCase();
  for (const [era, keywords] of Object.entries(ERA_KEYWORDS)) {
    if (keywords.some(kw => lower.includes(kw))) return era;
  }
  return null;
}

/**
 * Parse a PlaylistIntent from a playlist config object or free-form text.
 *
 * @param {object|string} input - Playlist config object (from playlists.js) or free-form string
 * @returns {PlaylistIntent}
 */
function parseIntent(input) {
  let hint = {};
  let searchText = '';

  if (typeof input === 'string') {
    searchText = input;
  } else if (typeof input === 'object') {
    // Use the `intent` field from playlists.js config if available
    hint = input.intent || {};
    searchText = [input.title, input.description, input.id].filter(Boolean).join(' ');
  }

  // ── Detect purpose / archetype ──────────────────────────────────────────────
  const detectedPurpose = hint.purpose || detectFromText(searchText, PURPOSE_KEYWORDS) || 'default';
  const archetype = { ...ARCHETYPES[detectedPurpose] || ARCHETYPES.default };

  // ── Detect language ─────────────────────────────────────────────────────────
  let languages = hint.languages || detectLanguages(searchText);
  if (!languages || languages.length === 0) languages = []; // No language constraint

  // ── Detect era ──────────────────────────────────────────────────────────────
  const detectedEra = hint.era || detectEra(searchText) || null;
  const eraYears = detectedEra ? ERA_YEARS[detectedEra] : null;

  // ── Popularity preference ───────────────────────────────────────────────────
  const popularityMap = { 'very-high': 0.90, high: 0.75, medium: 0.50, low: 0.25 };
  const popularityFloor = popularityMap[hint.popularity] || 0;

  // ── Override archetype weights from hint ────────────────────────────────────
  if (hint.popularity === 'very-high') archetype.popularityWeight = Math.max(archetype.popularityWeight, 0.45);
  if (hint.popularity === 'low') archetype.popularityWeight = Math.min(archetype.popularityWeight, 0.10);
  if (hint.discovery === 'high') archetype.noveltyWeight = Math.max(archetype.noveltyWeight, 0.40);
  if (hint.discovery === 'low') archetype.noveltyWeight = Math.min(archetype.noveltyWeight, 0.05);

  return {
    purpose: archetype.purpose,
    archetype: detectedPurpose,
    languages,
    era: detectedEra,
    eraYears, // { min, max } or null
    energyLevel: hint.energy || archetype.energyLevel,
    popularityFloor, // Minimum popularity score for candidates
    archetypeWeights: {
      popularityWeight: archetype.popularityWeight,
      intentWeight: archetype.intentWeight,
      noveltyWeight: archetype.noveltyWeight,
      recencyWeight: archetype.recencyWeight,
      affinityWeight: archetype.affinityWeight,
    },
    maxArtistRepeat: archetype.maxArtistRepeat,
    maxAlbumRepeat: archetype.maxAlbumRepeat,
    preventConsecutiveSameArtist: archetype.preventConsecutiveSameArtist,
    mainstreamsDistribution: archetype.mainstreamsDistribution,
    sequenceStyle: archetype.sequenceStyle,
    minSongs: archetype.minSongs,
    searchQuery: (typeof input === 'object' && input.searchQuery) ? input.searchQuery : null,
    searchQueries: (typeof input === 'object' && input.searchQueries) ? input.searchQueries : null,
  };
}

/**
 * Generate JioSaavn-compatible search queries from a PlaylistIntent.
 * Returns a prioritized list — first queries are most important.
 */
function generateSearchQueries(intent, playlistConfig = null) {
  const queries = [];

  // If the playlist config has explicit search queries, use those first
  if (playlistConfig && playlistConfig.searchQueries) {
    return playlistConfig.searchQueries;
  }
  if (playlistConfig && playlistConfig.searchQuery) {
    queries.push(playlistConfig.searchQuery);
    queries.push(`${playlistConfig.searchQuery} best songs`);
    queries.push(`${playlistConfig.searchQuery} top hits`);
    return queries;
  }

  // ── Build queries from intent fields ────────────────────────────────────────
  const langPrefix = intent.languages.length > 0 ? intent.languages.join(' ') + ' ' : '';
  const eraPrefix = intent.era ? intent.era + ' ' : '';

  switch (intent.purpose) {
    case 'workout':
      queries.push(`${langPrefix}workout songs`, `${langPrefix}gym music hits`, `${langPrefix}running music`, `${langPrefix}power songs`);
      break;
    case 'party':
      queries.push(`${langPrefix}party songs`, `${langPrefix}dance hits`, `${langPrefix}club music`, `${langPrefix}party anthem`);
      break;
    case 'chill':
      queries.push(`${langPrefix}chill songs`, `${langPrefix}relaxing music`, `${langPrefix}chill vibes`, `${langPrefix}easy listening`);
      break;
    case 'focus':
      queries.push(`${langPrefix}focus music`, `${langPrefix}study music`, `${langPrefix}concentration music`, `instrumental focus`);
      break;
    case 'relax':
      queries.push(`${langPrefix}relaxing songs`, `${langPrefix}calm music`, `${langPrefix}peaceful songs`);
      break;
    case 'romance':
      queries.push(`${langPrefix}romantic songs`, `${langPrefix}love songs`, `${langPrefix}romantic hits`);
      break;
    case 'nostalgia':
      queries.push(`${eraPrefix}${langPrefix}hits`, `${eraPrefix}${langPrefix}classics`, `${langPrefix}${eraPrefix}top songs`);
      break;
    case 'discover':
      queries.push(`${langPrefix}indie songs`, `${langPrefix}underground music`, `${langPrefix}new music 2024`);
      break;
    case 'hip-hop':
      queries.push(`${langPrefix}hip hop hits`, `${langPrefix}rap songs`, `${langPrefix}trap music`);
      break;
    case 'charts':
      queries.push(`${langPrefix}top hits`, `${langPrefix}popular songs`, `${langPrefix}trending music`);
      break;
    default:
      queries.push(`${eraPrefix}${langPrefix}hits`, `${eraPrefix}${langPrefix}popular songs`, `${langPrefix}best songs`);
  }

  return queries.filter(Boolean);
}

module.exports = { parseIntent, generateSearchQueries, ARCHETYPES, ERA_YEARS };
