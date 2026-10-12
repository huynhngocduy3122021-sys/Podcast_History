import 'package:flutter_test/flutter_test.dart';
import 'package:podcast_history/main.dart';

void main() {
  testWidgets('VietCast starts at auth and enters listener home', (tester) async {
    await tester.pumpWidget(const VietCastApp());
    expect(find.text('Dang nhap VietCast'), findsOneWidget);
    expect(find.text('Nguoi nghe (listener@vietcast.local)'), findsOneWidget);

    await tester.tap(find.text('Nguoi nghe (listener@vietcast.local)'));
    await tester.pumpAndSettle();

    expect(find.text('Minh Anh'), findsOneWidget);
    expect(find.text('Danh cho ban'), findsOneWidget);
  });
}
