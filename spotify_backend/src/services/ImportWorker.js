/**
 * ImportWorker
 * ============
 * Async import job processor. Runs an import job from start to finish,
 * fetching from the provider, matching against Amplify catalog, creating
 * playlists, updating the library, and seeding TasteEngine.
 *
 * Key design principles:
 *   - Resumable: job cursor is saved after every paginated batch
 *   - Idempotent: duplicate imports are prevented via compound indexes
 *   - Non-blocking: processes in batches, never within an HTTP request
 *   - Observable: job status/counts are updated in real-time
 */

const User        = require('../models/User');
const ImportJob   = require('../models/ImportJob');
const ImportedTrack = require('../models/ImportedTrack');
const ListeningEvent = require('../models/ListeningEvent');
const TasteEngine = require('./TasteEngine');
const TrackMatcher = require('./TrackMatcher');

const BATCH_SIZE = 50; // tracks per matching batch

class ImportWorker {
  /**
   * Run a complete import job.
   * @param {string} jobId   - ImportJob._id
   * @param {object} importer - MusicLibraryImporter instance (already authenticated)
   */
  static async run(jobId, importer) {
    let job;
    try {
      job = await ImportJob.findById(jobId);
      if (!job) throw new Error(`Job ${jobId} not found`);
      if (job.status === 'CANCELLED') return;

      await this._updateJob(job, { status: 'AUTHORIZING' });

      // Verify authentication before doing anything
      await importer.authenticate();

      await this._updateJob(job, { status: 'FETCHING' });

      // ── Phase 1: Import playlists ───────────────────────────────────────
      const { playlistMap, totalTracks } = await this._importPlaylists(job, importer);

      await this._updateJob(job, {
        status: 'FETCHING',
        totalItems: totalTracks,
      });

      // ── Phase 2: Fetch & match all tracks ──────────────────────────────
      await this._updateJob(job, { status: 'MATCHING' });
      const allTracks = await this._collectAllTracks(job, importer, playlistMap);

      await this._updateJob(job, { status: 'IMPORTING' });
      await this._importToAmplify(job, allTracks, playlistMap);

      // ── Phase 3: Library / saved tracks ────────────────────────────────
      await this._importLibrary(job, importer);

      // ── Phase 4: Listening history → TasteEngine ───────────────────────
      await this._updateJob(job, { status: 'PROCESSING_HISTORY' });
      await this._importListeningHistory(job, importer);

      // ── Complete ────────────────────────────────────────────────────────
      const finalJob = await ImportJob.findById(jobId);
      const hasMissed = finalJob.unavailableItems > 0 || finalJob.reviewItems > 0;

      await this._updateJob(job, {
        status: hasMissed ? 'PARTIAL' : 'COMPLETED',
        completedAt: new Date(),
      });

      // Trigger TasteEngine recalculation
      TasteEngine.calculateUserProfile(job.userId).catch(err =>
        console.error('[ImportWorker] TasteEngine error after import:', err.message)
      );

    } catch (err) {
      console.error(`[ImportWorker] Job ${jobId} failed:`, err.message);
      if (job) {
        await this._updateJob(job, {
          status: 'FAILED',
          error: err.message.substring(0, 500),
          completedAt: new Date(),
        }).catch(() => {});
      }
    }
  }

  // ─── Private: Phase 1 ─ Playlists ──────────────────────────────────────

  static async _importPlaylists(job, importer) {
    const playlistMap = {}; // sourcePlaylistId → { id, name, description, thumbnailUrl }
    let totalTracks = 0;
    let cursor = job.cursor?.playlistCursor || null;

    do {
      const { playlists, nextCursor } = await importer.getPlaylists(cursor);

      for (const pl of playlists) {
        playlistMap[pl.id] = pl;
        totalTracks += pl.totalTracks;
      }

      cursor = nextCursor;
      await this._updateJob(job, {
        cursor: { ...(job.cursor || {}), playlistCursor: cursor },
        playlistsImported: Object.keys(playlistMap).length,
      });

    } while (cursor);

    return { playlistMap, totalTracks };
  }

  // ─── Private: Phase 2 ─ Collect + Match All Tracks ─────────────────────

  static async _collectAllTracks(job, importer, playlistMap) {
    const allTracks = [];

    for (const [playlistId, playlist] of Object.entries(playlistMap)) {
      let cursor = null;

      do {
        const { tracks, nextCursor } = await importer.getPlaylistTracks(playlistId, cursor);

        for (const t of tracks) {
          // Tag each track with which playlist it belongs to
          t.playlistIds = t.playlistIds || [];
          if (!t.playlistIds.includes(playlistId)) {
            t.playlistIds.push(playlistId);
          }
          allTracks.push(t);
        }

        cursor = nextCursor;
      } while (cursor);
    }

    // Deduplicate by sourceTrackId (same track in multiple playlists)
    const seen = new Set();
    const unique = [];
    for (const t of allTracks) {
      if (!seen.has(t.sourceTrackId)) {
        seen.add(t.sourceTrackId);
        unique.push(t);
      } else {
        // Merge playlist memberships into the first occurrence
        const existing = unique.find(u => u.sourceTrackId === t.sourceTrackId);
        if (existing) {
          for (const pid of (t.playlistIds || [])) {
            if (!existing.playlistIds.includes(pid)) existing.playlistIds.push(pid);
          }
        }
      }
    }

    return unique;
  }

