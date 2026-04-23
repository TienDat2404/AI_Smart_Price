/// Model đại diện cho ngân sách theo hạng mục.
class Budget {
  final String id;
  final String userId;
  final String category;
  final double limit;
  final double spent;

  const Budget({
    required this.id,
    required this.userId,
    required this.category,
    required this.limit,
    required this.spent,
  });

  /// Tỉ lệ đã chi tiêu (0.0 → 1.0).
  double get progress => limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;

  /// Trả về true nếu đã vượt 80% ngân sách → kích hoạt cảnh báo.
  bool get isOverWarningThreshold => progress >= 0.8;

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
        id: json['_id'] as String,
        userId: json['userId'] as String,
        category: json['category'] as String,
        limit: (json['limit'] as num).toDouble(),
        spent: (json['spent'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        '_id': id,
        'userId': userId,
        'category': category,
        'limit': limit,
        'spent': spent,
      };
}
