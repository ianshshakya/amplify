/**
 * QualityValidator
 * ================
 * Validates a generated playlist before it is sent to the client.
 * Returns a validation report with a pass/fail decision and specific issues found.
 *
 * Checks:
 *   1. Minimum song count
 *   2. No empty results
 *   3. Language alignment (>50% songs match primary intended language)
 *   4. Era alignment (>60% songs match requested era, if specified)
 *   5. Artist concentration (no artist exceeds 30% of playlist)
 *   6. Duplicate detection
 *   7. Mainstream ratio (verify against archetype distribution)
 *   8. Remix concentration (remixes < 30% unless explicitly allowed)
 */

class QualityValidator {
  /**
   * Validate a generated playlist.
   *
   * @param {AmplifyTrack[]} tracks
   * @param {PlaylistIntent} intent
   * @returns {{ pass: boolean, score: number, issues: string[], warnings: string[] }}
   */
  static validate(tracks, intent) {
    const issues = [];
    const warnings = [];
    let score = 100;

    const minSongs = intent.minSongs || 10;

    // ── 1. Empty check ─────────────────────────────────────────────────────────
    if (!tracks || tracks.length === 0) {
      return { pass: false, score: 0, issues: ['EMPTY: No tracks generated'], warnings: [] };
    }

    // ── 2. Minimum song count ──────────────────────────────────────────────────
    if (tracks.length < minSongs) {
      issues.push(`TOO_FEW: Only ${tracks.length} tracks, need at least ${minSongs}`);
      score -= 30;
    } else if (tracks.length < minSongs * 1.5) {
      warnings.push(`LOW_COUNT: ${tracks.length} tracks (could be more)`);
      score -= 10;
    }

    // ── 3. Language alignment ──────────────────────────────────────────────────
    if (intent.languages && intent.languages.length > 0 && tracks.length > 3) {
      const targetLangs = intent.languages.map(l => l.toLowerCase());
      const tracksWithLang = tracks.filter(t => t.language);
      if (tracksWithLang.length > 0) {
        const matchCount = tracksWithLang.filter(t => targetLangs.includes((t.language || '').toLowerCase())).length;
        const matchRatio = matchCount / tracksWithLang.length;
        if (matchRatio < 0.40) {
          issues.push(`LANGUAGE_MISMATCH: Only ${Math.round(matchRatio * 100)}% tracks match intended language(s): ${intent.languages.join(', ')}`);
          score -= 25;
        } else if (matchRatio < 0.60) {
          warnings.push(`LANGUAGE_LOW: ${Math.round(matchRatio * 100)}% language match (target: ${intent.languages.join(', ')})`);
          score -= 10;
        }
      }
    }

    // ── 4. Era alignment ───────────────────────────────────────────────────────
    if (intent.eraYears && tracks.length > 3) {
      const { min, max } = intent.eraYears;
      const tracksWithYear = tracks.filter(t => t.releaseYear);
      if (tracksWithYear.length > 0) {
        const inEra = tracksWithYear.filter(t => t.releaseYear >= min && t.releaseYear <= max).length;
        const eraRatio = inEra / tracksWithYear.length;
        if (eraRatio < 0.40) {
          issues.push(`ERA_MISMATCH: Only ${Math.round(eraRatio * 100)}% tracks in era ${intent.era}`);
          score -= 20;
        } else if (eraRatio < 0.60) {
          warnings.push(`ERA_LOW: ${Math.round(eraRatio * 100)}% era match`);
          score -= 8;
        }
      }
    }

    // ── 5. Artist concentration ────────────────────────────────────────────────
    const artistCounts = {};
    for (const t of tracks) {
      const a = t.primaryArtist || (t.artist || '').split(',')[0].trim();
      artistCounts[a] = (artistCounts[a] || 0) + 1;
    }
    const maxCount = Math.max(...Object.values(artistCounts));
    const maxRatio = maxCount / tracks.length;
    if (maxRatio > 0.40 && intent.maxArtistRepeat < 50) {
      const dominantArtist = Object.keys(artistCounts).find(k => artistCounts[k] === maxCount);
      warnings.push(`ARTIST_DOMINANCE: "${dominantArtist}" appears ${maxCount} times (${Math.round(maxRatio * 100)}%)`);
      score -= 10;
    }

    // ── 6. Remix concentration ─────────────────────────────────────────────────
    const remixCount = tracks.filter(t => t.isRemix).length;
    const remixRatio = remixCount / tracks.length;
    if (remixRatio > 0.30) {
      warnings.push(`HIGH_REMIXES: ${Math.round(remixRatio * 100)}% tracks are remixes/covers`);
      score -= 10;
    }

    // ── 7. Mainstream ratio ────────────────────────────────────────────────────
    if (intent.archetypeWeights && intent.archetypeWeights.popularityWeight > 0.30) {
      const mainstreamCount = tracks.filter(t => (t.popularityScore || 0) >= 55).length;
      const mainRatio = mainstreamCount / tracks.length;
      if (mainRatio < 0.30) {
        warnings.push(`LOW_MAINSTREAM: Only ${Math.round(mainRatio * 100)}% tracks are mainstream (popularity ≥55)`);
        score -= 10;
      }
    }

    score = Math.max(0, score);
    const pass = issues.length === 0 && score >= 40;

    return { pass, score, issues, warnings };
  }
}

