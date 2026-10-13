import 'package:flutter_test/flutter_test.dart';
import 'package:podcast_history/main.dart';

void main() {
  testWidgets('VietCast starts with the API login form', (tester) async {
    await tester.pumpWidget(const VietCastApp());
    expect(find.text('Dang nhap VietCast'), findsOneWidget);
    expect(find.text('Username hoac email'), findsOneWidget);
    expect(find.text('Dang nhap'), findsOneWidget);

    await tester.tap(find.text('Chua co tai khoan?'));
    await tester.pumpAndSettle();

    expect(find.text('Dang ky VietCast'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Ten hien thi'), findsOneWidget);
    expect(find.text('Dang ky'), findsOneWidget);
  });
}
