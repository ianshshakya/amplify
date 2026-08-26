require('dotenv').config();
const mongoose = require('mongoose');
const DynamicPlaylist = require('./src/models/DynamicPlaylist');
const MusicProvider = require('./src/services/MusicProvider');
const CURATED_PLAYLISTS = require('./src/config/playlists');

/**
 * Seeds all curated playlists into MongoDB using the unified MusicProvider.
 *
 * Strategies:
 *   'playlist'  → fetch from JioSaavn playlist by saavnPlaylistId
 *   'artist'    → search JioSaavn for artist tracks (sorted by play count)
 *   'spotify'   → cross-reference Spotify playlist (spotifyUrl can be array)
 *   'multi'     → run multiple searchQueries and merge results
 */

function normalizeTitle(title) {
  if (!title) return '';
  return title.toLowerCase()
    .replace(/\(.*?\)/g, '')
    .replace(/\[.*?\]/g, '')
    .replace(/\s*-\s*(remix|version|cover|edit|official|audio|video|live).*/i, '')
    .replace(/[^a-z0-9\s]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function deduplicateByTitle(songs) {
  const seen = new Set();
  return songs.filter(s => {
    const key = `${normalizeTitle(s.title || '')}::${(s.primaryArtist || s.artist || '').toLowerCase().split(',')[0].trim()}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

async function fetchSongs(playlist) {
  const limit = 120;

  try {
    switch (playlist.strategy) {
      case 'spotify': {
        const urls = Array.isArray(playlist.spotifyUrl) ? playlist.spotifyUrl : [playlist.spotifyUrl];
        const tracks = await MusicProvider.getSpotifyPlaylist(urls, 100, playlist.saavnPlaylistId);
        return tracks;
      }

      case 'playlist': {
        const tracks = await MusicProvider.getPlaylist(playlist.saavnPlaylistId, limit);
        return tracks;
      }

      case 'artist': {
        const tracks = await MusicProvider.search(playlist.searchQuery, limit);
        return deduplicateByTitle(tracks);
      }

      case 'multi': {
        const queries = playlist.searchQueries || (playlist.searchQuery ? [playlist.searchQuery] : []);
        if (queries.length === 0) return [];
        const limitPerQuery = Math.ceil(limit / queries.length);
        const tracks = await MusicProvider.multiSearch(queries, limitPerQuery);
        return deduplicateByTitle(tracks);
      }

      default:
        console.warn(`Unknown strategy: ${playlist.strategy}. Skipping.`);
        return [];
    }
  } catch (err) {
    console.error(`Fetch failed for ${playlist.title}: ${err.message}`);
    return [];
  }
}

async function seed() {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log('MongoDB connected.');
    console.log(`Seeding ${CURATED_PLAYLISTS.length} playlists...`);

    for (const playlist of CURATED_PLAYLISTS) {
      console.log(`\nFetching: ${playlist.title} (${playlist.id}) [${playlist.strategy}]`);

      let songs = await fetchSongs(playlist);

      if (!songs || songs.length === 0) {
        console.warn(`  ⚠️  No songs found for ${playlist.title}. Skipping.`);
        continue;
      }

      const formattedSongs = songs.map(s => ({
        videoId: s.videoId,
        title: s.title,
        artist: s.artist,
        thumbnailUrl: s.thumbnailUrl,
        durationMs: s.durationMs || (s.duration ? s.duration * 1000 : 0),
        source: s.source || 'saavn',
        language: s.language || undefined,
        releaseYear: s.releaseYear || undefined,
        album: s.album || undefined,
        playCount: s.playCount || 0,
        popularityScore: s.popularityScore || 0,
        mainstreamsScore: s.mainstreamsScore || 0,
        isRemix: s.isRemix || false,
      }));

      const firstThumb = formattedSongs[0]?.thumbnailUrl || playlist.thumbnailUrl;

      await DynamicPlaylist.findOneAndUpdate(
        { playlistId: playlist.id },
        {
          title: playlist.title,
          description: playlist.description,
          thumbnailUrl: firstThumb,
          songs: formattedSongs,
          updatedAt: new Date(),
        },
        { upsert: true, new: true }
      );

      console.log(`  ✅ Saved ${formattedSongs.length} tracks for '${playlist.title}'`);
    }

    console.log('\n🎉 All playlists seeded successfully!');
  } catch (error) {
    console.error('Seeding error:', error);
  } finally {
    await mongoose.disconnect();
    console.log('MongoDB disconnected. Exiting.');
    process.exit(0);
  }
}

seed();
