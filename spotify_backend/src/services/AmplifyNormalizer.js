/**
 * AmplifyNormalizer
 * =================
 * Converts raw JioSaavn track objects into enriched AmplifyTrack objects.
 *
 * Every track that flows through the recommendation pipeline passes through
 * this normalizer so that all downstream components work with consistent,
 * scored objects rather than raw API data.
 */

const CURRENT_YEAR = new Date().getFullYear();

// Remix/cover detection patterns
const REMIX_PATTERNS = [
  /\b(remix|lofi|lo-fi|cover|version|reprise|acoustic|live|instrumental|karaoke|mashup|edit|extended|radio\s+edit|dj\s+mix|bootleg|flip|rework|remaster)\b/i
];

/**
 * Detect if a track is a remix, cover, or non-original version.
 */
function detectRemix(title) {
  return REMIX_PATTERNS.some(p => p.test(title));
}

/**
 * Calculate a popularity score (0–100) from JioSaavn's play_count.
 *
 * Play count distribution on JioSaavn (approximate):
 *   Mega hits:    > 500,000,000  → score ~95–100
 *   Mainstream:   50,000,000–500M → score ~75–94
 *   Popular:      5,000,000–50M   → score ~55–74
 *   Niche:        500,000–5M      → score ~30–54
 *   Deep disc:    < 500,000       → score ~0–29
 *
 * We use a log scale to map across this range.
 */
function computePopularityScore(playCount) {
  if (!playCount || playCount <= 0) return 10; // Unknown → slight boost over zero
  
  // log10(1) = 0, log10(500M) ≈ 8.7
  const log = Math.log10(Math.max(playCount, 1));
  // Clamp to 0–8.7, then scale to 0–100
  const score = Math.min(100, Math.round((log / 8.7) * 100));
  return score;
}

/**
 * Derive a mainstream score label from the popularity score.
 */
function computeMainstreamsLevel(popularityScore) {
  if (popularityScore >= 90) return 'mega';
  if (popularityScore >= 75) return 'mainstream';
  if (popularityScore >= 55) return 'popular';
  if (popularityScore >= 30) return 'niche';
  return 'deep-discovery';
}

/**
 * Calculate a recency score (0–100).
 * Recent songs score higher. Songs from this year = 100.
 * Each year in the past drops the score by ~5 points.
 */
function computeRecencyScore(releaseYear) {
  if (!releaseYear) return 40; // Unknown year → neutral
  const age = CURRENT_YEAR - releaseYear;
  if (age <= 0) return 100;
  if (age >= 20) return 0;
  return Math.max(0, Math.round(100 - age * 5));
}

/**
 * Normalize the primary artist name (first listed, no features/ft.)
 */
function normalizePrimaryArtist(artistStr) {
  if (!artistStr) return 'Unknown Artist';
  // Take the first artist in a comma-separated list
  const first = artistStr.split(',')[0].trim();
  // Strip featuring/ft. suffixes
  return first.replace(/\s+(ft\.|feat\.|featuring|x)\s+.*/i, '').trim();
}

/**
 * Normalize all artists sorted alphabetically to handle flipped artist names
 */
function normalizeAllArtists(artistStr) {
  if (!artistStr) return 'unknown artist';
  return artistStr
    .split(',')
    .map(a => a.trim().replace(/\s+(ft\.|feat\.|featuring|x)\s+.*/i, '').toLowerCase())
    .sort()
    .join(', ');
}

/**
 * Normalize a song title for deduplication (strip remix tags, punctuation).
 */
