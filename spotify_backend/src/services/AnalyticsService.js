const ListeningEvent = require('../models/ListeningEvent');
const SongStatistic = require('../models/SongStatistic');
const TasteEngine = require('./TasteEngine');

// In-memory queues for batch processing
const EVENT_QUEUE = [];
const STATS_QUEUE = [];

// Flush queues to MongoDB every 10 seconds
setInterval(async () => {
  if (EVENT_QUEUE.length > 0) {
    const batch = EVENT_QUEUE.splice(0, EVENT_QUEUE.length);
    try {
      await ListeningEvent.insertMany(batch);
      
      // Extract unique userIds from the batch and trigger TasteEngine profile recalculation
      const uniqueUserIds = [...new Set(batch.map(e => e.userId))];
      for (const uid of uniqueUserIds) {
        if (uid) {
          // Fire and forget (don't block the interval)
          TasteEngine.calculateUserProfile(uid).catch(err => {
            console.error(`[AnalyticsService] Failed to calc profile for ${uid}:`, err.message);
          });
        }
      }
    } catch (e) {
      console.error('[AnalyticsService] Batch insert ListeningEvent error:', e.message);
    }
  }

  if (STATS_QUEUE.length > 0) {
    const statsBatch = STATS_QUEUE.splice(0, STATS_QUEUE.length);
    
    // Consolidate updates for the same song before bulking to save ops
    const consolidated = {};
    for (const item of statsBatch) {
      if (!consolidated[item.songId]) consolidated[item.songId] = { ...item.update };
      else {
        const existing = consolidated[item.songId];
        if (item.update.$inc) {
          existing.$inc = existing.$inc || {};
          for (const key in item.update.$inc) {
            existing.$inc[key] = (existing.$inc[key] || 0) + item.update.$inc[key];
          }
        }
        existing.$set = { ...existing.$set, ...item.update.$set };
      }
    }

    try {
      const bulkOps = Object.keys(consolidated).map(songId => ({
        updateOne: {
          filter: { songId },
          update: consolidated[songId],
          upsert: true
        }
      }));
      if (bulkOps.length > 0) await SongStatistic.bulkWrite(bulkOps);
    } catch (e) {
      console.error('[AnalyticsService] Batch update SongStatistic error:', e.message);
    }
  }
}, 10000);

/**
 * Service to handle processing of listening events and aggregating
 * them into the scalable SongStatistics model.
 */
class AnalyticsService {
  /**
   * Processes a single listening event asynchronously.
   * In a high-scale production app, this would be pushed to a message queue (e.g., RabbitMQ).
   * For this implementation, we process it synchronously or slightly deferred.
   */
  static async processEvent(eventData, userId) {
    try {
      const { song, eventType, durationPlayedMs, completionPercent, context, sessionId, sourceType } = eventData;
      
      if (!song || !song.videoId || !eventType) {
        throw new Error('Invalid event data: song and eventType are required.');
      }

      // 1. Queue the raw event for batch insertion
      EVENT_QUEUE.push({
        userId,
        songId: song.videoId,
        song,
        eventType,
        durationPlayedMs: durationPlayedMs || 0,
        completionPercent: completionPercent || 0,
        context,
        sessionId,
        sourceType: sourceType || 'native_amplify',
        createdAt: new Date()
      });

      // 2. Queue the aggregate SongStatistics update
      this._updateSongStatistics(song, eventType);

      return true;
    } catch (error) {
      if (process.env.NODE_ENV !== 'production') console.error('AnalyticsService error:', error.message);
      // We don't want analytics failures to break the client API
      return false; 
    }
  }

  /**
   * Internal method to atomically update lifetime aggregates.
   */
  static async _updateSongStatistics(song, eventType) {
    const songId = song.videoId;
    let update = { 
      $setOnInsert: { song }, // Only set the song snapshot if this is the first time we see it
      $set: { lastUpdatedAt: Date.now() }
    };

    switch (eventType) {
      case 'PLAY':
        update.$inc = { lifetimePlays: 1, popularityScore: 1 };
        break;
      case 'COMPLETE':
        update.$inc = { lifetimeCompletions: 1, popularityScore: 2 };
        break;
      case 'SKIP':
        update.$inc = { lifetimeSkips: 1, popularityScore: -2 };
        break;
      case 'EARLY_SKIP':  // Skipped before 20% completion
        update.$inc = { lifetimeSkips: 1, popularityScore: -5 };
        break;
      case 'REPLAY':  // User played the same song again
        update.$inc = { lifetimePlays: 1, popularityScore: 4 };
        break;
      case 'LIKE':
        update.$inc = { lifetimeLikes: 1, popularityScore: 3 };
        break;
      case 'UNLIKE':
        update.$inc = { lifetimeLikes: -1, popularityScore: -3 };
        break;
      case 'DISLIKE':
        update.$inc = { lifetimeLikes: -1, popularityScore: -5 };
        break;
      default:
        return; // Ignore PAUSE or custom events for aggregates
    }

    STATS_QUEUE.push({ songId, update });
  }
}

module.exports = AnalyticsService;
