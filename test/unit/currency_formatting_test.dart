import 'package:flutter_test/flutter_test.dart';
import 'package:danaya_plus/core/utils/date_formatter.dart';

void main() {
  group('DateFormatter currency tests', () {
    test('Should format with FCFA by default', () {
      final result = DateFormatter.formatCurrency(1500, 'FCFA');
      expect(result, contains('1'));
      expect(result, contains('500'));

      expect(result, contains('FCFA'));
    });

    test('Should format with custom symbol \$', () {
      final result = DateFormatter.formatCurrency(1500, r'$');
      expect(result, contains('1'));
      expect(result, contains('500'));

      expect(result, contains(r'$'));
    });

    test('Should format with custom symbol €', () {
      final result = DateFormatter.formatCurrency(1500.25, '€');
      expect(result, contains('1'));
      expect(result, contains('500'));

      expect(result, contains('€'));
    });

    test('Should remove decimals when requested', () {
      final result = DateFormatter.formatCurrency(1500.75, 'FCFA', removeDecimals: true);
      expect(result, isNot(contains('.75')));
      expect(result, isNot(contains(',75')));
    });
  });
}
