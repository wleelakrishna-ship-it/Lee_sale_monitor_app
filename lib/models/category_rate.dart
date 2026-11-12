class CategoryRate {
  final String? id;
  final String date;
  final String category;
  final double ratePerKg;
  final double commissionPerKg;

  const CategoryRate({
    this.id,
    required this.date,
    required this.category,
    required this.ratePerKg,
    this.commissionPerKg = 0.0,
  });

  /// What's left per kg after paying the agent's commission.
  double get netPerKg => ratePerKg - commissionPerKg;

  CategoryRate copyWith({
    String? id,
    String? date,
    String? category,
    double? ratePerKg,
    double? commissionPerKg,
  }) {
    return CategoryRate(
      id: id ?? this.id,
      date: date ?? this.date,
      category: category ?? this.category,
      ratePerKg: ratePerKg ?? this.ratePerKg,
      commissionPerKg: commissionPerKg ?? this.commissionPerKg,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'date': date,
      'category': category,
      'rate_per_kg': ratePerKg,
      'commission_per_kg': commissionPerKg,
    };
  }

  factory CategoryRate.fromMap(String id, Map<String, Object?> map) {
    return CategoryRate(
      id: id,
      date: map['date'] as String,
      category: map['category'] as String,
      ratePerKg: (map['rate_per_kg'] as num).toDouble(),
      commissionPerKg: (map['commission_per_kg'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
