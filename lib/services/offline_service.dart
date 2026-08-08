import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  /// Gets the local path where a song should be saved.
  Future<String> _getLocalPath(String videoId) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$videoId.m4a';
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

  /// Downloads the audio stream in the background.
  Future<void> downloadSong(String videoId, String streamUrl) async {
    try {
      if (await isSongDownloaded(videoId)) {
        return; // Already downloaded
      }

      debugPrint('Downloading song $videoId for offline playback...');
      
      final response = await http.get(Uri.parse(streamUrl));
      if (response.statusCode == 200) {
        final path = await _getLocalPath(videoId);
        final file = File(path);
        await file.writeAsBytes(response.bodyBytes);
        debugPrint('Successfully downloaded song $videoId');
      } else {
        debugPrint('Failed to download song $videoId: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error downloading song $videoId: $e');
    }
  }
}
