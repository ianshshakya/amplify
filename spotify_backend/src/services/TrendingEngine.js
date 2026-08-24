const ListeningEvent = require('../models/ListeningEvent');
const SongStatistic = require('../models/SongStatistic');

class TrendingEngine {
  /**
   * Refreshes trend scores for all active songs by aggregating recent ListeningEvents.
   * In production, this should run periodically via a cron job (e.g., every hour).
   */
  static async refreshTrends() {
    try {
      console.log('Starting TrendingEngine.refreshTrends()...');
      
      const now = new Date();
      const oneDayAgo = new Date(now.getTime() - (24 * 60 * 60 * 1000));
      const sevenDaysAgo = new Date(now.getTime() - (7 * 24 * 60 * 60 * 1000));
      const thirtyDaysAgo = new Date(now.getTime() - (30 * 24 * 60 * 60 * 1000));

      // Use MongoDB aggregation pipeline for maximum efficiency
      const aggregation = await ListeningEvent.aggregate([
        {
          $match: {
            eventType: 'PLAY',
            createdAt: { $gte: thirtyDaysAgo }
          }
        },
        {
          $group: {
            _id: "$songId",
            song: { $first: "$song" },
            dailyPlays: {
              $sum: { $cond: [{ $gte: ["$createdAt", oneDayAgo] }, 1, 0] }
            },
            weeklyPlays: {
              $sum: { $cond: [{ $gte: ["$createdAt", sevenDaysAgo] }, 1, 0] }
            },
            monthlyPlays: {
              $sum: 1 // Since we already matched $gte thirtyDaysAgo
            }
          }
        }
      ]);

      console.log(`Aggregated trends for ${aggregation.length} active songs.`);

      // Update SongStatistics with time decay weights
      // Weights: Daily = 3.0, Weekly = 1.5, Monthly = 0.5
      // This ensures a song with 100 plays today outranks a song with 200 plays 25 days ago.
      let bulkOps = [];
      for (const stat of aggregation) {
        const trendScore = (stat.dailyPlays * 3.0) + (stat.weeklyPlays * 1.5) + (stat.monthlyPlays * 0.5);

        bulkOps.push({
          updateOne: {
            filter: { songId: stat._id },
            update: {
              $set: {
                song: stat.song,
                dailyPlays: stat.dailyPlays,
                weeklyPlays: stat.weeklyPlays,
                monthlyPlays: stat.monthlyPlays,
                trendScore: trendScore,
                lastUpdatedAt: now
              }
            },
            upsert: true
          }
        });

        // Execute in batches to prevent memory limits on huge datasets
        if (bulkOps.length > 500) {
          await SongStatistic.bulkWrite(bulkOps);
          bulkOps = [];
        }
      }

      if (bulkOps.length > 0) {
        await SongStatistic.bulkWrite(bulkOps);
      }

      console.log('TrendingEngine.refreshTrends() completed successfully.');
      return true;
    } catch (error) {
      console.error('TrendingEngine Error:', error);
      return false;
    }
  }
}

module.exports = TrendingEngine;
