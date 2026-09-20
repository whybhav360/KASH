import 'package:flutter_test/flutter_test.dart';
import 'package:test_money/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter.format', () {
    test('does not add decimals for integer amounts', () {
      expect(CurrencyFormatter.format(0), '₹0');
      expect(CurrencyFormatter.format(500), '₹500');
      expect(CurrencyFormatter.format(1000), '₹1,000');
      expect(CurrencyFormatter.format(100000), '₹1,00,000');
    });

    test('adds decimals only when fractional part is present', () {
      expect(CurrencyFormatter.format(500.5), '₹500.50');
      expect(CurrencyFormatter.format(500.25), '₹500.25');
      expect(CurrencyFormatter.format(1250.75), '₹1,250.75');
    });

    test('supports custom symbol', () {
      expect(CurrencyFormatter.format(500, symbol: '₹ '), '₹ 500');
      expect(CurrencyFormatter.format(500.5, symbol: '₹ '), '₹ 500.50');
      expect(CurrencyFormatter.format(500, symbol: ''), '500');
    });
  });

  group('CurrencyFormatter.formatInput', () {
    test('returns empty string for 0', () {
      expect(CurrencyFormatter.formatInput(0), '');
      expect(CurrencyFormatter.formatInput(0.0), '');
    });

    test('returns integer string without decimal point when whole number', () {
      expect(CurrencyFormatter.formatInput(500.0), '500');
      expect(CurrencyFormatter.formatInput(1500.0), '1500');
    });

    test('preserves decimals when user provided them', () {
      expect(CurrencyFormatter.formatInput(500.5), '500.5');
      expect(CurrencyFormatter.formatInput(500.25), '500.25');
    });
  });
}
