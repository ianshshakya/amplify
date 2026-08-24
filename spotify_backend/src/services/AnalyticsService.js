const ListeningEvent = require('../models/ListeningEvent');
const SongStatistic = require('../models/SongStatistic');

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
      const { song, eventType, durationPlayedMs, completionPercent, context, sessionId } = eventData;
      
      if (!song || !song.videoId || !eventType) {
        throw new Error('Invalid event data: song and eventType are required.');
      }

      // 1. Record the raw event for taste profiling (expires after 90 days)
      await ListeningEvent.create({
        userId,
        songId: song.videoId,
        song,
        eventType,
        durationPlayedMs: durationPlayedMs || 0,
        completionPercent: completionPercent || 0,
        context,
        sessionId
      });

      // 2. Incrementally update the aggregate SongStatistics
      await this._updateSongStatistics(song, eventType);

      return true;
    } catch (error) {
      console.error('AnalyticsService error:', error.message);
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
      case 'LIKE':
        update.$inc = { lifetimeLikes: 1, popularityScore: 3 };
        break;
      case 'UNLIKE':
        update.$inc = { lifetimeLikes: -1, popularityScore: -3 };
        break;
      default:
        return; // Ignore PAUSE or custom events for aggregates
    }

    await SongStatistic.findOneAndUpdate(
      { songId },
      update,
      { upsert: true, new: true }
    );
  }
}

module.exports = AnalyticsService;
