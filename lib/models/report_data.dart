class CategoryTotal {
  final String category;
  final double amount;
  final double kilograms;

  const CategoryTotal({required this.category, required this.amount, required this.kilograms});
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
