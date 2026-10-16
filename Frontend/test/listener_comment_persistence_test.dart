import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:podcast_history/api_service.dart';
import 'package:podcast_history/main.dart';

http.Response jsonResponse(String body, int status) => http.Response(
  body,
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  const saved = <String, dynamic>{
    'commentId': 'saved-in-database',
    'displayName': 'Listener',
    'content': 'Đoạn phút 18',
    'timestampSeconds': 1080,
  };

  test(
    'POST sends podcast ID, access token and position; GET restores position',
    () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/podcasts/podcast-id/comments');
        expect(request.headers['Authorization'], 'Bearer access');
        if (request.method == 'POST') {
          expect(jsonDecode(request.body), {
            'content': 'Đoạn phút 18',
            'timestampSeconds': 1080,
          });
          return jsonResponse(jsonEncode(saved), 201);
        }
        return jsonResponse(
          jsonEncode({
            'content': [saved],
          }),
          200,
        );
      });
      addTearDown(client.close);
      final api = ListenerApi(accessToken: 'access', client: client);
      final created = await api.createComment(
        'podcast-id',
        'Đoạn phút 18',
        timestampSeconds: 1080,
      );
      expect(created['commentId'], 'saved-in-database');
      final loaded = CommentData.fromJson(
        (await api.comments('podcast-id')).single,
        durationSeconds: 1200,
      );
      expect(loaded.time, '18:00');
      expect(loaded.position, .9);
    },
  );

  test('expired access token refreshes once for concurrent requests', () async {
    var refreshCalls = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/api/auth/refresh') {
        refreshCalls++;
        expect(jsonDecode(request.body)['refreshToken'], 'refresh-old');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return jsonResponse(
          jsonEncode({
            'accessToken': 'new-access',
            'refreshToken': 'refresh-new',
            'user': {'id': 'listener', 'role': 'LISTENER'},
          }),
          200,
        );
      }
      if (request.headers['Authorization'] == 'Bearer expired') {
        return jsonResponse('{}', 401);
      }
      expect(request.headers['Authorization'], 'Bearer new-access');
      return jsonResponse(
        jsonEncode({
          'content': [saved],
        }),
        200,
      );
    });
    addTearDown(client.close);
    final api = ListenerApi(
      accessToken: 'expired',
      refreshToken: 'refresh-old',
      client: client,
    );
    await Future.wait([api.comments('one'), api.comments('two')]);
    expect(refreshCalls, 1);
    expect(api.refreshToken, 'refresh-new');
  });

  test(
    'API failure throws instead of returning a fake saved comment',
    () async {
      final client = MockClient(
        (_) async =>
            jsonResponse(jsonEncode({'message': 'Không được lưu'}), 400),
      );
      addTearDown(client.close);
      final api = ListenerApi(accessToken: 'access', client: client);
      await expectLater(
        api.createComment('podcast', 'test'),
        throwsA(isA<ApiException>()),
      );
    },
  );

  Widget player({Future<CommentData> Function(String, int)? send}) =>
      MaterialApp(
        home: Scaffold(
          body: Player(
            show: const Show(
              'Podcast thật',
              'Kênh',
              '',
              '20:00',
              [Colors.red, Colors.black],
              id: 'podcast-id',
              durationSeconds: 1200,
            ),
            displayName: 'Listener',
            playing: false,
            initialProgress: .9,
            initialLiked: false,
            initialSaved: false,
            initialComments: const [],
            onComment: send,
            onProgressChanged: (_) {},
            onLikedChanged: (_) {},
            onSavedChanged: (_) {},
            onReport: () {},
            onMembership: () {},
            onCreatorProfile: () {},
            onToggle: () {},
          ),
        ),
      );

  Future<void> prepare(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(widget);
    await tester.enterText(find.byType(TextField).first, 'Đoạn phút 18');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
  }

  testWidgets('player waits for server ID and uses actual video duration', (
    tester,
  ) async {
    final pending = Completer<CommentData>();
    var calls = 0;
    await prepare(
      tester,
      player(
        send: (text, seconds) {
          calls++;
          expect(text, 'Đoạn phút 18');
          expect(seconds, 1080);
          return pending.future;
        },
      ),
    );
    expect(find.byType(Comment), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'Đoạn phút 18',
    );
    expect(calls, 1);
    pending.complete(CommentData.fromJson(saved, durationSeconds: 1200));
    await tester.pumpAndSettle();
    expect(find.byType(Comment), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      isEmpty,
    );
  });

  testWidgets('failed save preserves draft and does not add local comment', (
    tester,
  ) async {
    await prepare(
      tester,
      player(send: (_, _) async => throw const ApiException('Lỗi DB', 500)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Comment), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'Đoạn phút 18',
    );
    expect(find.textContaining('Chưa lưu được bình luận'), findsOneWidget);
  });

  testWidgets('missing persistence callback does not pretend to save', (
    tester,
  ) async {
    await prepare(tester, player());
    await tester.pumpAndSettle();
    expect(find.byType(Comment), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'Đoạn phút 18',
    );
    expect(find.textContaining('Podcast mẫu chưa có ID'), findsOneWidget);
  });
}
