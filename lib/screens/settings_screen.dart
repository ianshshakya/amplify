import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
// Assuming authProvider is defined in auth_provider.dart or similar
// We will mock the import based on the guidelines, let's just assume it's in auth_provider.dart
import '../providers/auth_provider.dart';
// Also assume AuthGate is in auth_gate.dart
import 'auth_gate.dart';
import '../providers/voice_provider.dart';
import 'import/bring_your_music_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF181818),
      ),
      backgroundColor: const Color(0xFF121212),
      body: ListView(
        children: [
          // Section 1 - Profile
          ListTile(
            leading: const Icon(Icons.person, color: Colors.white),
            title: Text(authState.user?.name ?? authState.user?.email ?? 'Guest', style: const TextStyle(color: Colors.white)),
          ),
          const Divider(color: Color(0xFF282828)),

          // Section 2 - Appearance
          ListTile(
            title: const Text('Theme', style: TextStyle(color: Colors.white)),
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode)),
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode)),
                ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.settings)),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (Set<ThemeMode> newSelection) {
                ref.read(settingsProvider.notifier).setThemeMode(newSelection.first);
              },
            ),
          ),
          const Divider(color: Color(0xFF282828)),

          // Section 3 - Audio
          ListTile(
            title: const Text('Audio Quality', style: TextStyle(color: Colors.white)),
            trailing: DropdownButton<AudioQuality>(
              value: settings.audioQuality,
              dropdownColor: const Color(0xFF282828),
              style: const TextStyle(color: Colors.white),
              items: const [
                DropdownMenuItem(value: AudioQuality.low, child: Text('Low (128kbps)')),
                DropdownMenuItem(value: AudioQuality.medium, child: Text('Medium (256kbps)')),
                DropdownMenuItem(value: AudioQuality.high, child: Text('High (Best available)')),
              ],
              onChanged: (AudioQuality? quality) {
                if (quality != null) {
                  ref.read(settingsProvider.notifier).setAudioQuality(quality);
                }
              },
            ),
          ),
          const Divider(color: Color(0xFF282828)),
          
          // Section - Voice Assistant
          Consumer(
            builder: (context, ref, child) {
              // Assuming you have imported voice_provider.dart
              // Wait, I should add the import first!
              final voiceState = ref.watch(voiceProvider);
              return SwitchListTile(
                title: const Text('Hands-Free Voice Assistant', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Listen for "Hey Bingo" in background', style: TextStyle(color: Color(0xFFB3B3B3))),
                activeColor: const Color(0xFF1DB954),
                value: voiceState.isHandsFreeEnabled,
                onChanged: (value) {
                  ref.read(voiceProvider.notifier).toggleHandsFree();
                },
              );
            },
          ),

          const Divider(color: Color(0xFF282828)),

          // Section 4 - Storage
          ListTile(
            title: const Text('Cached Downloads', style: TextStyle(color: Colors.white)),
            subtitle: const Text('1.2 GB used', style: TextStyle(color: Color(0xFFB3B3B3))),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE2534C),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF282828),
                    title: const Text('Clear all downloads?', style: TextStyle(color: Colors.white)),
                    content: const Text('This will remove all downloaded songs from your device.', style: TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                      ),
                      TextButton(
                        onPressed: () {
                          // perform clear
                          Navigator.pop(context);
                        },
                        child: const Text('Clear', style: TextStyle(color: Color(0xFFE2534C))),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Clear all downloads', style: TextStyle(color: Colors.white)),
            ),
          ),
          const Divider(color: Color(0xFF282828)),

          // Section: Connected Services / Import
          ListTile(
            leading: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF16A6A1)),
            title: const Text('Bring Your Music', style: TextStyle(color: Colors.white)),
            subtitle: Text(
              'Import from Spotify or YouTube Music',
              style: TextStyle(color: Color(0xFF535353), fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BringYourMusicScreen()),
            ),
          ),
          const Divider(color: Color(0xFF282828)),

          // Section 5 - Account
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFFE2534C)),
            title: const Text('Log out', style: TextStyle(color: Color(0xFFE2534C))),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF282828),
                  title: const Text('Log out?', style: TextStyle(color: Colors.white)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ref.read(authProvider.notifier).logout();
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const AuthGate()),
                          (route) => false,
                        );
                      },
                      child: const Text('Log out', style: TextStyle(color: Color(0xFFE2534C))),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