  // ─── Private: Phase 3 ─ Match + Write to Amplify ───────────────────────

  static async _importToAmplify(job, allTracks, playlistMap) {
    const source = job.provider.replace('_file', ''); // 'spotify_file' → 'spotify'

    // Process in batches
    for (let i = 0; i < allTracks.length; i += BATCH_SIZE) {
      if (await this._isCancelled(job._id)) return;

      const batch = allTracks.slice(i, i + BATCH_SIZE);
      const { results } = await TrackMatcher.matchBatch(batch);

      // Upsert ImportedTrack records (idempotent via compound index)
      const ops = results.map(r => ({
        updateOne: {
          filter: {
            importJobId: job._id,
            source,
            sourceTrackId: r.track.sourceTrackId,
          },
          update: {
            $setOnInsert: {
              importJobId: job._id,
              userId: job.userId,
              source,
              sourceTrackId: r.track.sourceTrackId,
              sourcePlaylistIds: r.track.playlistIds,
              title: r.track.title,
              artist: r.track.artist,
              artists: r.track.artists,
              album: r.track.album,
              isrc: r.track.isrc,
              durationMs: r.track.durationMs,
              thumbnailUrl: r.track.thumbnailUrl,
              normalizedTitle: r.track.title?.toLowerCase().trim(),
              normalizedArtist: r.track.artist?.toLowerCase().trim(),
              createdAt: new Date(),
            },
            $set: {
              matchStatus: r.matchStatus,
              confidenceScore: r.confidenceScore,
              amplifyVideoId: r.amplifyVideoId,
              reviewCandidates: r.reviewCandidates,
            },
          },
          upsert: true,
        },
      }));

      if (ops.length > 0) await ImportedTrack.bulkWrite(ops);

      // Update job progress
      const matched = results.filter(r => r.matchStatus === 'MATCHED').length;
      const review  = results.filter(r => r.matchStatus === 'REVIEW_REQUIRED').length;
      const unavail = results.filter(r => r.matchStatus === 'UNAVAILABLE').length;

      await ImportJob.updateOne({ _id: job._id }, {
        $inc: {
          processedItems: batch.length,
          matchedItems: matched,
          reviewItems: review,
          unavailableItems: unavail,
        },
      });
    }

    // Now recreate playlists in Amplify
    await this._recreatePlaylists(job, playlistMap, source);
  }

  static async _recreatePlaylists(job, playlistMap, source) {
    const user = await User.findById(job.userId);
    if (!user) return;

    for (const [sourcePlaylistId, playlist] of Object.entries(playlistMap)) {
      // Idempotency: skip if this playlist was already imported
      const existingPlaylist = user.playlists.find(
        p => p.importMeta?.sourceId === sourcePlaylistId &&
             p.importMeta?.source === source
      );

      // Get all MATCHED ImportedTrack records for this playlist
      const importedTracks = await ImportedTrack.find({
        importJobId: job._id,
        sourcePlaylistIds: sourcePlaylistId,
        matchStatus: 'MATCHED',
        amplifyVideoId: { $exists: true, $ne: null },
      }).lean();

      if (existingPlaylist) {
        // Update: add any newly matched tracks
        const existingIds = new Set(existingPlaylist.tracks.map(t => t.videoId));
        const newTracks = importedTracks.filter(it => !existingIds.has(it.amplifyVideoId));

        if (newTracks.length > 0) {
          await User.updateOne(
            { _id: job.userId, 'playlists._id': existingPlaylist._id },
            {
              $push: {
                'playlists.$.tracks': {
                  $each: newTracks.map(it => this._buildAmplifyTrack(it)),
                },
              },
              $set: {
                'playlists.$.importMeta.unavailableCount':
                  importedTracks.filter(it => it.matchStatus !== 'MATCHED').length,
              },
            }
          );
        }
      } else {
        // Create new playlist
        const amplifyTracks = importedTracks.map(it => this._buildAmplifyTrack(it));

        await User.updateOne(
          { _id: job.userId },
          {
            $push: {
              playlists: {
                name: playlist.name,
                tracks: amplifyTracks,
                createdAt: new Date(),
                importMeta: {
                  source,
                  sourceId: sourcePlaylistId,
                  sourceUrl: playlist.sourceUrl,
                  importJobId: String(job._id),
                  description: playlist.description,
                  thumbnailUrl: playlist.thumbnailUrl,
                  unavailableCount: importedTracks.filter(it => it.matchStatus !== 'MATCHED').length,
                },
              },
            },
          }
        );
      }
    }
  }

  // ─── Private: Phase 4 ─ Library (Saved Tracks) ─────────────────────────

