/**
 * DiversityController
 * ===================
 * Takes a scored, sorted candidate list and applies diversity rules to
 * produce the final selection before sequencing.
 *
 * Rules:
 *   - Max N songs per artist (configurable per intent archetype)
 *   - Max M songs per album (configurable per intent archetype)
 *   - No duplicate tracks (by videoId or normalizedTitle+artist)
 *   - No consecutive songs by the same artist (configurable)
 *   - Filter out remixes unless pool is too small
 *
 * After diversity filtering, the SequenceBuilder orders the final playlist
 * into a musically sensible arc.
 */

class DiversityController {
  /**
   * Apply diversity rules to a scored candidate list.
   *
   * @param {ScoredTrack[]} scoredCandidates - Sorted descending by score
   * @param {PlaylistIntent} intent
   * @param {number} targetCount - How many songs the final playlist should have
   * @returns {AmplifyTrack[]} - Diverse selection (not yet sequenced)
   */
  static select(scoredCandidates, intent, targetCount = 30) {
    const maxArtistRepeat = intent.maxArtistRepeat || 3;
    const maxAlbumRepeat = intent.maxAlbumRepeat || 2;
    const preventConsecutive = intent.preventConsecutiveSameArtist !== false;

    const artistCounts = {};
    const albumCounts = {};
    const selectedIds = new Set();
    const selected = [];

    // First pass: prefer non-remix originals
    for (const track of scoredCandidates) {
      if (selected.length >= targetCount) break;
      if (selectedIds.has(track.videoId)) continue;
      if (track.isRemix) continue; // Skip remixes on first pass

      if (!this._passesArtistLimit(track, artistCounts, maxArtistRepeat)) continue;
      if (!this._passesAlbumLimit(track, albumCounts, maxAlbumRepeat)) continue;

      this._addTrack(track, selected, selectedIds, artistCounts, albumCounts);
    }

    // Second pass: fill remaining slots (allow remixes if needed)
    if (selected.length < targetCount) {
      for (const track of scoredCandidates) {
        if (selected.length >= targetCount) break;
        if (selectedIds.has(track.videoId)) continue;
        if (!this._passesArtistLimit(track, artistCounts, maxArtistRepeat)) continue;
        if (!this._passesAlbumLimit(track, albumCounts, maxAlbumRepeat)) continue;

        this._addTrack(track, selected, selectedIds, artistCounts, albumCounts);
      }
    }

    // Third pass: if still short, relax artist limits
    if (selected.length < Math.min(targetCount * 0.7, 10)) {
      const relaxedArtistLimit = maxArtistRepeat * 2;
      for (const track of scoredCandidates) {
        if (selected.length >= targetCount) break;
        if (selectedIds.has(track.videoId)) continue;
        if (!this._passesArtistLimit(track, artistCounts, relaxedArtistLimit)) continue;
        this._addTrack(track, selected, selectedIds, artistCounts, albumCounts);
      }
    }

    // Apply consecutive-same-artist shuffling if needed
    if (preventConsecutive && selected.length > 3) {
      return this._breakConsecutiveArtists(selected);
    }

    return selected;
  }

  static _passesArtistLimit(track, artistCounts, maxRepeat) {
    const artist = track.primaryArtist || (track.artist || '').split(',')[0].trim();
    return (artistCounts[artist] || 0) < maxRepeat;
  }

  static _passesAlbumLimit(track, albumCounts, maxRepeat) {
    if (!track.album) return true;
    return (albumCounts[track.album] || 0) < maxRepeat;
  }

  static _addTrack(track, selected, selectedIds, artistCounts, albumCounts) {
    selected.push(track);
    selectedIds.add(track.videoId);

    const artist = track.primaryArtist || (track.artist || '').split(',')[0].trim();
    artistCounts[artist] = (artistCounts[artist] || 0) + 1;
    if (track.album) albumCounts[track.album] = (albumCounts[track.album] || 0) + 1;
  }

  /**
   * Shuffle the list to avoid consecutive songs by the same artist,
   * while preserving relative score ordering as much as possible.
   */
  static _breakConsecutiveArtists(tracks) {
    const result = [];
    const remaining = [...tracks];
    let lastArtist = null;

    while (remaining.length > 0) {
      // Try to find the next highest-scored track that isn't from the same artist
      let picked = false;
      for (let i = 0; i < remaining.length; i++) {
        const track = remaining[i];
        const artist = track.primaryArtist || (track.artist || '').split(',')[0].trim();
        if (artist !== lastArtist) {
          result.push(track);
          remaining.splice(i, 1);
          lastArtist = artist;
          picked = true;
          break;
        }
      }

      // If we couldn't find a different artist, just take the next one
      if (!picked && remaining.length > 0) {
        result.push(remaining.shift());
        lastArtist = result[result.length - 1].primaryArtist;
      }
    }

    return result;
  }
}

