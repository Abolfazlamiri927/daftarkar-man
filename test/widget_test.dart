import 'package:flutter_test/flutter_test.dart';
import 'package:daftarkar_man/main.dart';

void main() {
  test('formats monetary values without initializing the database', () {
    expect(money(12345), isNotEmpty);
  });

  test('parses Persian and Arabic numerals as integer amounts', () {
    expect(parseAmount('۱۲۳۴۵'), 12345);
    expect(parseAmount('١٢٣٤٥'), 12345);
    expect(parseAmount('12,345'), 12345);
  });

  test('rejects invalid amount input', () {
    expect(parseAmount('متن'), isNull);
  });
}
