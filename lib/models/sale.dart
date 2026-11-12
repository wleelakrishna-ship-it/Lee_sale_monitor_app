class Sale {
  final String? id;
  final String date;
  final String buyerName;
  final String category;
  final double ratePerKg;
  final double kilograms;
  final double amount;
  final String createdAt;
  final double commissionPerKg;

  const Sale({
    this.id,
    required this.date,
    required this.buyerName,
    required this.category,
    required this.ratePerKg,
    required this.kilograms,
    required this.amount,
    required this.createdAt,
    this.commissionPerKg = 0.0,
  });

  /// Total owed to the agent for this sale.
  double get commissionAmount => commissionPerKg * kilograms;

  /// What's left after paying the agent's commission.
  double get netAmount => amount - commissionAmount;

  Map<String, Object?> toMap() {
    return {
      'date': date,
      'buyer_name': buyerName,
      'category': category,
      'rate_per_kg': ratePerKg,
      'kilograms': kilograms,
      'amount': amount,
      'created_at': createdAt,
      'commission_per_kg': commissionPerKg,
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
      commissionPerKg: (map['commission_per_kg'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
