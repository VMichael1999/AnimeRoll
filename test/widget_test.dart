import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anime_roll/app.dart';
import 'package:anime_roll/features/home/data/home_provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          popularAnimeProvider.overrideWith((ref) async => []),
          latestAnimeProvider.overrideWith((ref) async => []),
        ],
        child: const App(),
      ),
    );
    expect(find.byType(ProviderScope), findsOneWidget);
  });
}
