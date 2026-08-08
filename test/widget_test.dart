// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:spotify_clone/main.dart';
import 'package:spotify_clone/providers/playlist_provider.dart';

void main() {
  testWidgets('app builds without crashing', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Hive.initFlutter();

    final playlistProvider = PlaylistProvider();
    await playlistProvider.init();

    await tester.pumpWidget(SpotifyCloneApp(playlistProvider: playlistProvider));

    expect(find.text('Home'), findsOneWidget);
  });
}
