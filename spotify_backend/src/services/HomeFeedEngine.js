/**
 * HomeFeedEngine builds browse recommendations.  It deliberately does not
 * participate in autoplay: both systems share taste signals but have separate
 * sequencing and refresh lifecycles.
 */
const UserMusicProfile = require('../models/UserMusicProfile');
const ListeningEvent = require('../models/ListeningEvent');
const SongStatistic = require('../models/SongStatistic');
const DynamicPlaylist = require('../models/DynamicPlaylist');
const RecommendationEngine = require('./RecommendationEngine');
const CURATED_PLAYLISTS = require('../config/playlists');
const { SimpleCache } = require('../utils/cache');

const TTL_MS = 15 * 60 * 1000;
const homeFeedCache = new SimpleCache(15 * 60);
const mapObject = value => value instanceof Map ? Object.fromEntries(value) : (value || {});
const topEntries = (map, count = 3) => Object.entries(mapObject(map)).sort((a, b) => b[1] - a[1]).slice(0, count);
const primaryArtist = song => String(song?.artist || '').split(',')[0].trim();
const idOf = song => song?.videoId || song?.songId;

class HomeSectionCandidateGenerator {
  static async generate(userId, profile, session = {}) {
    const recentEvents = userId ? await ListeningEvent.find({ userId }).sort({ createdAt: -1 }).limit(80).lean() : [];
    const recentSongs = uniqueSongs(recentEvents.map(e => e.song).filter(Boolean), 12);
    const artists = topEntries(profile?.artistAffinity, 3).map(([name]) => name.replace(/_/g, ' '));
    const languages = topEntries(profile?.languageAffinity, 2).map(([name]) => name);
    const hasTaste = artists.length > 0 || languages.length > 0;
    const candidates = [
      { type: 'QUICK_PICKS', title: 'Quick Picks', score: 100, items: this.quickPicks(artists), reason: 'Your essentials, all in one place.' },
      { type: 'TRENDING', title: 'Trending now', score: hasTaste ? 36 : 80, loader: () => this.trending(profile), reason: 'Popular with Amplify listeners right now.' },
      { type: 'MADE_FOR_YOU', title: 'Made for you', score: hasTaste ? 85 : 0, loader: () => this.madeForYou(userId), reason: 'Built from your listening history.' },
      { type: 'CONTINUE_LISTENING', title: 'Continue listening', score: recentSongs.length >= 2 ? 88 : 0, items: tracks(recentSongs), reason: 'Based on what you played recently.' },
      { type: 'RECENT_ROTATION', title: 'Your recent rotation', score: recentSongs.length >= 4 ? 64 : 0, items: tracks(recentSongs.slice(0, 8)), reason: 'Songs returning to your rotation.' },
      { type: 'BECAUSE_YOU_LISTEN', title: artists[0] ? `Because you listen to ${artists[0]}` : 'Because you listen', score: artists[0] ? 78 : 0, loader: () => this.artistMix(artists[0]), reason: artists[0] ? `Inspired by your affinity for ${artists[0]}.` : '' },
      { type: 'AMPLIFY_RECOMMENDS', title: 'Amplify recommends', score: hasTaste ? 70 : 28, loader: () => this.recommends(userId), reason: hasTaste ? 'Picked for your taste and recent listening.' : 'A great place to start.' },
      { type: 'DISCOVER_SOMETHING_NEW', title: 'Discover something new', score: hasTaste ? 58 + (profile.discoveryPreference || 0) * 15 : 45, loader: () => this.discovery(userId), reason: 'A little outside your usual rotation.' },
      { type: 'NEW_RELEASES_FOR_YOU', title: 'New releases for you', score: hasTaste ? 52 : 38, items: this.newReleasePlaylists(languages), reason: hasTaste ? 'Fresh picks aligned with your taste.' : 'Fresh releases worth hearing.' },
      { type: 'MOOD_CONTEXT', title: this.contextTitle(profile, session), score: hasTaste ? 48 : 22, items: this.contextPlaylists(languages, profile, session), reason: 'A soft match for your current listening context.' },
    ];
    return candidates;
  }

