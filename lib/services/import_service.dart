// lib/services/import_service.dart
// HTTP client layer for all /api/import/* endpoints.

import 'dart:convert';
import 'api_client.dart';

class ImportService {
  final ApiClient _api = ApiClient();

  // ─── Providers ─────────────────────────────────────────────────────────

  Future<List<dynamic>> getProviders() async {
    final res = await _api.get('/import/providers');
    return (res as List<dynamic>?) ?? [];
  }

  // ─── OAuth ─────────────────────────────────────────────────────────────

  /// Returns a map with { authUrl, state } to open in a browser/WebView.
  Future<Map<String, dynamic>> initiateOAuth(String provider) async {
    final res = await _api.get('/import/oauth/$provider');
    return Map<String, dynamic>.from(res as Map);
  }

  // ─── Import Jobs ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> startImport(String provider) async {
    final res = await _api.post('/import/$provider/start');
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, dynamic>> getJobStatus(String jobId) async {
    final res = await _api.get('/import/jobs/$jobId');
    return Map<String, dynamic>.from(res as Map);
  }

  Future<void> cancelJob(String jobId) async {
    await _api.post('/import/jobs/$jobId/cancel');
  }

  // ─── Review ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getReviewTracks(String jobId, {int page = 1}) async {
    final res = await _api.get('/import/jobs/$jobId/review?page=$page');
    return Map<String, dynamic>.from(res as Map);
  }

  Future<void> submitReviews(
    String jobId,
    List<Map<String, String?>> reviews,
  ) async {
    await _api.post('/import/jobs/$jobId/review', body: {'reviews': reviews});
  }

  // ─── Import History ──────────────────────────────────────────────────────

  Future<List<dynamic>> getImportHistory() async {
    final res = await _api.get('/import/history');
    return (res as List<dynamic>?) ?? [];
  }

  // ─── File Import ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> uploadSpotifyExport(String filePath) async {
    final res = await _api.uploadFile('/import/file/spotify/upload', filePath, 'file');
    return Map<String, dynamic>.from(res as Map);
  }

  /// Upload a listening history file (base64-encoded JSON).
  Future<Map<String, dynamic>> uploadHistoryFile(
    String provider,
    List<int> fileBytes,
  ) async {
    final base64Data = base64Encode(fileBytes);
    final res = await _api.post(
      '/import/file/$provider/history',
      body: {'fileContent': base64Data},
    );
    return Map<String, dynamic>.from(res as Map);
  }

  // ─── Connected Services ──────────────────────────────────────────────────

  Future<List<dynamic>> getConnectedServices() async {
    final res = await _api.get('/import/services');
    return (res as List<dynamic>?) ?? [];
  }

  Future<void> disconnectService(String provider) async {
    await _api.delete('/import/services/$provider');
  }
}