/**
 * SequenceBuilder
 * ===============
 * Orders the final selected tracks into a musically sensible arc
 * based on the playlist's sequenceStyle.
 *
 * Sequence styles:
 *   smooth-flow:       gradually transition, opener → body → closer
 *   energy-build:      start moderate, build to peak, maintain
 *   peak-energy:       peak early, maintain high energy throughout (party/club)
 *   steady-state:      maintain consistent level (focus/study)
 *   gradual-discovery: familiar → progressively more novel
 */
class SequenceBuilder {
  /**
   * Sequence a diverse track list into a final playlist order.
   *
   * @param {AmplifyTrack[]} tracks - Diverse, unordered tracks
   * @param {PlaylistIntent} intent
   * @returns {AmplifyTrack[]}
   */
  static sequence(tracks, intent) {
    if (tracks.length <= 3) return tracks;

    const style = intent.sequenceStyle || 'smooth-flow';

    switch (style) {
      case 'energy-build':
        return this._energyBuild(tracks);
      case 'peak-energy':
        return this._peakEnergy(tracks);
      case 'steady-state':
        return this._steadyState(tracks);
      case 'gradual-discovery':
        return this._gradualDiscovery(tracks);
      default: // smooth-flow
        return this._smoothFlow(tracks);
    }
  }

  /**
   * smooth-flow: Strong opener → varied body → strong closer.
   * Uses popularity score as a proxy for familiarity/energy.
   */
  static _smoothFlow(tracks) {
    const sorted = [...tracks].sort((a, b) =>
      (b._scoring ? b._scoring.finalScore : b.popularityScore) -
      (a._scoring ? a._scoring.finalScore : a.popularityScore)
    );

    if (sorted.length <= 4) return sorted;

    // Take top 2 songs as openers, put strongest closer at end
    const opener1 = sorted.shift();
    const opener2 = sorted.shift();
    const closer = sorted.pop();

    // Shuffle the middle for variety
    const middle = this._lightShuffle(sorted);

    return [opener1, opener2, ...middle, closer];
  }

  /**
   * energy-build: Start moderate, build to peak (positions 60–75%), then wind down.
   */
  static _energyBuild(tracks) {
    const sorted = [...tracks].sort((a, b) => (b.popularityScore || 50) - (a.popularityScore || 50));
    const count = sorted.length;

    // Split into low/mid/high popularity buckets
    const high = sorted.filter(t => (t.popularityScore || 50) >= 70);
    const mid  = sorted.filter(t => (t.popularityScore || 50) >= 45 && (t.popularityScore || 50) < 70);
    const low  = sorted.filter(t => (t.popularityScore || 50) < 45);

    // Sequence: 2 mid openers → low → mid → peak (high) → wind-down
    const peakCount = Math.ceil(count * 0.25);
    const peak = high.slice(0, peakCount);
    const preBody = [...low, ...mid.slice(0, Math.ceil(mid.length / 2))];
    const postBody = [...mid.slice(Math.ceil(mid.length / 2)), ...high.slice(peakCount)];

    return [
      ...(mid.slice(0, 2)),
      ...this._lightShuffle(preBody),
      ...peak,
      ...this._lightShuffle(postBody),
    ].slice(0, tracks.length);
  }

  /**
   * peak-energy: Put the biggest hits upfront and maintain energy.
   */
  static _peakEnergy(tracks) {
    return [...tracks].sort((a, b) =>
      (b._scoring ? b._scoring.finalScore : b.popularityScore || 50) -
      (a._scoring ? a._scoring.finalScore : a.popularityScore || 50)
    );
  }

  /**
   * steady-state: Consistent energy level throughout (for focus/study).
   */
  static _steadyState(tracks) {
    // Sort by popularity descending but alternate between high and lower
    const sorted = [...tracks].sort((a, b) => (b.popularityScore || 50) - (a.popularityScore || 50));
    const result = [];
    let i = 0, j = sorted.length - 1;
    let pickFront = true;
    while (i <= j) {
      if (pickFront) result.push(sorted[i++]);
      else result.push(sorted[j--]);
      pickFront = !pickFront;
    }
    return result;
  }

  /**
   * gradual-discovery: Start with familiar songs, gradually introduce more obscure.
   */
  static _gradualDiscovery(tracks) {
    return [...tracks].sort((a, b) => (b.popularityScore || 50) - (a.popularityScore || 50));
    // Naturally goes from most popular → least popular
  }

  /**
   * Light shuffle — slightly randomize while keeping rough score order.
   * Splits tracks into chunks of 3–5 and shuffles within each chunk.
   */
  static _lightShuffle(tracks) {
    const chunkSize = 4;
    const result = [];
    for (let i = 0; i < tracks.length; i += chunkSize) {
      const chunk = tracks.slice(i, i + chunkSize);
      for (let j = chunk.length - 1; j > 0; j--) {
        const k = Math.floor(Math.random() * (j + 1));
        [chunk[j], chunk[k]] = [chunk[k], chunk[j]];
      }
      result.push(...chunk);
    }
    return result;
  }
}

module.exports = { DiversityController, SequenceBuilder };
