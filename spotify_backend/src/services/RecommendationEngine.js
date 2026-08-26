/**
 * RecommendationEngine
 * ====================
 * High-level recommendation entry points.
 * All actual intelligence is delegated to PlaylistIntelligence.
 *
 * Fixes from audit:
 *   - Fixed silent bug: artistAffinity.has() doesn't work on Mongoose Map objects
 *   - Replaced random shuffle in getSongRadio with scored/diverse selection
 *   - getDailyMix now uses PlaylistIntelligence pipeline
 *   - Cold-start handled gracefully with mainstream popular fallback
 */

const PlaylistIntelligence = require('./PlaylistIntelligence');
const UserMusicProfile = require('../models/UserMusicProfile');
const SongStatistic = require('../models/SongStatistic');
const MusicProvider = require('./MusicProvider');

class RecommendationEngine {
  /**
   * Generates a personalized "Daily Mix" for a user.
   * Uses PlaylistIntelligence pipeline with the user's taste profile.
   */
  static async getDailyMix(userId) {
    try {
      const profile = await UserMusicProfile.findOne({ userId });

      // Determine primary language preference from user profile
      let primaryLanguage = null;
      if (profile && profile.languageAffinity) {
        // Fix: use Mongoose Map API correctly
        const langMap = profile.languageAffinity instanceof Map
          ? profile.languageAffinity
          : new Map(Object.entries(profile.languageAffinity));

        let maxScore = 0;
        for (const [lang, score] of langMap.entries()) {
          if (score > maxScore) { maxScore = score; primaryLanguage = lang; }
        }
      }

      const intentInput = {
        id: 'daily-mix',
        title: 'Daily Mix',
        description: primaryLanguage ? `Personalized mix in ${primaryLanguage}` : 'Your personalized mix',
        intent: {
          purpose: 'general',
          languages: primaryLanguage ? [primaryLanguage] : [],
          popularity: 'high',
          discovery: 'medium',
        },
      };

      const result = await PlaylistIntelligence.generate(intentInput, userId, { targetCount: 25, forceRefresh: true });
      return result.songs;
    } catch (error) {
      console.error('RecommendationEngine getDailyMix error:', error.message);
      // Cold-start fallback
      const tracks = await MusicProvider.getMainstreamFallback('Hindi', 25);
      return tracks.map(t => ({
        videoId: t.videoId, title: t.title, artist: t.artist,
        thumbnailUrl: t.thumbnailUrl, durationMs: t.durationMs, source: t.source,
      }));
    }
  }

  /**
   * Generates a radio stream starting from a specific song.
   * Uses PlaylistIntelligence.getRadioTracks — properly scored, not randomly shuffled.
   */
  static async getSongRadio(songId, userId, limit = 15, sessionContext = {}) {
    try {
      // Try to reconstruct seed track from SongStatistic or search
      let seedTrack = null;
      const stat = await SongStatistic.findOne({ songId });
      if (stat && stat.song) {
        seedTrack = stat.song;
      }

      if (!seedTrack) {
        // Fallback: we don't have the track in our DB, return related via JioSaavn
        const related = await MusicProvider.getRelated(songId, limit);
        return related.map(t => ({
          videoId: t.videoId, title: t.title, artist: t.artist,
          thumbnailUrl: t.thumbnailUrl, durationMs: t.durationMs, source: t.source,
        }));
      }

      return await PlaylistIntelligence.getRadioTracks(seedTrack, sessionContext, userId, limit);
    } catch (error) {
      console.error('RecommendationEngine getSongRadio error:', error.message);
      return [];
    }
  }

  /**
   * Generates a radio stream for an artist.
   */
  static async getArtistRadio(artistName, userId, limit = 20) {
    try {
      const intentInput = {
        id: 'artist-radio',
        title: `${artistName} Radio`,
        intent: { purpose: 'artist', popularity: 'high', discovery: 'low' },
        searchQuery: artistName,
      };
      const result = await PlaylistIntelligence.generate(intentInput, userId, { targetCount: limit });
      return result.songs;
    } catch (error) {
      console.error('RecommendationEngine getArtistRadio error:', error.message);
      return [];
    }
  }

  /**
   * "One Song Away": High-confidence discovery track.
   */
  static async getOneSongAway(userId) {
    try {
      const result = await PlaylistIntelligence.discover(userId, 10);
      const songs = result.songs || [];
      if (songs.length > 0) {
        return songs[Math.floor(Math.random() * Math.min(songs.length, 5))];
      }
      return null;
    } catch (error) {
      console.error('RecommendationEngine getOneSongAway error:', error.message);
      return null;
    }
  }
}

module.exports = RecommendationEngine;
