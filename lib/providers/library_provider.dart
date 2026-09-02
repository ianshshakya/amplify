import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/album.dart';
import '../models/artist.dart';

class LibraryNotifier extends StateNotifier<LibraryState> {
  LibraryNotifier() : super(const LibraryState()) {
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    final albumsJson = prefs.getStringList('saved_albums') ?? [];
    final artistsJson = prefs.getStringList('saved_artists') ?? [];

    final albums = albumsJson.map((a) {
      final map = jsonDecode(a) as Map<String, dynamic>;
      return Album(
        id: map['id'],
        title: map['title'],
        artistName: map['artistName'],
        year: map['year'],
        thumbnailUrl: map['thumbnailUrl'],
        totalDuration: Duration.zero,
        tracks: [],
      );
    }).toList();

    final artists = artistsJson.map((a) {
      final map = jsonDecode(a) as Map<String, dynamic>;
      return Artist(
        id: map['id'],
        name: map['name'],
        thumbnailUrl: map['thumbnailUrl'],
        subscribers: map['subscribers'],
      );
    }).toList();

    state = state.copyWith(albums: albums, artists: artists);
  }

  Future<void> _saveLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    
    final albumsJson = state.albums.map((a) => jsonEncode({
      'id': a.id,
      'title': a.title,
      'artistName': a.artistName,
      'year': a.year,
      'thumbnailUrl': a.thumbnailUrl,
    })).toList();
    
    final artistsJson = state.artists.map((a) => jsonEncode({
      'id': a.id,
      'name': a.name,
      'thumbnailUrl': a.thumbnailUrl,
      'subscribers': a.subscribers,
    })).toList();

    await prefs.setStringList('saved_albums', albumsJson);
    await prefs.setStringList('saved_artists', artistsJson);
  }

  bool isAlbumSaved(String albumId) => state.albums.any((a) => a.id == albumId);
  bool isArtistSaved(String artistId) => state.artists.any((a) => a.id == artistId);

  void toggleAlbum(Album album) {
    if (isAlbumSaved(album.id)) {
      state = state.copyWith(albums: state.albums.where((a) => a.id != album.id).toList());
    } else {
      state = state.copyWith(albums: [...state.albums, album]);
    }
    _saveLibrary();
  }

  void toggleArtist(Artist artist) {
    if (isArtistSaved(artist.id)) {
      state = state.copyWith(artists: state.artists.where((a) => a.id != artist.id).toList());
    } else {
      state = state.copyWith(artists: [...state.artists, artist]);
    }
    _saveLibrary();
  }
}

class LibraryState {
  final List<Album> albums;
  final List<Artist> artists;

  const LibraryState({
    this.albums = const [],
    this.artists = const [],
  });

  LibraryState copyWith({
    List<Album>? albums,
    List<Artist>? artists,
  }) {
    return LibraryState(
      albums: albums ?? this.albums,
      artists: artists ?? this.artists,
    );
  }
}

final libraryProvider = StateNotifierProvider<LibraryNotifier, LibraryState>((ref) {
  return LibraryNotifier();
});
