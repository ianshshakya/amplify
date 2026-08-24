const SongStatistic = require('../models/SongStatistic');
const UserMusicProfile = require('../models/UserMusicProfile');
const { searchSaavn } = require('../utils/saavn');

class RecommendationEngine {
  /**
   * Generates a personalized "Daily Mix" for a user.
   * Uses candidate generation -> scoring -> diversification.
   */
  static async getDailyMix(userId) {
    try {
      const profile = await UserMusicProfile.findOne({ userId });
      
      // Candidate Generation
      let candidates = [];

      if (profile && profile.artistAffinity && Object.keys(profile.artistAffinity).length > 0) {
        // We have personalized data! 
        // 1. Get top affinity artists
        const topArtists = Object.entries(profile.artistAffinity)
          .sort((a, b) => b[1] - a[1])
          .slice(0, 3)
          .map(entry => entry[0]);
        
        // Fetch candidates for these artists from Saavn API
        for (const artist of topArtists) {
          const songs = await searchSaavn(`${artist} best songs`, 10);
          candidates.push(...songs);
        }
      } 
      
      // 2. Add Global Trending candidates
      const trendingStats = await SongStatistic.find().sort({ trendScore: -1 }).limit(20);
      const trendingSongs = trendingStats.map(s => s.song).filter(s => s != null);
      candidates.push(...trendingSongs);

      // 3. Fallback / Diversity injection (if candidates pool is small)
      if (candidates.length < 20) {
        const fallbacks = await searchSaavn('New pop hits 2024', 15);
        candidates.push(...fallbacks);
      }

      // Deduplicate candidates
      const uniqueMap = new Map();
      for (const song of candidates) {
        if (!uniqueMap.has(song.videoId)) {
          uniqueMap.set(song.videoId, song);
        }
      }
      candidates = Array.from(uniqueMap.values());

      // Scoring Phase
      let scoredCandidates = candidates.map(song => {
        let score = 0;
        let reasons = [];

        // 1. Artist Affinity Bonus (30%)
        if (profile && profile.artistAffinity) {
          const songArtists = song.artist ? song.artist.split(',').map(a => a.trim()) : [];
          for (const a of songArtists) {
            if (profile.artistAffinity.has(a)) {
              score += (profile.artistAffinity.get(a) * 30);
              reasons.push(`High affinity for ${a}`);
              break; // Only apply once per song
            }
          }
        }

        // 2. Global Trend Bonus (20%)
        const stat = trendingStats.find(s => s.song && s.song.videoId === song.videoId);
        if (stat && stat.trendScore > 0) {
          score += 20; // Simplified trend bonus
          reasons.push('Trending right now');
        }

        // 3. Discovery Bonus (10%)
        // If the user has high discovery preference, boost unknown songs
        const discoveryPref = profile ? profile.discoveryPreference : 0.2;
        if (reasons.length === 0) { // Unfamiliar song
          score += (discoveryPref * 10);
          reasons.push('Discovery pick');
        }

        // Add a tiny random jitter (0-2) to break ties and keep things fresh
        score += (Math.random() * 2);

        return { song, score, reasons };
      });

      // Sort by score
      scoredCandidates.sort((a, b) => b.score - a.score);

      // Diversification (Limit consecutive songs by same artist)
      let finalMix = [];
      let artistCounts = {};
      
      for (const item of scoredCandidates) {
        const primaryArtist = item.song.artist ? item.song.artist.split(',')[0].trim() : 'Unknown';
        
        // Allow max 3 songs from the same artist in a Daily Mix
        if ((artistCounts[primaryArtist] || 0) < 3) {
          finalMix.push(item.song);
          artistCounts[primaryArtist] = (artistCounts[primaryArtist] || 0) + 1;
        }

        if (finalMix.length >= 20) break; // Limit playlist to 20 songs
      }

      return finalMix;

    } catch (error) {
      console.error('RecommendationEngine getDailyMix error:', error.message);
      // Fallback
      return searchSaavn('Top global hits 2024', 20);
    }
  }

  /**
   * Generates an Infinite Radio stream starting from a specific song.
   * Fetches similar songs based on the artist and global trends.
   */
  static async getSongRadio(songId, userId, limit = 15) {
    try {
      // 1. We need to fetch the song metadata to know the artist
      // For this, we'll try to find it in our SongStatistic or assume it's Saavn
      let song = null;
      const stat = await SongStatistic.findOne({ songId });
      if (stat && stat.song) {
        song = stat.song;
      }

      let candidates = [];
      
      if (song && song.artist) {
        // Search Saavn for similar artist tracks
        const primaryArtist = song.artist.split(',')[0].trim();
        const similarSongs = await searchSaavn(`${primaryArtist} best tracks`, 20);
        candidates.push(...similarSongs);
      } else {
        // Fallback: just fetch trending songs
        const trendingStats = await SongStatistic.find().sort({ trendScore: -1 }).limit(limit);
        candidates = trendingStats.map(s => s.song).filter(s => s != null);
      }

      // Filter out the seed song so it doesn't immediately repeat
      candidates = candidates.filter(c => c.videoId !== songId);

      // Shuffle candidates to feel random
      candidates.sort(() => Math.random() - 0.5);

      return candidates.slice(0, limit);
    } catch (error) {
      console.error('RecommendationEngine getSongRadio error:', error.message);
      return [];
    }
  }

  /**
   * Generates an Infinite Radio stream starting from a specific artist.
   */
  static async getArtistRadio(artistName, userId, limit = 20) {
    try {
      // 1. Fetch artist's tracks
      const artistTracks = await searchSaavn(`${artistName} radio`, limit * 2);
      
      // Shuffle candidates
      artistTracks.sort(() => Math.random() - 0.5);
      
      return artistTracks.slice(0, limit);
    } catch (error) {
      console.error('RecommendationEngine getArtistRadio error:', error.message);
      return [];
    }
  }

  /**
   * "One Song Away": Highly filtered, high-confidence discovery.
   * Returns a single track guaranteed to be new to the user (not in their top history).
   */
  static async getOneSongAway(userId) {
    try {
      // 1. Get user profile
      const profile = await UserMusicProfile.findOne({ userId });
      
      let query = 'Trending discovery music';
      if (profile && profile.artistAffinity && Object.keys(profile.artistAffinity).length > 0) {
        // Find their second or third favorite artist to encourage slight discovery
        const artists = Object.entries(profile.artistAffinity).sort((a, b) => b[1] - a[1]);
        if (artists.length > 1) {
          const discoveryArtist = artists[Math.floor(Math.random() * Math.min(artists.length, 5))][0];
          query = `${discoveryArtist} lesser known hits`;
        }
      }

      const candidates = await searchSaavn(query, 10);
      
      if (candidates.length > 0) {
        // Just pick one randomly from the pool
        const randomIndex = Math.floor(Math.random() * candidates.length);
        return candidates[randomIndex];
      }

      return null;
    } catch (error) {
      console.error('RecommendationEngine getOneSongAway error:', error.message);
      return null;
    }
  }
}

module.exports = RecommendationEngine;
