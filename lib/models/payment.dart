class Payment {
  final String? id;
  final String date;
  final String buyerName;
  final double amountGiven;
  final String createdAt;

  const Payment({
    this.id,
    required this.date,
    required this.buyerName,
    required this.amountGiven,
    required this.createdAt,
  });

  Map<String, Object?> toMap() {
    return {
      'date': date,
      'buyer_name': buyerName,
      'amount_given': amountGiven,
      'created_at': createdAt,
    };
  }

  factory Payment.fromMap(String id, Map<String, Object?> map) {
    return Payment(
      id: id,
      date: map['date'] as String,
      buyerName: map['buyer_name'] as String,
      amountGiven: (map['amount_given'] as num).toDouble(),
      createdAt: map['created_at'] as String,
    );
  }
}
