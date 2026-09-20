import 'package:intl/intl.dart';

class CurrencyFormatter {
  /// Formats an amount with a currency symbol (defaults to '₹').
  /// If the amount has no fractional part (e.g., 500.0), no decimals are added (e.g., '₹500').
  /// If the amount has a fractional part (e.g., 500.5), 2 decimals are shown (e.g., '₹500.50').
  static String format(double amount, {String symbol = '₹'}) {
    final decimalDigits = (amount.abs() % 1 == 0) ? 0 : 2;
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: symbol,
      decimalDigits: decimalDigits,
    );
    return formatter.format(amount);
  }

  /// Formats an amount for input fields (TextFormField, TextField).
  /// If amount is 0, returns empty string ''.
  /// If amount is an integer (e.g. 500.0), returns '500'.
  /// If amount has a fractional part (e.g. 500.5), returns '500.5' or exact representation without forced decimal.
  static String formatInput(double amount) {
    if (amount == 0) return '';
    if (amount.abs() % 1 == 0) {
      return amount.toInt().toString();
    }
    return amount.toString();
  }
}
