import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:podcast_history/main.dart';
import 'test_helper.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = TestHttpOverrides();
  });

  testWidgets('VietCast starts at auth and enters listener home', (tester) async {
    await tester.pumpWidget(const VietCastApp());
    expect(find.text('Dang nhap VietCast'), findsOneWidget);
    expect(find.text('Nguoi nghe (listener@vietcast.local)'), findsOneWidget);

    await tester.tap(find.text('Nguoi nghe (listener@vietcast.local)'));
    await tester.pumpAndSettle();

    expect(find.text('Minh Anh'), findsOneWidget);
    expect(find.text('Danh cho ban'), findsOneWidget);
  });

  testWidgets('VietCast enters Creator Studio', (tester) async {
    await tester.pumpWidget(const VietCastApp());
    expect(find.text('Nguoi sang tao (creator@vietcast.local)'), findsOneWidget);

    await tester.tap(find.text('Nguoi sang tao (creator@vietcast.local)'));
    await tester.pumpAndSettle();

    expect(find.text('Creator Studio'), findsOneWidget);
    expect(find.text('Tổng quan tháng này'), findsOneWidget);

    // Verify bottom navigation bar buttons work
    await tester.tap(find.text('Podcast'));
    await tester.pumpAndSettle();
    expect(find.text('Quản lý Podcast'), findsOneWidget);

    await tester.tap(find.text('Đơn đặt'));
    await tester.pumpAndSettle();
    expect(find.text('Đơn đặt Podcast (Custom Request)'), findsOneWidget);

    await tester.tap(find.text('Ví tiền'));
    await tester.pumpAndSettle();
    expect(find.text('Ví & Thu nhập Creator'), findsOneWidget);

    await tester.tap(find.text('Tiện ích'));
    await tester.pumpAndSettle();
    expect(find.text('Công cụ & Cài đặt Studio'), findsOneWidget);

    await tester.tap(find.text('Tổng quan'));
    await tester.pumpAndSettle();
    expect(find.text('Creator Studio'), findsOneWidget);
  });
}
