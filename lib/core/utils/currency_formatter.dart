import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: '\$',
    decimalDigits: 2,
  );

  static final NumberFormat _compactCurrencyFormat = NumberFormat.compactCurrency(
    symbol: '\$',
    decimalDigits: 0,
  );

  /// Formats cents (integer) into standard dollar string (e.g. 4500000 -> "$45,000.00")
  static String formatCents(int cents) {
    return _currencyFormat.format(cents / 100.0);
  }

  /// Formats double dollars into standard dollar string
  static String formatDollars(double dollars) {
    return _currencyFormat.format(dollars);
  }

  /// Formats compact dollar string (e.g. 118500 -> "$119K")
  static String formatCompactDollars(double dollars) {
    return _compactCurrencyFormat.format(dollars);
  }
}
