class BuyerOverallSummary {
  final String buyerName;
  final double totalAmount;
  final double totalKilograms;
  final double totalGiven;

  const BuyerOverallSummary({
    required this.buyerName,
    required this.totalAmount,
    required this.totalKilograms,
    required this.totalGiven,
  });

  double get balance => totalAmount - totalGiven;
}
