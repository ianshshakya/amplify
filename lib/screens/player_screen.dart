import 'dart:async';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palette_generator/palette_generator.dart';

import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/download_provider.dart';
import '../providers/voice_provider.dart';
import '../models/voice_command.dart';
import '../theme/app_theme.dart';
import 'queue_screen.dart';
import 'lyrics_screen.dart';
import 'search_screen.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  Color _backgroundColor = AppColors.background;
  bool _colorExtracted = false;
  String? _lastVideoId;

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final track = ref.watch(playerProvider).currentTrack;
    if (track != null && track.videoId != _lastVideoId) {
      _lastVideoId = track.videoId;
      _colorExtracted = false;
      _extractPalette(track.thumbnailUrl);
    }

    // Handle navigation commands from voice (e.g. "open search")
    final voiceState = ref.watch(voiceProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (voiceState.lastCommand != null) {
        _handleNavigationCommand(voiceState.lastCommand!.intent);
      }
    });
  }

  void _handleNavigationCommand(VoiceIntent intent) {
    switch (intent) {
      case VoiceIntent.openSearch:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen()));
        ref.read(voiceProvider.notifier).reset();
      case VoiceIntent.openLikedSongs:
      case VoiceIntent.openPlaylists:
        Navigator.of(context).pop(); // go back to root shell where library is
        ref.read(voiceProvider.notifier).reset();
      default:
        break;
    }
  }

  Future<void> _extractPalette(String url) async {
    if (_colorExtracted || url.isEmpty) return;
    try {
      final provider = CachedNetworkImageProvider(url);
      final palette = await PaletteGenerator.fromImageProvider(provider);
      if (palette.dominantColor != null && mounted) {
        setState(() {
          _backgroundColor = palette.dominantColor!.color;
          _colorExtracted = true;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final playlistState = ref.watch(playlistProvider);
    final track = playerState.currentTrack;

    if (track == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('Nothing playing', style: TextStyle(color: Colors.white))),
      );
    }

    final isLiked = playlistState.isLiked(track);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _backgroundColor.withOpacity(0.8),
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // ─── Header ───────────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down, size: 32, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Text(
                      'NOW PLAYING',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.queue_music, color: Colors.white),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const QueueScreen()),
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // ─── Album Art (Hero tag matches MiniPlayer) ───────────────────
                Hero(
                  tag: 'mini-player-art-${track.videoId}',
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: CachedNetworkImage(
                          imageUrl: track.thumbnailUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // ─── Info Row (Title, Artist, Like, Download) ─────────────────
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                          if (playerState.status == PlaybackStatus.error)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                playerState.errorMessage ?? 'Error loading track',
                                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? AppColors.heart : Colors.white,
                        size: 26,
                      ),
                      onPressed: () => ref.read(playlistProvider.notifier).toggleLiked(track),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download, color: Colors.white),
                      onPressed: () {
                        ref.read(downloadProvider.notifier).download(track);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Starting download for ${track.title}...')),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ─── Progress Bar ─────────────────────────────────────────────
                StreamBuilder<Duration>(
                  stream: ref.read(playerProvider.notifier).positionStream,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final total = playerState.duration;
                    final maxMs = total.inMilliseconds > 0 ? total.inMilliseconds.toDouble() : 1.0;
                    final valueMs = position.inMilliseconds.toDouble().clamp(0.0, maxMs);

                    return Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                            activeTrackColor: AppColors.primary,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            min: 0,
                            max: maxMs,
                            value: valueMs,
                            onChanged: (value) {
                              ref.read(playerProvider.notifier).seek(Duration(milliseconds: value.toInt()));
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatDuration(position),
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              Text(_formatDuration(total),
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 12),

                // ─── Main Playback Controls ───────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.shuffle,
                        color: playerState.shuffleEnabled ? AppColors.primary : Colors.white54,
                        size: 26,
                      ),
                      onPressed: () => ref.read(playerProvider.notifier).toggleShuffle(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_previous, size: 44, color: Colors.white),
                      onPressed: () => ref.read(playerProvider.notifier).playPrevious(),
                    ),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: IconButton(
                        iconSize: 42,
                        color: Colors.black,
                        icon: playerState.status == PlaybackStatus.loading
                            ? const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                              )
                            : playerState.status == PlaybackStatus.error
                                ? const Icon(Icons.error_outline, color: Colors.red)
                                : Icon(playerState.status == PlaybackStatus.playing ? Icons.pause : Icons.play_arrow),
                        onPressed: playerState.status == PlaybackStatus.error 
                            ? () => ref.read(playerProvider.notifier).playTrack(track) // Retry 
                            : () => ref.read(playerProvider.notifier).togglePlayPause(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next, size: 44, color: Colors.white),
                      onPressed: () => ref.read(playerProvider.notifier).playNext(),
                    ),
                    IconButton(
                      icon: Icon(
                        playerState.repeatMode == RepeatMode.one
                            ? Icons.repeat_one
                            : Icons.repeat,
                        color: playerState.repeatMode == RepeatMode.off
                            ? Colors.white54
                            : AppColors.primary,
                        size: 26,
                      ),
                      onPressed: () => ref.read(playerProvider.notifier).cycleRepeatMode(),
                    ),
                  ],
                ),

                const Spacer(),

                // ─── Voice Control ────────────────────────────────────────────
                _VoiceControlBar(),

                const SizedBox(height: 12),

                // ─── Lyrics Drag Up Panel Indicator ──────────────────────────
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => LyricsScreen(track: track)),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lyrics, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Lyrics',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Spacer(),
                        Icon(Icons.keyboard_arrow_up, color: Colors.white54),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Polished voice control bar that shows mic state + feedback to the user.
