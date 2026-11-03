import 'package:flutter_test/flutter_test.dart';
import 'package:daftarkar_man/main.dart';

void main() {
  test('formats monetary values without initializing the database', () {
    expect(money(12345), isNotEmpty);
  });
}
