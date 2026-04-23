/// Kết quả bóc tách từ AI Engine (NLP / OCR).
class AiParseResult {
  final double amount;
  final String category;
  final String note;
  final double confidence;

  const AiParseResult({
    required this.amount,
    required this.category,
    required this.note,
    required this.confidence,
  });

  factory AiParseResult.fromJson(Map<String, dynamic> json) => AiParseResult(
        amount: (json['amount'] as num).toDouble(),
        category: json['category'] as String,
        note: json['note'] as String? ?? '',
        confidence: (json['confidence'] as num? ?? 1.0).toDouble(),
      );
}

/// Service giao tiếp với Python AI Engine (FastAPI).
/// TODO: Thay [_baseUrl] bằng địa chỉ thực tế khi deploy.
class AiService {
  static const String _baseUrl = 'http://localhost:8000';

  AiService._();
  static final AiService instance = AiService._();

  // ── Keyword maps cho mock NLP ──────────────────────────────────────────

  static const Map<String, String> _categoryKeywords = {
    'phở': 'Ăn uống',
    'cơm': 'Ăn uống',
    'bún': 'Ăn uống',
    'bánh': 'Ăn uống',
    'ăn': 'Ăn uống',
    'cafe': 'Ăn uống',
    'trà': 'Ăn uống',
    'nhậu': 'Ăn uống',
    'lẩu': 'Ăn uống',
    'grab': 'Di chuyển',
    'xe': 'Di chuyển',
    'xăng': 'Di chuyển',
    'bus': 'Di chuyển',
    'taxi': 'Di chuyển',
    'shopee': 'Mua sắm',
    'lazada': 'Mua sắm',
    'quần': 'Mua sắm',
    'áo': 'Mua sắm',
    'mua': 'Mua sắm',
    'phim': 'Giải trí',
    'game': 'Giải trí',
    'netflix': 'Giải trí',
    'spotify': 'Giải trí',
    'thuốc': 'Sức khỏe',
    'bác sĩ': 'Sức khỏe',
    'khám': 'Sức khỏe',
    'gym': 'Sức khỏe',
    'điện': 'Hóa đơn',
    'nước': 'Hóa đơn',
    'internet': 'Hóa đơn',
    'lương': 'Thu nhập',
    'thưởng': 'Thu nhập',
    'freelance': 'Thu nhập',
  };

  // ── Public API ─────────────────────────────────────────────────────────

  /// Gửi câu văn tự nhiên để AI bóc tách Amount, Category, Note.
  /// Ví dụ: "Ăn phở bò 45k" → { amount: 45000, category: "Ăn uống", note: "Phở bò" }
  ///
  /// Hiện tại dùng mock NLP cục bộ. Thay bằng HTTP POST khi backend sẵn sàng.
  Future<AiParseResult> parseText(String input) async {
    // Giả lập độ trễ mạng
    await Future.delayed(const Duration(seconds: 2));

    // TODO: Thay bằng HTTP POST $_baseUrl/parse/text
    return _mockParse(input);
  }

  /// Gửi ảnh hóa đơn (base64) để AI OCR bóc tách dữ liệu.
  Future<AiParseResult> parseImage(String base64Image) async {
    await Future.delayed(const Duration(seconds: 2));
    // TODO: Implement HTTP POST $_baseUrl/parse/image
    throw UnimplementedError('parseImage chưa được implement');
  }

  /// Lấy danh sách log xử lý AI (dành cho Admin Monitor).
  Future<List<Map<String, dynamic>>> getAiLogs() async {
    // TODO: Implement HTTP GET $_baseUrl/logs
    throw UnimplementedError('getAiLogs chưa được implement');
  }

  // ── Mock NLP Engine ────────────────────────────────────────────────────

  /// Bóc tách đơn giản dựa trên từ khóa và regex số tiền.
  AiParseResult _mockParse(String input) {
    final lower = input.toLowerCase().trim();

    // 1. Tìm số tiền — hỗ trợ: "45k", "45.000", "45000", "45 nghìn"
    final amount = _extractAmount(lower);

    // 2. Tìm hạng mục từ từ khóa
    String category = 'Khác';
    for (final entry in _categoryKeywords.entries) {
      if (lower.contains(entry.key)) {
        category = entry.value;
        break;
      }
    }

    // 3. Ghi chú = input gốc bỏ phần số tiền
    final note = _extractNote(input, amount);

    // 4. Confidence: cao nếu tìm được cả amount lẫn category
    final confidence = (amount > 0 && category != 'Khác') ? 0.92 : 0.65;

    return AiParseResult(
      amount: amount,
      category: category,
      note: note,
      confidence: confidence,
    );
  }

  double _extractAmount(String text) {
    // Thứ tự ưu tiên: "45k" / "45K" → 45000, "45.000" → 45000, "45000" → 45000
    final kPattern = RegExp(r'(\d+(?:[.,]\d+)?)\s*k\b', caseSensitive: false);
    final kMatch = kPattern.firstMatch(text);
    if (kMatch != null) {
      final raw = kMatch.group(1)!.replaceAll(',', '.');
      return (double.tryParse(raw) ?? 0) * 1000;
    }

    final nghìnPattern = RegExp(r'(\d+)\s*nghìn');
    final nghìnMatch = nghìnPattern.firstMatch(text);
    if (nghìnMatch != null) {
      return (double.tryParse(nghìnMatch.group(1)!) ?? 0) * 1000;
    }

    final dotPattern = RegExp(r'(\d{1,3}(?:\.\d{3})+)');
    final dotMatch = dotPattern.firstMatch(text);
    if (dotMatch != null) {
      return double.tryParse(dotMatch.group(1)!.replaceAll('.', '')) ?? 0;
    }

    final plainPattern = RegExp(r'\b(\d{4,})\b');
    final plainMatch = plainPattern.firstMatch(text);
    if (plainMatch != null) {
      return double.tryParse(plainMatch.group(1)!) ?? 0;
    }

    return 0;
  }

  String _extractNote(String original, double amount) {
    // Xóa phần số tiền khỏi câu để lấy ghi chú sạch
    var note = original
        .replaceAll(RegExp(r'\d+(?:[.,]\d+)?\s*k\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\d+\s*nghìn'), '')
        .replaceAll(RegExp(r'\d{1,3}(?:\.\d{3})+'), '')
        .replaceAll(RegExp(r'\b\d{4,}\b'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    // Viết hoa chữ đầu
    if (note.isNotEmpty) {
      note = note[0].toUpperCase() + note.substring(1);
    }

    return note.isEmpty ? original : note;
  }
}