class _VoiceControlBar extends ConsumerStatefulWidget {
  @override
  ConsumerState<_VoiceControlBar> createState() => _VoiceControlBarState();
}

class _VoiceControlBarState extends ConsumerState<_VoiceControlBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceProvider);
    final notifier = ref.read(voiceProvider.notifier);
    final isListening = voiceState.feedback == VoiceFeedback.listening;
    final isProcessing = voiceState.feedback == VoiceFeedback.processing;

    // Auto-reset after success/error
    if (voiceState.feedback == VoiceFeedback.success ||
        voiceState.feedback == VoiceFeedback.error) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) notifier.reset();
      });
    }

    return GestureDetector(
      onTapDown: (_) => notifier.startListening(),
      onTapUp: (_) => notifier.stopListening(),
      onTapCancel: () => notifier.stopListening(),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
        decoration: BoxDecoration(
          color: isListening
              ? const Color(0xFF1DB954).withOpacity(0.15)
              : Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isListening
                ? const Color(0xFF1DB954)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Mic icon — pulses when listening
            if (isListening)
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (_, __) => Transform.scale(
                  scale: _pulseAnimation.value,
                  child: const Icon(Icons.mic, color: Color(0xFF1DB954), size: 20),
                ),
              )
            else if (isProcessing)
              const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF1DB954),
                ),
              )
            else if (voiceState.feedback == VoiceFeedback.success)
              const Icon(Icons.check_circle_outline, color: Color(0xFF1DB954), size: 20)
            else if (voiceState.feedback == VoiceFeedback.error)
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 20)
            else
              const Icon(Icons.mic_none, color: Colors.white70, size: 20),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isListening
                        ? 'Listening…'
                        : isProcessing
                            ? 'Processing…'
                            : voiceState.feedback == VoiceFeedback.success
                                ? voiceState.feedbackMessage
                                : voiceState.feedback == VoiceFeedback.error
                                    ? voiceState.feedbackMessage
                                    : 'Hold to speak',
                    style: TextStyle(
                      color: voiceState.feedback == VoiceFeedback.error
                          ? Colors.redAccent
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  if (voiceState.recognizedText.isNotEmpty && isListening)
                    Text(
                      '"${voiceState.recognizedText}"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