function normalizeTitle(title) {
  if (!title) return '';
  return title
    .toLowerCase()
    .replace(/\s*\(.*?\)\s*/g, '')   // remove (Remix), (Official), etc.
    .replace(/\s*\[.*?\]\s*/g, '')   // remove [Lyric Video], etc.
    .replace(/\s*-\s*(remix|version|cover|edit|official|audio|video|live).*/i, '')
    .replace(/[^a-z0-9\s]/g, '')     // strip punctuation
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Normalize a track from JioSaavn raw data into an AmplifyTrack.
 *
 * @param {object} rawTrack - Object from saavn.js (mapSaavnResult output)
 * @returns {AmplifyTrack}
 */
function normalizeTrack(rawTrack) {
  const popularityScore = computePopularityScore(rawTrack.playCount || 0);
  const recencyScore = computeRecencyScore(rawTrack.releaseYear);
  const isRemix = detectRemix(rawTrack.title || '');

  return {
    // ── Core fields (passed to Flutter client) ─────────────────────────────
    videoId: rawTrack.videoId,
    title: rawTrack.title || 'Unknown Title',
    artist: rawTrack.artist || 'Unknown Artist',
    thumbnailUrl: rawTrack.thumbnailUrl || '',
    durationMs: (rawTrack.duration || 0) * 1000,
    source: rawTrack.source || 'saavn',

    // ── Enrichment ─────────────────────────────────────────────────────────
    language: rawTrack.language || null,
    releaseYear: rawTrack.releaseYear || null,
    album: rawTrack.album || null,
    isExplicit: rawTrack.isExplicit || false,
    playCount: rawTrack.playCount || 0,

    // ── Amplify computed scores ────────────────────────────────────────────
    popularityScore,
    mainstreamsScore: popularityScore, // Alias — same value, kept for semantic clarity
    mainstreamsLevel: computeMainstreamsLevel(popularityScore),
    recencyScore,
    isRemix,
    discoveryScore: 100 - popularityScore,

    // ── Derived helpers for fast matching ─────────────────────────────────
    primaryArtist: normalizePrimaryArtist(rawTrack.artist),
    normalizedTitle: normalizeTitle(rawTrack.title),
    normalizedArtist: normalizePrimaryArtist(rawTrack.artist).toLowerCase(),
    normalizedAllArtists: normalizeAllArtists(rawTrack.artist),

    // ── Debug / scoring metadata ───────────────────────────────────────────
    _scoring: null, // Populated by ScoringEngine
  };
}

/**
 * Normalize an array of raw JioSaavn tracks.
 */
function normalizeTracks(rawTracks) {
  return rawTracks.map(normalizeTrack);
}

/**
 * Levenshtein distance for fuzzy title matching
 */
function levenshteinDistance(a, b) {
  if (a.length === 0) return b.length;
  if (b.length === 0) return a.length;
  const matrix = [];
  for (let i = 0; i <= b.length; i++) {
    matrix[i] = [i];
  }
  for (let j = 0; j <= a.length; j++) {
    matrix[0][j] = j;
  }
  for (let i = 1; i <= b.length; i++) {
    for (let j = 1; j <= a.length; j++) {
      if (b.charAt(i - 1) === a.charAt(j - 1)) {
        matrix[i][j] = matrix[i - 1][j - 1];
      } else {
        matrix[i][j] = Math.min(
          matrix[i - 1][j - 1] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j] + 1
        );
      }
    }
  }
  return matrix[b.length][a.length];
}

/**
 * Remove duplicate tracks from a list of AmplifyTracks.
 * Deduplication happens on:
 *   1. Exact videoId match
 *   2. Same normalized title + same artist (or subset of sorted artists)
 *   3. Fuzzy title match (Levenshtein distance) for typos
 */
function deduplicateTracks(tracks) {
  const result = [];

  for (const track of tracks) {
    if (result.some(r => r.videoId === track.videoId)) continue;

    let isDuplicate = false;
    for (const existing of result) {
      const sameArtist = existing.normalizedAllArtists === track.normalizedAllArtists || 
                         existing.normalizedArtist === track.normalizedArtist ||
                         existing.normalizedAllArtists.includes(track.normalizedArtist);

      if (!sameArtist) continue;

      if (existing.normalizedTitle === track.normalizedTitle) {
        isDuplicate = true;
        break;
      }
      
      if (Math.abs(existing.normalizedTitle.length - track.normalizedTitle.length) > 5) continue;
      
      const len = Math.max(existing.normalizedTitle.length, track.normalizedTitle.length);
      const threshold = len > 10 ? 3 : (len > 5 ? 2 : 1);
      
      const dist = levenshteinDistance(existing.normalizedTitle, track.normalizedTitle);
      if (dist <= threshold) {
        isDuplicate = true;
        break;
      }
      
      if (existing.normalizedTitle.includes(track.normalizedTitle) || track.normalizedTitle.includes(existing.normalizedTitle)) {
        if (Math.abs(existing.normalizedTitle.length - track.normalizedTitle.length) <= 5) {
          isDuplicate = true;
          break;
        }
      }
    }

    if (!isDuplicate) {
      result.push(track);
    }
  }

  return result;
}

module.exports = {
  normalizeTrack,
  normalizeTracks,
  deduplicateTracks,
  computePopularityScore,
  computeMainstreamsLevel,
  computeRecencyScore,
  normalizeTitle,
  normalizePrimaryArtist,
};
