/// Model đại diện cho một giao dịch tài chính.
class Transaction {
  final String id;
  final String userId;
  final double amount;
  final String category;
  final String note;
  final DateTime date;
  final bool isExpense;

  const Transaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.category,
    required this.note,
    required this.date,
    this.isExpense = true,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['_id'] as String,
        userId: json['userId'] as String,
        amount: (json['amount'] as num).toDouble(),
        category: json['category'] as String,
        note: json['note'] as String? ?? '',
        date: DateTime.parse(json['date'] as String),
        isExpense: json['isExpense'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        '_id': id,
        'userId': userId,
        'amount': amount,
        'category': category,
        'note': note,
        'date': date.toIso8601String(),
        'isExpense': isExpense,
      };
}
