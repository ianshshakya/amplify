const { MusicLibraryImporter, ImporterError } = require('./MusicLibraryImporter');
const SpotifyExportParser = require('./SpotifyExportParser');

class SpotifyFileImporter extends MusicLibraryImporter {
  constructor(directoryPath) {
    super();
    this.parser = new SpotifyExportParser(directoryPath);
    this._playlists = null;
    this._library = null;
    this._history = null;
  }

  async authenticate() {
    return { valid: true, userId: 'local_file_import', displayName: 'Spotify Export' };
  }

  async getPlaylists(cursor = null, limit = 50) {
    if (!this._playlists) {
      this._playlists = await this.parser.findPlaylists();
    }
    
    const startIndex = cursor ? parseInt(cursor, 10) : 0;
    const chunk = this._playlists.slice(startIndex, startIndex + limit);
    const nextCursor = startIndex + limit < this._playlists.length ? String(startIndex + limit) : null;
    
    return { playlists: chunk, nextCursor };
  }

  async getPlaylistTracks(playlistId, cursor = null, limit = 100) {
    if (!this._playlists) {
      this._playlists = await this.parser.findPlaylists();
    }

    const playlist = this._playlists.find(p => p.id === playlistId);
    if (!playlist) throw new ImporterError('NOT_FOUND', 'Playlist not found in export');

    const tracks = playlist._parsedTracks || [];
    const startIndex = cursor ? parseInt(cursor, 10) : 0;
    const chunk = tracks.slice(startIndex, startIndex + limit);
    const nextCursor = startIndex + limit < tracks.length ? String(startIndex + limit) : null;

    return { tracks: chunk, nextCursor };
  }

  async getLibrary(cursor = null, limit = 50) {
    if (!this._library) {
      this._library = await this.parser.findLibrary();
    }

    const startIndex = cursor ? parseInt(cursor, 10) : 0;
    const chunk = this._library.slice(startIndex, startIndex + limit);
    const nextCursor = startIndex + limit < this._library.length ? String(startIndex + limit) : null;

    return { tracks: chunk, nextCursor };
  }

  async getListeningHistory(cursor = null, limit = 500) {
    if (!this._history) {
      this._history = await this.parser.findHistory();
    }

    const startIndex = cursor ? parseInt(cursor, 10) : 0;
    const chunk = this._history.slice(startIndex, startIndex + limit);
    const nextCursor = startIndex + limit < this._history.length ? String(startIndex + limit) : null;

    return { events: chunk, nextCursor };
  }
}

module.exports = SpotifyFileImporter;
