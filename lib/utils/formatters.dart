import 'package:intl/intl.dart';

final NumberFormat currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
final NumberFormat kgFormat = NumberFormat('#,##0.00');

String formatCurrency(double value) => currencyFormat.format(value);

String formatKg(double value) => '${kgFormat.format(value)} kg';

/// Converts an invested-vs-shared pair into a display-friendly status: a positive
/// "Outstanding" figure when the investor is still owed money, or a positive "Profit"
/// figure (not a confusing negative number) once they've been paid more than they invested.
({String label, double amount, bool isProfit}) netStatus(double invested, double shared) {
  final net = invested - shared;
  if (net > 0) return (label: 'Outstanding', amount: net, isProfit: false);
  return (label: 'Profit', amount: -net, isProfit: true);
}
