import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class SpotifyExportGuideScreen extends StatelessWidget {
  const SpotifyExportGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Export Spotify Data'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How to get your Spotify data',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 24),
            _step(
              '1. Go to Spotify Privacy Settings',
              'Open a web browser and go to the Privacy Settings page on your Spotify account.',
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse('https://www.spotify.com/us/account/privacy/'),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Open Spotify Privacy Settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 32),
            _step(
              '2. Request your data',
              'Scroll down to "Download your data". Choose "Account data" (for playlists/library) and "Extended streaming history" (if you want your full listening history imported). Click "Request Data".',
            ),
            const SizedBox(height: 24),
            _step(
              '3. Wait for the email',
              'Spotify will email you a link to download your data. This can take a few days depending on the size of your history.',
            ),
            const SizedBox(height: 24),
            _step(
              '4. Upload the ZIP file',
              'Once you download the ZIP file from Spotify, come back to Amplify and upload the file directly. You don\'t need to extract it.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _step(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
        const SizedBox(height: 8),
        Text(description, style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.8), height: 1.4)),
      ],
    );
  }
}
