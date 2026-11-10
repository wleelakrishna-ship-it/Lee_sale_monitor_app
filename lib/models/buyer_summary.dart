class BuyerSummary {
  final String buyerName;
  final double total;
  final double given;
  final double totalKilograms;

  const BuyerSummary({
    required this.buyerName,
    required this.total,
    required this.given,
    required this.totalKilograms,
  });

  double get balance => total - given;
}
