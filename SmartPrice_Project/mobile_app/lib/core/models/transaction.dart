/// Model đại diện cho một giao dịch tài chính.
/// Tên field khớp với JSON trả về từ ASP.NET Core (PascalCase).
class Transaction {
  final String id;
  final String userId;
  final String itemName; // tên món/dịch vụ
  final double amount;
  final String category;
  final String note;
  final DateTime date;
  final bool isExpense;

  const Transaction({
    required this.id,
    required this.userId,
    required this.itemName,
    required this.amount,
    required this.category,
    required this.note,
    required this.date,
    this.isExpense = true,
  });

  /// Parse JSON từ ASP.NET Core API.
  /// Backend trả về PascalCase: Id, UserId, ItemName, Amount, Date, Category...
  factory Transaction.fromJson(Map<String, dynamic> json) {
    // Hỗ trợ cả _id (MongoDB raw) và Id (ASP.NET serialized)
    final id = (json['Id'] ?? json['_id'] ?? '') as String;

    // Amount có thể là int, double, hoặc string (Decimal128 từ MongoDB)
    final rawAmount = json['Amount'] ?? json['amount'] ?? 0;
    final amount = rawAmount is String
        ? double.tryParse(rawAmount) ?? 0.0
        : (rawAmount as num).toDouble();

    // Date có thể là ISO string hoặc MongoDB date object
    final rawDate = json['Date'] ?? json['date'];
    final date = rawDate is String
        ? DateTime.tryParse(rawDate) ?? DateTime.now()
        : DateTime.now();

    return Transaction(
      id: id,
      userId: (json['UserId'] ?? json['userId'] ?? '') as String,
      itemName: (json['ItemName'] ?? json['itemName'] ?? '') as String,
      amount: amount,
      category: (json['Category'] ?? json['category'] ?? '') as String,
      note: (json['Note'] ?? json['note'] ?? '') as String,
      date: date,
      isExpense: (json['IsExpense'] ?? json['isExpense'] ?? true) as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'UserId': userId,
        'ItemName': itemName,
        'Amount': amount,
        'Category': category,
        'Note': note,
        'Date': date.toIso8601String(),
        'IsExpense': isExpense,
      };

  /// Tính số dư: thu nhập dương, chi tiêu âm
  double get signedAmount => isExpense ? -amount : amount;
}
