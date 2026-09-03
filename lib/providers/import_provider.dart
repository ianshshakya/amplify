// lib/providers/import_provider.dart
// Riverpod providers for the Universal Music Import system.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/import_models.dart';
import '../services/import_service.dart';

final _importService = ImportService();

// ─── Available Providers ────────────────────────────────────────────────────

final importProvidersProvider = FutureProvider<List<ProviderInfo>>((ref) async {
  final raw = await _importService.getProviders();
  return raw
      .whereType<Map<String, dynamic>>()
      .map((m) => ProviderInfo.fromJson(m))
      .toList();
});

// ─── Connected Services ──────────────────────────────────────────────────────

final connectedServicesProvider = StateNotifierProvider<ConnectedServicesNotifier, AsyncValue<List<ConnectedService>>>(
  (ref) => ConnectedServicesNotifier(),
);

class ConnectedServicesNotifier extends StateNotifier<AsyncValue<List<ConnectedService>>> {
  ConnectedServicesNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    try {
      state = const AsyncValue.loading();
      final raw = await _importService.getConnectedServices();
      state = AsyncValue.data(
        raw.whereType<Map<String, dynamic>>()
           .map((m) => ConnectedService.fromJson(m))
           .toList(),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> disconnect(String provider) async {
    await _importService.disconnectService(provider);
    await load();
  }
}

// ─── Active Import Job ────────────────────────────────────────────────────────

final activeImportJobProvider = StateNotifierProvider<ImportJobNotifier, ImportJob?>(
  (ref) => ImportJobNotifier(),
);

class ImportJobNotifier extends StateNotifier<ImportJob?> {
  ImportJobNotifier() : super(null);
  Timer? _pollTimer;

  /// Start a new import for the given provider.
  Future<String?> startImport(String provider) async {
    try {
      final res = await _importService.startImport(provider);
      final jobId = res['importJobId'] as String?;
      if (jobId != null) {
        _beginPolling(jobId);
      }
      return jobId;
    } catch (e) {
      rethrow;
    }
  }

  /// Resume polling for an existing job (e.g., user returns to screen).
  void resumePolling(String jobId) => _beginPolling(jobId);

  void _beginPolling(String jobId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final raw = await _importService.getJobStatus(jobId);
        final job = ImportJob.fromJson(raw);
        state = job;

        if (job.status.isFinished) {
          _pollTimer?.cancel();
          _pollTimer = null;
        }
      } catch (_) {
        // Ignore transient network errors during polling
      }
    });
  }

  Future<void> cancel() async {
    if (state == null) return;
    _pollTimer?.cancel();
    await _importService.cancelJob(state!.id);
    state = null;
  }

  void clear() {
    _pollTimer?.cancel();
    state = null;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

// ─── Import History ───────────────────────────────────────────────────────────

final importHistoryProvider = FutureProvider<List<ImportJob>>((ref) async {
  final raw = await _importService.getImportHistory();
  return raw
      .whereType<Map<String, dynamic>>()
      .map((m) => ImportJob.fromJson(m))
      .toList();
});
