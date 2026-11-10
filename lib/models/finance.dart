class Investor {
  final String? id;
  final String name;
  final double amount;
  final String date;
  final String? note;
  final String createdAt;

  const Investor({
    this.id,
    required this.name,
    required this.amount,
    required this.date,
    this.note,
    required this.createdAt,
  });

  Map<String, Object?> toMap() {
    return {
      'name': name,
      'amount': amount,
      'date': date,
      'note': note,
      'created_at': createdAt,
    };
  }

  factory Investor.fromMap(String id, Map<String, Object?> map) {
    return Investor(
      id: id,
      name: map['name'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: map['date'] as String,
      note: map['note'] as String?,
      createdAt: map['created_at'] as String,
    );
  }
}

class Expense {
  final String? id;
  final String description;
  final double amount;
  final String date;
  final String createdAt;

  const Expense({
    this.id,
    required this.description,
    required this.amount,
    required this.date,
    required this.createdAt,
  });

  Map<String, Object?> toMap() {
    return {
      'description': description,
      'amount': amount,
      'date': date,
      'created_at': createdAt,
    };
  }

  factory Expense.fromMap(String id, Map<String, Object?> map) {
    return Expense(
      id: id,
      description: map['description'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: map['date'] as String,
      createdAt: map['created_at'] as String,
    );
  }
}

class ProfitShare {
  final String? id;
  final String investorName;
  final double amount;
  final String date;
  final String? note;
  final String createdAt;

  const ProfitShare({
    this.id,
    required this.investorName,
    required this.amount,
    required this.date,
    this.note,
    required this.createdAt,
  });

  Map<String, Object?> toMap() {
    return {
      'investor_name': investorName,
      'amount': amount,
      'date': date,
      'note': note,
      'created_at': createdAt,
    };
  }

  factory ProfitShare.fromMap(String id, Map<String, Object?> map) {
    return ProfitShare(
      id: id,
      investorName: map['investor_name'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: map['date'] as String,
      note: map['note'] as String?,
      createdAt: map['created_at'] as String,
    );
  }
}

class InvestorTotal {
  final String name;
  final double invested;
  final double shared;
  final double net;

  const InvestorTotal({
    required this.name,
    required this.invested,
    required this.shared,
    required this.net,
  });
}
