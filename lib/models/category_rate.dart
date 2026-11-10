class CategoryRate {
  final String? id;
  final String date;
  final String category;
  final double ratePerKg;

  const CategoryRate({
    this.id,
    required this.date,
    required this.category,
    required this.ratePerKg,
  });

  CategoryRate copyWith({String? id, String? date, String? category, double? ratePerKg}) {
    return CategoryRate(
      id: id ?? this.id,
      date: date ?? this.date,
      category: category ?? this.category,
      ratePerKg: ratePerKg ?? this.ratePerKg,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'date': date,
      'category': category,
      'rate_per_kg': ratePerKg,
    };
  }

  factory CategoryRate.fromMap(String id, Map<String, Object?> map) {
    return CategoryRate(
      id: id,
      date: map['date'] as String,
      category: map['category'] as String,
      ratePerKg: (map['rate_per_kg'] as num).toDouble(),
    );
  }
}
