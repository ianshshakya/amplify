import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../models/track.dart';

class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  /// Gets the local path where a song audio file should be saved.
  Future<String> _getLocalPath(String videoId) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$videoId.m4a';
  }

  /// Gets the local path where a song metadata file should be saved.
  Future<String> _getMetadataPath(String videoId) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$videoId.json';
  }

  /// Checks if a song is already downloaded to local storage.
  Future<bool> isSongDownloaded(String videoId) async {
    final path = await _getLocalPath(videoId);
    final file = File(path);
    return await file.exists();
  }

  /// Gets the file URI for a downloaded song.
  Future<Uri?> getLocalUri(String videoId) async {
    if (await isSongDownloaded(videoId)) {
      final path = await _getLocalPath(videoId);
      return Uri.file(path);
    }
    return null;
  }

  /// Downloads the audio stream in the background and saves its metadata.
  Future<void> downloadSong(Track track, String streamUrl) async {
    try {
      if (await isSongDownloaded(track.videoId)) {
        return; // Already downloaded
      }

      debugPrint('Downloading song ${track.videoId} for offline playback...');
      
      final response = await http.get(Uri.parse(streamUrl));
      if (response.statusCode == 200) {
        // Save audio
        final path = await _getLocalPath(track.videoId);
        final file = File(path);
        await file.writeAsBytes(response.bodyBytes);
        
        // Save metadata
        final metaPath = await _getMetadataPath(track.videoId);
        final metaFile = File(metaPath);
        final metaJson = jsonEncode(track.toJson());
        await metaFile.writeAsString(metaJson);

        debugPrint('Successfully downloaded song ${track.videoId} with metadata');
      } else {
        debugPrint('Failed to download song ${track.videoId}: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error downloading song ${track.videoId}: $e');
    }
  }

  /// Returns a list of all downloaded tracks.
  Future<List<Track>> getDownloadedTracks() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final entities = dir.listSync();
      
      final List<Track> tracks = [];
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final jsonStr = await entity.readAsString();
            final map = jsonDecode(jsonStr);
            tracks.add(Track.fromJson(map));
          } catch (e) {
            debugPrint('Failed to parse metadata ${entity.path}: $e');
          }
        }
      }
      return tracks;
    } catch (e) {
      debugPrint('Error getting downloaded tracks: $e');
      return [];
    }
  }
}
