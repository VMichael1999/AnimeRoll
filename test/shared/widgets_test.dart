import 'package:anime_roll/shared/models/anime_model.dart';
import 'package:anime_roll/shared/widgets/anime_card.dart';
import 'package:anime_roll/shared/widgets/app_toast.dart';
import 'package:anime_roll/shared/widgets/error_view.dart';
import 'package:anime_roll/shared/widgets/section_header.dart';
import 'package:anime_roll/shared/widgets/wide_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const anime = AnimeModel(
    title: 'Frieren',
    url: 'anime-url',
    cover: 'https://example.com/cover.jpg',
    type: 'TV',
    year: '2023',
    score: 9.1,
  );

  testWidgets('shared display widgets render text and actions', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              ErrorView(message: 'Broken', onRetry: () => tapped++),
              SectionHeader(
                title: 'Popular',
                action: 'More',
                onAction: () => tapped++,
              ),
              AnimeCard(anime: anime, onTap: () => tapped++),
              WideCard(anime: anime, onTap: () => tapped++),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Broken'), findsOneWidget);
    expect(find.text('Popular'), findsOneWidget);
    expect(find.text('Frieren'), findsWidgets);

    await tester.tap(find.text('Reintentar'));
    await tester.tap(find.text('More'));
    await tester.tap(find.text('Frieren').first);
    expect(tapped, greaterThanOrEqualTo(3));
  });

  testWidgets('AppToast shows success, error and info overlays', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () => AppToast.show(
                    context,
                    message: 'Saved',
                    type: AppToastType.success,
                  ),
                  child: const Text('success'),
                ),
                TextButton(
                  onPressed: () => AppToast.show(
                    context,
                    message: 'Failed',
                    type: AppToastType.error,
                  ),
                  child: const Text('error'),
                ),
                TextButton(
                  onPressed: () => AppToast.show(context, message: 'Info'),
                  child: const Text('info'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('success'));
    await tester.pump();
    expect(find.text('Saved'), findsOneWidget);

    await tester.tap(find.text('error'));
    await tester.pump();
    expect(find.text('Failed'), findsOneWidget);

    await tester.tap(find.text('info'));
    await tester.pump();
    expect(find.text('Info'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2500));
    expect(find.text('Info'), findsNothing);
  });
}
