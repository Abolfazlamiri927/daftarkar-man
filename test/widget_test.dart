import 'package:flutter_test/flutter_test.dart';
import 'package:daftarkar_man/main.dart';

void main() {
  testWidgets('app shows main navigation and title', (tester) async {
    await tester.pumpWidget(const DaftarkarApp());
    expect(find.text('دفترکار من'), findsOneWidget);
  });
}