  static async _importLibrary(job, importer) {
    try {
      let cursor = null;
      const libraryTracks = [];

      do {
        const { tracks, nextCursor } = await importer.getLibrary(cursor);
        libraryTracks.push(...tracks);
        cursor = nextCursor;
      } while (cursor && libraryTracks.length < 5000); // safety limit

      // We must add libraryTracks count to totalItems since we didn't know them in Phase 1
      job.totalItems = (job.totalItems || 0) + libraryTracks.length;
      await ImportJob.updateOne({ _id: job._id }, {
        $inc: { totalItems: libraryTracks.length },
      });

      // Match library tracks in batches so UI progress updates
      const matched = [];
      
      for (let i = 0; i < libraryTracks.length; i += BATCH_SIZE) {
        if (await this._isCancelled(job._id)) return;
        
        const batch = libraryTracks.slice(i, i + BATCH_SIZE);
        const { results } = await TrackMatcher.matchBatch(batch);
        
        const batchMatched = results.filter(r => r.matchStatus === 'MATCHED' && r.amplifyVideoId);
        matched.push(...batchMatched);

        // Update progress in the database so the frontend can see it
        await ImportJob.updateOne({ _id: job._id }, {
          $inc: {
            processedItems: batch.length,
            matchedItems: batchMatched.length,
            reviewItems: results.filter(r => r.matchStatus === 'REVIEW_REQUIRED').length,
            unavailableItems: results.filter(r => r.matchStatus === 'UNAVAILABLE').length,
          }
        });
      }

      // Add matched tracks to user's Liked Songs (if not already there)
      const user = await User.findById(job.userId);
      if (!user) return;

      const existingLikedIds = new Set(user.likedSongs.map(t => t.videoId));
      const newLiked = matched
        .filter(r => !existingLikedIds.has(r.amplifyVideoId))
        .map(r => this._buildAmplifyTrack(r));

      if (newLiked.length > 0) {
        await User.updateOne(
          { _id: job.userId },
          { $push: { likedSongs: { $each: newLiked } } }
        );
      }

    } catch (err) {
      // NOT_SUPPORTED is expected for providers without library access
      if (err.code !== 'NOT_SUPPORTED') {
        console.error('[ImportWorker] Library import error:', err.message);
      }
    }
  }

  // ─── Private: Phase 5 ─ Listening History → TasteEngine ────────────────

  static async _importListeningHistory(job, importer) {
    const source = job.provider.replace('_file', '');
    const sourceType = `${source}_import`; // 'spotify_import' | 'youtube_import'

    try {
      let cursor = null;
      const historyEvents = [];

      do {
        const { events, nextCursor } = await importer.getListeningHistory(cursor);
        historyEvents.push(...events);
        cursor = nextCursor;
      } while (cursor && historyEvents.length < 50);

      await this._writeHistoryEvents(job.userId, historyEvents, sourceType);
      await ImportJob.updateOne(
        { _id: job._id },
        { $inc: { historyRecords: historyEvents.length } }
      );

    } catch (err) {
      if (err.code === 'NOT_SUPPORTED') return; // Provider doesn't support this
      console.error('[ImportWorker] History import error:', err.message);
    }
  }

  /**
   * Write parsed history file events into TasteEngine.
   * Called directly from the file upload route.
   */
  static async writeHistoryFileEvents(userId, events, sourceType) {
    await this._writeHistoryEvents(userId, events, sourceType);
    TasteEngine.calculateUserProfile(userId).catch(() => {});
  }

  static async _writeHistoryEvents(userId, events, sourceType) {
    if (!events || events.length === 0) return;

    const docs = events.map(e => ({
      userId,
      songId: `import_${Buffer.from(`${e.title}:${e.artist}`).toString('base64').substring(0, 20)}`,
      song: {
        videoId: `import_${Buffer.from(`${e.title}:${e.artist}`).toString('base64').substring(0, 20)}`,
        title: e.title || 'Unknown',
        artist: e.artist || 'Unknown',
        thumbnailUrl: '',
        durationMs: e.durationMs || e.msPlayed || 0,
      },
      eventType: 'PLAY',
      durationPlayedMs: e.msPlayed || 0,
      completionPercent: e.durationMs && e.msPlayed
        ? Math.round((e.msPlayed / e.durationMs) * 100)
        : 50,
      sourceType,
      createdAt: e.playedAt || new Date(),
    }));

    try {
      await ListeningEvent.insertMany(docs, { ordered: false });
    } catch (err) {
      // Ignore duplicate key errors (idempotent re-import)
      if (err.code !== 11000) {
        console.error('[ImportWorker] History insert error:', err.message);
      }
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  static _buildAmplifyTrack(importedTrack) {
    return {
      videoId:      importedTrack.amplifyVideoId,
      title:        importedTrack.title,
      artist:       importedTrack.artist,
      thumbnailUrl: importedTrack.thumbnailUrl || '',
      durationMs:   importedTrack.durationMs || 0,
      source:       'saavn',
    };
  }

  static async _updateJob(job, update) {
    Object.assign(job, update);
    await ImportJob.updateOne({ _id: job._id }, { $set: update });
  }

  static async _isCancelled(jobId) {
    const j = await ImportJob.findById(jobId, 'status').lean();
    return j?.status === 'CANCELLED';
  }
}

module.exports = ImportWorker;
