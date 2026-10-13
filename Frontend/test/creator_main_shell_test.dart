import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podcast_history/features/creator_studio/presentation/views/creator_main_shell.dart';
import 'package:podcast_history/core/theme/app_theme.dart';

class TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _TestHttpClient();
}

class _TestHttpClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getUrl || invocation.memberName == #openUrl) {
      return Future.value(_TestHttpClientRequest());
    }
    return null;
  }
}

class _TestHttpClientRequest implements HttpClientRequest {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #close) {
      return Future.value(_TestHttpClientResponse());
    }
    return null;
  }
}

class _TestHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  static final Uint8List _imageBytes = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  @override
  int get statusCode => 200;

  @override
  int get contentLength => _imageBytes.length;

  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return Stream<List<int>>.value(_imageBytes).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  setUpAll(() {
    HttpOverrides.global = TestHttpOverrides();
  });

  testWidgets('CreatorMainShell renders all tabs and navigates correctly', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const CreatorMainShell(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Dashboard renders
    expect(find.text('Creator Studio'), findsOneWidget);
    expect(find.text('Tổng quan tháng này'), findsOneWidget);

    // Tap Podcast tab
    await tester.tap(find.text('Podcast'));
    await tester.pumpAndSettle();
    expect(find.text('Quản lý Podcast'), findsOneWidget);

    // Tap Đơn đặt tab
    await tester.tap(find.text('Đơn đặt'));
    await tester.pumpAndSettle();
    expect(find.text('Đơn đặt Podcast (Custom Request)'), findsOneWidget);

    // Tap Ví tiền tab
    await tester.tap(find.text('Ví tiền'));
    await tester.pumpAndSettle();
    expect(find.text('Ví & Thu nhập Creator'), findsOneWidget);

    // Tap Tiện ích tab
    await tester.tap(find.text('Tiện ích'));
    await tester.pumpAndSettle();
    expect(find.text('Công cụ & Cài đặt Studio'), findsOneWidget);

    // Tap back to Tổng quan
    await tester.tap(find.text('Tổng quan'));
    await tester.pumpAndSettle();
    expect(find.text('Creator Studio'), findsOneWidget);
  });
}
