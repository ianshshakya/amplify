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
 * Remove duplicate tracks from a list of AmplifyTracks.
 * Deduplication happens on:
 *   1. Exact videoId match
 *   2. Same normalized title + same primary artist (catches different recordings)
 */
function deduplicateTracks(tracks) {
  const seenIds = new Set();
  const seenTitleArtist = new Set();
  const result = [];

  for (const track of tracks) {
    if (seenIds.has(track.videoId)) continue;

    const key = `${track.normalizedTitle}::${track.normalizedArtist}`;
    if (seenTitleArtist.has(key)) continue;

    seenIds.add(track.videoId);
    seenTitleArtist.add(key);
    result.push(track);
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
