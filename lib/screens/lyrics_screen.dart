import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palette_generator/palette_generator.dart';

import '../providers/home_provider.dart';
import '../providers/player_provider.dart';
import '../models/track.dart';
import '../models/lyrics.dart';

class LyricsScreen extends ConsumerStatefulWidget {
  final Track track;
  const LyricsScreen({super.key, required this.track});

  @override
  ConsumerState<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends ConsumerState<LyricsScreen> {
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<Duration>? _positionSubscription;
  Duration _currentPosition = Duration.zero;
  Color _dominantColor = const Color(0xFF121212);

  @override
  void initState() {
    super.initState();
    _extractColor();
    _positionSubscription = ref.read(playerProvider.notifier).positionStream.listen((pos) {
      setState(() {
        _currentPosition = pos;
      });
      // Optionally implement auto-scroll here using scrollController
    });
  }

  Future<void> _extractColor() async {
    final imageProvider = CachedNetworkImageProvider(widget.track.thumbnailUrl);
    final palette = await PaletteGenerator.fromImageProvider(imageProvider);
    if (palette.dominantColor != null && mounted) {
      setState(() {
        _dominantColor = palette.dominantColor!.color;
      });
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lyricsAsync = ref.watch(lyricsProvider(widget.track.videoId));
    ref.watch(playerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lyrics'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          )
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _dominantColor,
              const Color(0xFF121212),
            ],
          ),
        ),
        child: lyricsAsync.when(
          data: (lyrics) {
            if (lyrics == null) {
              return const Center(child: Text('Lyrics unavailable', style: TextStyle(color: Colors.white)));
            }

            if (lyrics.hasSynced && lyrics.syncedLines != null) {
              return ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + kToolbarHeight + 32,
                  bottom: 100,
                  left: 24,
                  right: 24,
                ),
                itemCount: lyrics.syncedLines!.length,
                itemBuilder: (context, index) {
                  final line = lyrics.syncedLines![index];
                  final isActive = line.startTimeMs <= _currentPosition.inMilliseconds &&
                      (index == lyrics.syncedLines!.length - 1 ||
                          lyrics.syncedLines![index + 1].startTimeMs > _currentPosition.inMilliseconds);
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      line.text,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        color: isActive ? Colors.white : Colors.white54,
                      ),
                    ),
                  );
                },
              );
            } else if (lyrics.plainText != null) {
              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + kToolbarHeight + 32,
                  bottom: 100,
                  left: 24,
                  right: 24,
                ),
                child: Text(
                  lyrics.plainText!,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
              );
            } else {
              return const Center(child: Text('Lyrics unavailable', style: TextStyle(color: Colors.white)));
            }
          },
          loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF1DB954))),
          error: (error, stack) => const Center(child: Text('Could not load lyrics', style: TextStyle(color: Colors.white))),
        ),
      ),
    );
  }
}
