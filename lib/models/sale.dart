class Sale {
  final String? id;
  final String date;
  final String buyerName;
  final String category;
  final double ratePerKg;
  final double kilograms;
  final double amount;
  final String createdAt;

  const Sale({
    this.id,
    required this.date,
    required this.buyerName,
    required this.category,
    required this.ratePerKg,
    required this.kilograms,
    required this.amount,
    required this.createdAt,
  });

  Map<String, Object?> toMap() {
    return {
      'date': date,
      'buyer_name': buyerName,
      'category': category,
      'rate_per_kg': ratePerKg,
      'kilograms': kilograms,
      'amount': amount,
      'created_at': createdAt,
    };
  }

  factory Sale.fromMap(String id, Map<String, Object?> map) {
    return Sale(
      id: id,
      date: map['date'] as String,
      buyerName: map['buyer_name'] as String,
      category: map['category'] as String,
      ratePerKg: (map['rate_per_kg'] as num).toDouble(),
      kilograms: (map['kilograms'] as num).toDouble(),
      amount: (map['amount'] as num).toDouble(),
      createdAt: map['created_at'] as String,
    );
  }
}