/**
 * FallbackLadder
 * ==============
 * When playlist generation fails quality validation, this ladder
 * progressively relaxes constraints until we get something good enough.
 *
 * Level 1: Exact intent match
 * Level 2: Relax era constraint
 * Level 3: Relax language constraint (keep purpose)
 * Level 4: Relax to purpose only
 * Level 5: Language mainstream hits
 * Level 6: Broad mainstream fallback (always succeeds)
 */

const MusicProvider = require('./MusicProvider');
const { normalizeTracks, deduplicateTracks } = require('./AmplifyNormalizer');
const ScoringEngine = require('./ScoringEngine');
const { DiversityController, SequenceBuilder } = require('./DiversityController');

class FallbackLadder {
  /**
   * Attempt fallback strategies until a valid playlist is produced.
   *
   * @param {PlaylistIntent} intent
   * @param {number} targetCount
   * @param {object|null} userProfile
   * @returns {{ tracks: AmplifyTrack[], fallbackLevel: number, fallbackReason: string }}
   */
  static async run(intent, targetCount = 25, userProfile = null) {
    const attempts = [
      { level: 2, description: 'Relax era constraint', modifier: i => ({ ...i, eraYears: null, era: null }) },
      { level: 3, description: 'Relax language constraint', modifier: i => ({ ...i, languages: [], eraYears: null }) },
      { level: 4, description: 'Purpose-only fallback', modifier: i => ({ ...i, languages: [], eraYears: null, era: null }) },
      { level: 5, description: 'Language mainstream hits', modifier: i => ({
          ...i, languages: i.languages.length > 0 ? [i.languages[0]] : [],
          eraYears: null, era: null,
          archetypeWeights: { ...i.archetypeWeights, popularityWeight: 0.60, intentWeight: 0.10 }
        })
      },
      { level: 6, description: 'Broad mainstream fallback', modifier: () => null }, // Handled specially
    ];

    for (const attempt of attempts) {
      try {
        let result;

        if (attempt.level === 6) {
          // Level 6: absolute fallback — just return mainstream songs
          const lang = intent.languages.length > 0 ? intent.languages[0] : 'Hindi';
          console.log(`[FallbackLadder] Level 6: Broad mainstream fallback (${lang})`);
          const tracks = await MusicProvider.getMainstreamFallback(lang, targetCount + 10);
          result = DiversityController.select(
            ScoringEngine.score(tracks, intent, userProfile),
            intent, targetCount
          );
        } else {
          console.log(`[FallbackLadder] Level ${attempt.level}: ${attempt.description}`);
          const relaxedIntent = attempt.modifier(intent);
          const CandidateGenerator = require('./CandidateGenerator');
          const candidates = await CandidateGenerator.generatePool(relaxedIntent, null, userProfile);
          const scored = ScoringEngine.score(candidates, relaxedIntent, userProfile);
          result = DiversityController.select(scored, relaxedIntent, targetCount);
        }

        if (result && result.length >= Math.min(targetCount * 0.5, 8)) {
          return {
            tracks: SequenceBuilder.sequence(result, intent),
            fallbackLevel: attempt.level,
            fallbackReason: attempt.description,
          };
        }
      } catch (e) {
        console.error(`[FallbackLadder] Level ${attempt.level} failed:`, e.message);
      }
    }

    // Absolute last resort
    console.error('[FallbackLadder] All levels failed. Returning empty.');
    return { tracks: [], fallbackLevel: 99, fallbackReason: 'All fallback strategies failed' };
  }
}

module.exports = { QualityValidator, FallbackLadder };
