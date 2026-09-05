const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

class SpotifyExportParser {
  constructor(directoryPath) {
    this.directoryPath = directoryPath;
    this.files = [];
    this._scanDirectory(this.directoryPath);
  }

  _scanDirectory(dir) {
    const items = fs.readdirSync(dir);
    for (const item of items) {
      const fullPath = path.join(dir, item);
      const stat = fs.statSync(fullPath);
      if (stat.isDirectory()) {
        this._scanDirectory(fullPath);
      } else if (fullPath.toLowerCase().endsWith('.json')) {
        this.files.push(fullPath);
      }
    }
  }

  async findPlaylists() {
    const playlists = [];
    for (const file of this.files) {
      try {
        const content = fs.readFileSync(file, 'utf8');
        const data = JSON.parse(content);

        if (data && Array.isArray(data.playlists)) {
          for (const pl of data.playlists) {
            if (!pl.name) continue;
            
            // Extract tracks
            const tracks = [];
            if (Array.isArray(pl.items)) {
              for (const item of pl.items) {
                const trackNode = item.track || item;
                const trackName = trackNode.trackName || trackNode.track;
                if (!trackName) continue;
                
                tracks.push({
                  sourceTrackId: trackNode.trackUri || `spotify_export_${crypto.randomUUID()}`,
                  title: trackName,
                  artist: trackNode.artistName || trackNode.artist || 'Unknown',
                  album: trackNode.albumName || trackNode.album,
                  isrc: trackNode.isrc,
                  addedAt: item.addedDate,
                });
              }
            }

            playlists.push({
              id: `spotify_export_pl_${crypto.randomUUID()}`,
              name: pl.name,
              description: pl.description || '',
              totalTracks: tracks.length,
              isPublic: false,
              _parsedTracks: tracks, // Keep tracks here temporarily
            });
          }
        }
      } catch (err) {
        console.error(`[SpotifyExportParser] Error parsing playlist file ${file}:`, err.message);
      }
    }
    return playlists;
  }

  async findLibrary() {
    const libraryTracks = [];
    for (const file of this.files) {
      try {
        const content = fs.readFileSync(file, 'utf8');
        const data = JSON.parse(content);
        
        // Match structure: { "tracks": [ { "track": "...", "artist": "..." } ] }
        if (data && Array.isArray(data.tracks)) {
          for (const item of data.tracks) {
            const title = item.track || item.trackName;
            if (!title) continue;
            libraryTracks.push({
              sourceTrackId: item.uri || item.trackUri || `spotify_export_${crypto.randomUUID()}`,
              title,
              artist: item.artist || item.artistName || 'Unknown',
              album: item.album || item.albumName,
            });
          }
        }
      } catch (err) {}
    }
    return libraryTracks;
  }

  async findHistory() {
    const historyEvents = [];
    for (const file of this.files) {
      if (!file.toLowerCase().includes('streaming') && !file.toLowerCase().includes('history')) continue;
      
      try {
        const content = fs.readFileSync(file, 'utf8');
        const data = JSON.parse(content);
        
        if (Array.isArray(data)) {
          for (const item of data) {
            const title = item.master_metadata_track_name || item.trackName;
            const artist = item.master_metadata_album_artist_name || item.artistName;
            
            if (!title || !artist) continue;

            const ts = item.ts || item.endTime;
            if (!ts) continue;

            historyEvents.push({
              playedAt: new Date(ts),
              title,
              artist,
              album: item.master_metadata_album_album_name,
              msPlayed: item.ms_played || item.msPlayed || 0,
              sourceTrackId: item.spotify_track_uri,
            });
          }
        }
      } catch (err) {}
    }
    
    // Sort chronological
    historyEvents.sort((a, b) => a.playedAt - b.playedAt);
    return historyEvents;
  }
}

module.exports = SpotifyExportParser;
