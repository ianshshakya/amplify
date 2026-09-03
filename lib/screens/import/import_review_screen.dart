// lib/screens/import/import_review_screen.dart
// Review screen for uncertain track matches.
// Only shows REVIEW_REQUIRED tracks. User can select or skip.

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/import_models.dart';
import '../../services/import_service.dart';

class ImportReviewScreen extends StatefulWidget {
  final String jobId;
  const ImportReviewScreen({super.key, required this.jobId});

  @override
  State<ImportReviewScreen> createState() => _ImportReviewScreenState();
}

class _ImportReviewScreenState extends State<ImportReviewScreen> {
  List<ImportReviewTrack> _tracks = [];
  int _currentIndex = 0;
  bool _loading = true;
  bool _submitting = false;
  String? _selectedVideoId;
  final List<Map<String, String?>> _decisions = [];
  int _page = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks({int page = 1}) async {
    setState(() => _loading = true);
    try {
      final res = await ImportService().getReviewTracks(widget.jobId, page: page);
      final items = (res['tracks'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((m) => ImportReviewTrack.fromJson(m))
          .toList();
      setState(() {
        _tracks = items;
        _page = page;
        _totalPages = (res['pages'] as num?)?.toInt() ?? 1;
        _currentIndex = 0;
        _selectedVideoId = null;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _submitAndAdvance(String? selectedVideoId) async {
    if (_currentIndex >= _tracks.length) return;
    final track = _tracks[_currentIndex];

    _decisions.add({
      'importedTrackId': track.id,
      'selectedVideoId': selectedVideoId,
    });

    // Submit in batches of 10
    if (_decisions.length >= 10) {
      await _flushDecisions();
    }

    if (_currentIndex < _tracks.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedVideoId = null;
      });
    } else if (_page < _totalPages) {
      await _flushDecisions();
      await _loadTracks(page: _page + 1);
    } else {
      await _flushDecisions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('All done! Matches saved.'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _flushDecisions() async {
    if (_decisions.isEmpty) return;
    final batch = List<Map<String, String?>>.from(_decisions);
    _decisions.clear();
    try {
      await ImportService().submitReviews(widget.jobId, batch);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Review Matches', style: TextStyle(color: Colors.white)),
        actions: [
          if (_tracks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_currentIndex + 1} / ${_tracks.length}',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tracks.isEmpty
              ? _emptyState()
              : _reviewCard(_tracks[_currentIndex]),
    );
  }

  Widget _reviewCard(ImportReviewTrack track) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Source track info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceHighlight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IMPORTED FROM ${track.matchStatus}',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(track.title,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text(track.artist,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                if (track.album != null)
                  Text(track.album!,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                if (track.durationMs != null)
                  Text(_formatDuration(track.durationMs!),
                    style: TextStyle(color: AppColors.textDisabled, fontSize: 11)),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'POSSIBLE MATCHES',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          // Candidates
          ...track.reviewCandidates.map((c) => _candidateTile(c)),

          if (track.reviewCandidates.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceHighlight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'No matches found in the Amplify catalog.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),

          const SizedBox(height: 28),

          // Action row
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: BorderSide(color: AppColors.textSecondary.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: () => _submitAndAdvance(null), // Skip
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(0, 48),
                    disabledBackgroundColor: AppColors.surfaceHighlight,
                  ),
                  onPressed: _selectedVideoId != null
                      ? () => _submitAndAdvance(_selectedVideoId)
                      : null,
                  child: Text(
                    _selectedVideoId != null ? 'Confirm Match' : 'Select a match',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _candidateTile(ReviewCandidate candidate) {
    final isSelected = _selectedVideoId == candidate.videoId;

    return GestureDetector(
      onTap: () => setState(() =>
        _selectedVideoId = isSelected ? null : candidate.videoId
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.15) : AppColors.surfaceHighlight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.06),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: candidate.thumbnailUrl != null && candidate.thumbnailUrl!.isNotEmpty
                  ? Image.network(
                      candidate.thumbnailUrl!,
                      width: 44, height: 44, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                    )
                  : _thumbPlaceholder(),
            ),

            const SizedBox(width: 12),

            // Track info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(candidate.title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w600, fontSize: 13,
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  Text(candidate.artist,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  if (candidate.durationMs != null)
                    Text(_formatDuration(candidate.durationMs!),
                      style: TextStyle(color: AppColors.textDisabled, fontSize: 10)),
                ],
              ),
            ),

            // Confidence badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _confidenceColor(candidate.confidenceScore).withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${candidate.confidenceScore}%',
                style: TextStyle(
                  color: _confidenceColor(candidate.confidenceScore),
                  fontSize: 11, fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Selection indicator
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.primary : AppColors.textDisabled,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() => Container(
    width: 44, height: 44,
    color: AppColors.surfaceHighlight,
    child: Icon(Icons.music_note, color: AppColors.textDisabled, size: 20),
  );

  Widget _emptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check_circle_rounded, size: 64, color: AppColors.primary),
        const SizedBox(height: 16),
        const Text('All reviews complete!',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Great — your library is fully matched.',
          style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back to Library'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
        ),
      ],
    ),
  );

  Color _confidenceColor(int score) {
    if (score >= 85) return AppColors.primary;
    if (score >= 60) return AppColors.warning;
    return AppColors.error;
  }

  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
