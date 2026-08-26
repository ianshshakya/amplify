import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track.dart';
import '../services/music_service.dart';
import '../services/offline_service.dart';

enum DownloadStatus { idle, downloading, done, error }

@immutable
class DownloadEntry {
  final DownloadStatus status;
  final double progress; // 0.0 – 1.0

  const DownloadEntry({
    this.status = DownloadStatus.idle,
    this.progress = 0,
  });
}

@immutable
class DownloadState {
  final Map<String, DownloadEntry> entries; // videoId → DownloadEntry

  const DownloadState({this.entries = const {}});

  DownloadStatus statusFor(String videoId) =>
      entries[videoId]?.status ?? DownloadStatus.idle;

  double progressFor(String videoId) => entries[videoId]?.progress ?? 0;

  bool isDownloaded(String videoId) => statusFor(videoId) == DownloadStatus.done;

  DownloadState copyWith({Map<String, DownloadEntry>? entries}) =>
      DownloadState(entries: entries ?? this.entries);
}

class DownloadNotifier extends StateNotifier<DownloadState> {
  final OfflineService _offline = OfflineService();
  final MusicService _music = MusicService();

  DownloadNotifier() : super(const DownloadState()) {
    _checkExisting();
  }

  Future<void> _checkExisting() async {
    final downloaded = await _offline.getDownloadedTracks();
    final entries = <String, DownloadEntry>{};
    for (final t in downloaded) {
      entries[t.videoId] = const DownloadEntry(status: DownloadStatus.done, progress: 1);
    }
    state = DownloadState(entries: entries);
  }

  /// Download a single track. Updates progress in state.
  Future<void> download(Track track) async {
    if (state.isDownloaded(track.videoId)) return;

    _setEntry(track.videoId, DownloadStatus.downloading, 0.1);

    try {
      final url = await _music.getAudioStreamUrl(track.videoId);
      _setEntry(track.videoId, DownloadStatus.downloading, 0.3);
      await _offline.downloadSong(track, url);
      _setEntry(track.videoId, DownloadStatus.done, 1.0);
    } catch (e) {
      debugPrint('Download failed for ${track.videoId}: $e');
      _setEntry(track.videoId, DownloadStatus.error, 0);
    }
  }

  /// Removes a downloaded track.
  Future<void> removeDownload(String videoId) async {
    await _offline.deleteSong(videoId);
    final entries = Map<String, DownloadEntry>.from(state.entries);
    entries.remove(videoId);
    state = state.copyWith(entries: entries);
  }

  void _setEntry(String videoId, DownloadStatus status, double progress) {
    state = state.copyWith(
      entries: {
        ...state.entries,
        videoId: DownloadEntry(status: status, progress: progress),
      },
    );
  }
}

final downloadProvider = StateNotifierProvider<DownloadNotifier, DownloadState>(
  (ref) => DownloadNotifier(),
);
