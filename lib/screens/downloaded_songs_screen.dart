import 'package:flutter/material.dart';
import '../models/track.dart';
import '../services/offline_service.dart';
import '../theme/app_theme.dart';
import '../widgets/track_tile.dart';

class DownloadedSongsScreen extends StatefulWidget {
  const DownloadedSongsScreen({super.key});

  @override
  State<DownloadedSongsScreen> createState() => _DownloadedSongsScreenState();
}

class _DownloadedSongsScreenState extends State<DownloadedSongsScreen> {
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
    );
  }
}
