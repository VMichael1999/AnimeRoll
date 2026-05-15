import 'package:anime_roll/features/marathon/data/marathon_provider.dart';
import 'package:anime_roll/features/marathon/presentation/marathon_hud.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MarathonHud hides inactive session and renders active session', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MarathonHud(session: MarathonSession.empty())),
      ),
    );
    expect(find.byType(SizedBox), findsWidgets);

    var reset = false;
    final active = MarathonSession.fromJson({
      'watchedMs': const Duration(hours: 3).inMilliseconds,
      'episodeKeys': ['a', 'b', 'c'],
      'recordEpisodeCount': 2,
      'startedAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarathonHud(session: active, onReset: () => reset = true),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(MarathonHud), findsOneWidget);
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    expect(reset, isTrue);
  });
}
