import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track.dart';
import '../services/offline_service.dart';
import '../providers/download_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/track_tile.dart';
import '../widgets/mini_player.dart';

class DownloadedSongsScreen extends ConsumerStatefulWidget {
  const DownloadedSongsScreen({super.key});

  @override
  ConsumerState<DownloadedSongsScreen> createState() => _DownloadedSongsScreenState();
}

class _DownloadedSongsScreenState extends ConsumerState<DownloadedSongsScreen> {
  List<Track> _downloadedTracks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDownloadedTracks();
  }

  Future<void> _loadDownloadedTracks() async {
    final tracks = await OfflineService().getDownloadedTracks();
    if (!mounted) return;
    setState(() {
      _downloadedTracks = tracks;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Re-load tracks whenever the download state changes (e.g. new downloads complete)
    ref.listen(downloadProvider, (previous, next) {
      _loadDownloadedTracks();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Downloads'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _downloadedTracks.isEmpty
              ? const Center(
                  child: Text(
                    'No downloaded songs yet',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  itemCount: _downloadedTracks.length,
                  itemBuilder: (context, index) {
                    return TrackTile(
                      track: _downloadedTracks[index],
                      context_: _downloadedTracks,
                    );
                  },
                ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}
