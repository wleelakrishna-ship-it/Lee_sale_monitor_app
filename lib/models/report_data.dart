class CategoryTotal {
  final String category;
  final double amount;
  final double kilograms;
  final double commission;

  const CategoryTotal({
    required this.category,
    required this.amount,
    required this.kilograms,
    this.commission = 0.0,
  });

  /// What's left after paying the agent's commission for this category.
  double get net => amount - commission;
}

class BuyerTotal {
  final String buyerName;
  final double amount;
  final double kilograms;

  const BuyerTotal({required this.buyerName, required this.amount, required this.kilograms});
}

class DailyTotal {
  final DateTime date;
  final double amount;

  const DailyTotal({required this.date, required this.amount});
}
