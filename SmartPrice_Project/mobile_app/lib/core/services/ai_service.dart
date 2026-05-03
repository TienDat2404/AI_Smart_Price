import 'package:flutter/foundation.dart';

// ── Models ────────────────────────────────────────────────────────────────────

/// Một giao dịch được bóc tách từ câu văn tự nhiên.
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
        amount:     (json['amount']     as num).toDouble(),
        category:   json['category']   as String,
        note:       json['note']       as String? ?? '',
        confidence: (json['confidence'] as num? ?? 1.0).toDouble(),
      );

  @override
  String toString() => 'AiParseResult(amount: $amount, category: $category, note: $note)';
}

/// Kết quả parse có thể chứa NHIỀU giao dịch (câu ghép).
/// Ví dụ: "đi chơi 40k và ăn 50k" → 2 items.
class AiParseResponse {
  final List<AiParseResult> items;

  const AiParseResponse({required this.items});

  /// Tiện lợi: lấy item đầu tiên (backward compat)
  AiParseResult get first => items.first;

  bool get isMultiple => items.length > 1;
}

// ── Service ───────────────────────────────────────────────────────────────────

/// Service giao tiếp với Python AI Engine (FastAPI).
/// Hiện tại dùng mock NLP cục bộ. Thay bằng HTTP POST khi backend sẵn sàng.
class AiService {
  static const String _baseUrl = 'http://localhost:8000';

  AiService._();
  static final AiService instance = AiService._();

  // ── Keyword maps ──────────────────────────────────────────────────────────

  static const Map<String, String> _categoryKeywords = {
    'phở':      'Ăn uống',
    'cơm':      'Ăn uống',
    'bún':      'Ăn uống',
    'bánh':     'Ăn uống',
    'ăn':       'Ăn uống',
    'cafe':     'Ăn uống',
    'trà':      'Ăn uống',
    'nhậu':     'Ăn uống',
    'lẩu':      'Ăn uống',
    'chơi':     'Giải trí',
    'grab':     'Di chuyển',
    'xe':       'Di chuyển',
    'xăng':     'Di chuyển',
    'bus':      'Di chuyển',
    'taxi':     'Di chuyển',
    'shopee':   'Mua sắm',
    'lazada':   'Mua sắm',
    'quần':     'Mua sắm',
    'áo':       'Mua sắm',
    'mua':      'Mua sắm',
    'phim':     'Giải trí',
    'game':     'Giải trí',
    'netflix':  'Giải trí',
    'spotify':  'Giải trí',
    'thuốc':    'Sức khỏe',
    'bác sĩ':   'Sức khỏe',
    'khám':     'Sức khỏe',
    'gym':      'Sức khỏe',
    'điện':     'Hóa đơn',
    'nước':     'Hóa đơn',
    'internet': 'Hóa đơn',
    'lương':    'Thu nhập',
    'thưởng':   'Thu nhập',
    'freelance':'Thu nhập',
  };

  // ── Separators nhận biết câu ghép ─────────────────────────────────────────
  // "và", "với", ",", ";", "còn", "thêm", "plus"
  static final _separatorPattern = RegExp(
    r'\s+(?:và|với|còn|thêm|plus)\s+|[,;]\s*',
    caseSensitive: false,
  );

  // ── Public API ────────────────────────────────────────────────────────────

  /// Parse câu văn tự nhiên → có thể trả về nhiều giao dịch.
  Future<AiParseResponse> parseText(String input) async {
    await Future.delayed(const Duration(seconds: 1));
    // TODO: Thay bằng HTTP POST $_baseUrl/parse/text
    return _mockParseMultiple(input);
  }

  // ── Mock NLP Engine ───────────────────────────────────────────────────────

  /// Tách câu ghép thành các đoạn con, parse từng đoạn.
  AiParseResponse _mockParseMultiple(String input) {
    // Tách câu theo separator
    final segments = input.split(_separatorPattern)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    debugPrint('[AiService] Input: "$input"');
    debugPrint('[AiService] Segments: $segments');

    final results = <AiParseResult>[];

    for (final segment in segments) {
      final result = _parseSingleSegment(segment);
      // Chỉ thêm nếu tìm được số tiền hợp lệ
      if (result.amount > 0) {
        results.add(result);
        debugPrint('[AiService] Parsed: $result');
      }
    }

    // Nếu không parse được gì → trả về 1 kết quả từ toàn bộ input
    if (results.isEmpty) {
      results.add(_parseSingleSegment(input));
    }

    return AiParseResponse(items: results);
  }

  AiParseResult _parseSingleSegment(String segment) {
    final lower = segment.toLowerCase().trim();

    // 1. Tìm TẤT CẢ số tiền trong đoạn — lấy số lớn nhất (hoặc đầu tiên)
    final amount = _extractAmount(lower);

    // 2. Tìm hạng mục
    String category = 'Khác';
    for (final entry in _categoryKeywords.entries) {
      if (lower.contains(entry.key)) {
        category = entry.value;
        break;
      }
    }

    // 3. Ghi chú = đoạn gốc bỏ phần số tiền
    final note = _extractNote(segment, amount);

    // 4. Confidence
    final confidence = (amount > 0 && category != 'Khác') ? 0.92 : 0.65;

    return AiParseResult(
      amount:     amount,
      category:   category,
      note:       note,
      confidence: confidence,
    );
  }

  double _extractAmount(String text) {
    // Ưu tiên: "45k" / "45K" → 45000
    final kPattern = RegExp(r'(\d+(?:[.,]\d+)?)\s*k\b', caseSensitive: false);
    final kMatch = kPattern.firstMatch(text);
    if (kMatch != null) {
      final raw = kMatch.group(1)!.replaceAll(',', '.');
      return (double.tryParse(raw) ?? 0) * 1000;
    }

    // "45 nghìn"
    final nghienPattern = RegExp(r'(\d+)\s*ngh[iì]n');
    final nghienMatch = nghienPattern.firstMatch(text);
    if (nghienMatch != null) {
      return (double.tryParse(nghienMatch.group(1)!) ?? 0) * 1000;
    }

    // "45.000"
    final dotPattern = RegExp(r'(\d{1,3}(?:\.\d{3})+)');
    final dotMatch = dotPattern.firstMatch(text);
    if (dotMatch != null) {
      return double.tryParse(dotMatch.group(1)!.replaceAll('.', '')) ?? 0;
    }

    // Số nguyên >= 4 chữ số
    final plainPattern = RegExp(r'\b(\d{4,})\b');
    final plainMatch = plainPattern.firstMatch(text);
    if (plainMatch != null) {
      return double.tryParse(plainMatch.group(1)!) ?? 0;
    }

    return 0;
  }

  String _extractNote(String original, double amount) {
    var note = original
        .replaceAll(RegExp(r'\d+(?:[.,]\d+)?\s*k\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\d+\s*nghìn'), '')
        .replaceAll(RegExp(r'\d{1,3}(?:\.\d{3})+'), '')
        .replaceAll(RegExp(r'\b\d{4,}\b'), '')
        // Xóa các từ nối thừa ở đầu/cuối
        .replaceAll(RegExp(r'^\s*(hôm nay|hôm qua|sáng|trưa|tối|chiều)\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*(hết|mất|tốn|chi)\s*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    if (note.isNotEmpty) {
      note = note[0].toUpperCase() + note.substring(1);
    }

    return note.isEmpty ? original : note;
  }
}
