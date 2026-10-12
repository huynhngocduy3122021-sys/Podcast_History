import 'package:flutter_test/flutter_test.dart';
import 'package:podcast_history/main.dart';

void main() {
  testWidgets('VietCast renders the listening home', (tester) async {
    await tester.pumpWidget(const VietCastApp());
    expect(find.text('Minh Anh'), findsOneWidget);
    expect(find.text('Danh cho ban'), findsOneWidget);
  });
}
