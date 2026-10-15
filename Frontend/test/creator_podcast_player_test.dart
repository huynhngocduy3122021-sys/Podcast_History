import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podcast_history/features/creator_studio/data/models/creator_models.dart';
import 'package:podcast_history/features/creator_studio/presentation/widgets/creator_podcast_player_sheet.dart';
import 'package:podcast_history/features/creator_studio/presentation/widgets/soundcloud_podcast_card.dart';
import 'test_helper.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = TestHttpOverrides();
  });

  final dummyPodcast = CreatorPodcast(
    id: 'pod_test',
    title: 'Tập 12: Đêm trước Cách mạng Tháng Tám',
    description: 'Không khí sục sôi tại Quảng trường Nhà hát Lớn',
    eraTag: '1858–1945',
    sources: 'Lịch sử Đảng Cộng sản Việt Nam tập 1',
    status: PodcastStatus.published,
    isExclusive: false,
    coverUrl: '',
    audioFileName: 'cach_mang_thang_tam.mp3',
    duration: const Duration(minutes: 32, seconds: 15),
    createdAt: DateTime.now(),
    likesCount: 1850,
    commentsCount: 94,
    listensCount: 14200,
  );

  testWidgets('Tapping play button on SoundCloudPodcastCard expands CreatorPodcastPlayerSheet', (tester) async {
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

    // Verify play button exists and tap it
    final playBtn = find.byIcon(Icons.play_arrow_rounded);
    expect(playBtn, findsOneWidget);
    await tester.tap(playBtn);
    await tester.pumpAndSettle();

    // Verify CreatorPodcastPlayerSheet is now expanded
    expect(find.byType(CreatorPodcastPlayerSheet), findsOneWidget);
    expect(find.text('Đang phát (Studio Preview)'), findsOneWidget);
    expect(find.text('Tập 12: Đêm trước Cách mạng Tháng Tám'), findsWidgets);
    expect(find.byIcon(Icons.replay_10_rounded), findsOneWidget);
    expect(find.byIcon(Icons.forward_10_rounded), findsOneWidget);

    // Tap minimize button to close player sheet
    final closeBtn = find.byTooltip('Thu nhỏ');
    expect(closeBtn, findsOneWidget);
    await tester.tap(closeBtn);
    await tester.pumpAndSettle();

    // Player sheet is closed
    expect(find.byType(CreatorPodcastPlayerSheet), findsNothing);
  });
}