  static quickPicks(artists) {
    const fixed = [
      { id: 'liked-songs', type: 'COLLECTION', title: 'Liked Songs', subtitle: 'Your library', imageUrl: 'https://misc.scdn.co/liked-songs/liked-songs-640.png' },
      { id: 'global100', type: 'PLAYLIST', title: 'Global 100', subtitle: 'Top charts', imageUrl: '' },
    ];
    if (artists[0]) fixed.push({ id: 'daily-mix', type: 'MIX', title: 'Your Daily Mix', subtitle: `Featuring ${artists[0]}`, imageUrl: '' });
    return [...fixed, ...CURATED_PLAYLISTS.slice(0, 3).map(playlistItem)];
  }
  static async trending(profile) {
    const stats = await SongStatistic.find().sort({ trendScore: -1, popularityScore: -1 }).limit(30).lean();
    return rankTracks(stats.map(s => s.song).filter(Boolean), profile).slice(0, 12).map(trackItem);
  }
  static async madeForYou(userId) {
    const songs = await RecommendationEngine.getDailyMix(userId);
    if (!songs.length) return [];
    return [
      { id: 'daily-mix', type: 'MIX', title: 'Your Daily Mix', subtitle: 'A daily blend from your taste', imageUrl: songs[0]?.thumbnailUrl || '', metadata: { playlistId: 'daily-mix' } },
      ...tracks(songs.slice(0, 8)),
    ];
  }
  static async artistMix(artist) {
    const songs = artist ? await RecommendationEngine.getArtistRadio(artist, null, 14) : [];
    return tracks(songs);
  }
  static async recommends(userId) { return tracks((await RecommendationEngine.getDailyMix(userId)).slice(0, 12)); }
  static async discovery(userId) {
    const result = await DynamicPlaylist.find({ 'songs.0': { $exists: true } }).sort({ updatedAt: -1 }).limit(3).lean();
    const seen = new Set();
    return tracks(result.flatMap(p => p.songs || []).filter(song => !seen.has(idOf(song)) && seen.add(idOf(song))).slice(0, 12));
  }
  static newReleasePlaylists(languages) {
    const matching = CURATED_PLAYLISTS.filter(p => /new|release|top/i.test(`${p.id} ${p.title}`) && (!languages.length || languages.some(l => (p.intent?.languages || []).includes(l))));
    return (matching.length ? matching : CURATED_PLAYLISTS.slice(0, 5)).slice(0, 8).map(playlistItem);
  }
  static contextTitle(profile, session) {
    const hour = new Date().getHours();
    const energy = session.energy || topEntries(profile?.energyAffinity, 1)[0]?.[0];
    if (energy === 'high') return 'High energy picks';
    if (hour < 6) return 'Late night listening';
    if (hour < 12) return 'Morning focus';
    return 'For your moment';
  }
  static contextPlaylists(languages, profile, session) {
    const mood = session.mood || topEntries(profile?.moodAffinity, 1)[0]?.[0];
    const items = CURATED_PLAYLISTS.filter(p => !mood || `${p.title} ${p.id}`.toLowerCase().includes(mood.toLowerCase()));
    return (items.length ? items : CURATED_PLAYLISTS).filter(p => !languages.length || !(p.intent?.languages?.length) || languages.some(l => p.intent.languages.includes(l))).slice(0, 8).map(playlistItem);
  }
}

class SectionRanker {
  static select(candidates, maxSections = 7) {
    const usedTypes = new Set();
    return candidates.filter(c => c.score > 0).sort((a, b) => b.score - a.score).filter(c => {
      if (usedTypes.has(c.type)) return false;
      usedTypes.add(c.type); return true;
    }).slice(0, maxSections);
  }
}

class HomeFeedEngine {
  static async getFeed(userId, session = {}, forceRefresh = false) {
    const cacheKey = `home-feed:${userId || 'anonymous'}:${new Date().getHours()}`;
    if (forceRefresh) homeFeedCache.delete(cacheKey);
    const cached = homeFeedCache.get(cacheKey);
    if (cached) return cached;
    const profile = userId ? await UserMusicProfile.findOne({ userId }).lean() : null;
    const candidates = await HomeSectionCandidateGenerator.generate(userId, profile, session);
    const sections = [];
    const usedTracks = new Set();
    const usedArtists = new Map();
    for (const candidate of SectionRanker.select(candidates)) {
      const rawItems = candidate.items || await candidate.loader?.() || [];
      const items = diversityFilter(rawItems, usedTracks, usedArtists);
      if (items.length) sections.push({ id: candidate.type.toLowerCase(), type: candidate.type, title: candidate.title, subtitle: candidate.reason, reason: candidate.reason, priority: candidate.score, items });
    }
    const now = new Date();
    const feed = { greeting: greeting(now), generatedAt: now.toISOString(), expiresAt: new Date(now.getTime() + TTL_MS).toISOString(), sections };
    homeFeedCache.set(cacheKey, feed);
    return feed;
  }
}

function greeting(now) { const hour = now.getHours(); return hour < 5 ? 'Good night' : hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening'; }
function uniqueSongs(songs, limit) { const ids = new Set(); return songs.filter(s => idOf(s) && !ids.has(idOf(s)) && ids.add(idOf(s))).slice(0, limit); }
function trackItem(song) { return { id: idOf(song), type: 'SONG', title: song.title || 'Unknown', subtitle: song.artist || 'Unknown artist', imageUrl: song.thumbnailUrl || '', track: song }; }
function tracks(songs) { return (songs || []).filter(Boolean).map(trackItem); }
function playlistItem(p) { return { id: p.id, type: 'PLAYLIST', title: p.title, subtitle: p.description || p.type || '', imageUrl: p.thumbnailUrl || '', metadata: { playlistId: p.id } }; }
function rankTracks(songs, profile) { const affinity = mapObject(profile?.artistAffinity); return [...songs].sort((a, b) => (affinity[primaryArtist(b)] || 0) - (affinity[primaryArtist(a)] || 0)); }
function diversityFilter(items, usedTracks, usedArtists) {
  return items.filter(item => {
    if (item.type !== 'SONG') return true;
    if (!item.id || usedTracks.has(item.id)) return false;
    const artist = primaryArtist(item.track || { artist: item.subtitle });
    if ((usedArtists.get(artist) || 0) >= 2) return false;
    usedTracks.add(item.id); usedArtists.set(artist, (usedArtists.get(artist) || 0) + 1); return true;
  });
}

module.exports = { HomeFeedEngine, HomeSectionCandidateGenerator, SectionRanker, diversityFilter };
