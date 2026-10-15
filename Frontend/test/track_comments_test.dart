import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';
import 'package:podcast_history/features/creator_studio/presentation/widgets/soundcloud_podcast_card.dart';
import 'package:podcast_history/features/creator_studio/presentation/widgets/track_comments_sheet.dart';
import 'test_helper.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = TestHttpOverrides();
  });

  final dummyPodcast = CreatorPodcast(
    id: 'pod_test',
    title: 'Bản thảo: Phong trào Cần Vương',
    description: 'Mô tả thử nghiệm',
    eraTag: '1858–1945',
    sources: 'Sử quán Triều Nguyễn',
    status: PodcastStatus.published,
    isExclusive: false,
    coverUrl: '',
    audioFileName: 'test.mp3',
    duration: const Duration(minutes: 18, seconds: 20),
    createdAt: DateTime.now(),
    likesCount: 15,
    commentsCount: 3,
    listensCount: 120,
  );

  testWidgets('Tapping comment button on SoundCloudPodcastCard opens TrackCommentsSheet', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SoundCloudPodcastCard(
                podcast: dummyPodcast,
                creatorName: 'Sử Kể Đêm Khuya',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify comment icon exists
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);

    // Tap comment button
    await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
    await tester.pumpAndSettle();

    // Verify TrackCommentsSheet is now displayed
    expect(find.byType(TrackCommentsSheet), findsOneWidget);
    expect(find.text('Bình luận & Mốc thời gian'), findsOneWidget);
    expect(find.text('Bản thảo: Phong trào Cần Vương'), findsWidgets);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Tapping a waveform comment pin opens TrackCommentsSheet with highlight', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SoundCloudPodcastCard(
                podcast: dummyPodcast,
                creatorName: 'Sử Kể Đêm Khuya',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Find the pin tooltip
    final pinFinder = find.byTooltip('Hoàng Long: Đoạn này xúc động quá!');
    expect(pinFinder, findsOneWidget);

    // Tap the pin
    await tester.tap(pinFinder);
    await tester.pumpAndSettle();

    // Verify TrackCommentsSheet opened
    expect(find.byType(TrackCommentsSheet), findsOneWidget);
  });
}
