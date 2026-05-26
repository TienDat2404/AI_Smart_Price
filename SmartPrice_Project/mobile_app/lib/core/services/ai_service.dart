import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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
    // Ăn uống
    'pho':      'Ăn uống',
    'com':      'Ăn uống',
    'bun':      'Ăn uống',
    'banh':     'Ăn uống',
    'an':       'Ăn uống',
    'cafe':     'Ăn uống',
    'ca phe':   'Ăn uống',
    'tra':      'Ăn uống',
    'nhau':     'Ăn uống',
    'lau':      'Ăn uống',
    'man':      'Ăn uống',   // mần (Nghệ Tĩnh/Huế)
    'to':       'Ăn uống',   // tô (tô phở)
    'uong':     'Ăn uống',
    // Di chuyển
    'xe om':    'Di chuyển',
    'grab':     'Di chuyển',
    'xe':       'Di chuyển',
    'xang':     'Di chuyển',
    'bus':      'Di chuyển',
    'taxi':     'Di chuyển',
    // Mua sắm
    'shopee':   'Mua sắm',
    'lazada':   'Mua sắm',
    'quan':     'Mua sắm',
    'ao':       'Mua sắm',
    'mua':      'Mua sắm',
    'kiem':     'Mua sắm',   // kiếm (miền Nam: đi kiếm = đi mua)
    // Giải trí
    'choi':     'Giải trí',
    'phim':     'Giải trí',
    'game':     'Giải trí',
    'netflix':  'Giải trí',
    'spotify':  'Giải trí',
    // Sức khỏe
    'thuoc':    'Sức khỏe',
    'bac si':   'Sức khỏe',
    'kham':     'Sức khỏe',
    'gym':      'Sức khỏe',
    // Hóa đơn
    'dien':     'Hóa đơn',
    'nuoc':     'Hóa đơn',
    'internet': 'Hóa đơn',
    // Thu nhập
    'luong':    'Thu nhập',
    'thuong':   'Thu nhập',
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
  /// Gọi Python AI Engine (hỗ trợ tiếng Việt vùng miền).
  /// Fallback về mock local nếu AI Engine chưa chạy.
  Future<AiParseResponse> parseText(String input) async {
    // Thử gọi Python AI Engine trước
    try {
      final uri = Uri.parse('$_baseUrl/parse/text');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': input}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        // Python trả về: { item, price, category, confidence, normalized_text, dialect_detected }
        final item = AiParseResult(
          amount:     (json['price'] as num? ?? 0).toDouble(),
          category:   json['category'] as String? ?? 'Khác',
          note:       json['item']     as String? ?? input,
          confidence: (json['confidence'] as num? ?? 0.8).toDouble(),
        );
        debugPrint('[AiService] Python response: $json');
        return AiParseResponse(items: [item]);
      }
    } catch (e) {
      debugPrint('[AiService] Python AI Engine không khả dụng, dùng mock: $e');
    }

    // Fallback: mock local (hỗ trợ tiếng Việt cơ bản + tiếng Anh)
    await Future.delayed(const Duration(milliseconds: 500));
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
    // Chuẩn hóa về ASCII để khớp keyword không dấu
    final ascii = _removeAccents(lower);

    // 1. Tìm số tiền (hỗ trợ dialect)
    final amount = _extractAmount(lower);

    // 2. Tìm hạng mục — so sánh trên chuỗi ASCII
    String category = 'Khác';
    for (final entry in _categoryKeywords.entries) {
      if (ascii.contains(entry.key)) {
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

  // ── Accent removal (no Unicode in regex char classes) ────────────────────

  static String _removeAccents(String s) {
    var r = s;
    // a-variants
    r = r.replaceAll('\u00e0', 'a').replaceAll('\u00e1', 'a')
         .replaceAll('\u1ea1', 'a').replaceAll('\u1ea3', 'a')
         .replaceAll('\u00e3', 'a')
         .replaceAll('\u0103', 'a')
         .replaceAll('\u1eb1', 'a').replaceAll('\u1eaf', 'a')
         .replaceAll('\u1eb3', 'a').replaceAll('\u1eb5', 'a')
         .replaceAll('\u00e2', 'a')
         .replaceAll('\u1ea7', 'a').replaceAll('\u1ea5', 'a')
         .replaceAll('\u1ead', 'a').replaceAll('\u1ea9', 'a')
         .replaceAll('\u1eab', 'a');
    // e-variants
    r = r.replaceAll('\u00e8', 'e').replaceAll('\u00e9', 'e')
         .replaceAll('\u1eb9', 'e').replaceAll('\u1ebb', 'e')
         .replaceAll('\u1ebd', 'e')
         .replaceAll('\u00ea', 'e')
         .replaceAll('\u1ec1', 'e').replaceAll('\u1ebf', 'e')
         .replaceAll('\u1ec7', 'e').replaceAll('\u1ec3', 'e')
         .replaceAll('\u1ec5', 'e');
    // i-variants
    r = r.replaceAll('\u00ec', 'i').replaceAll('\u00ed', 'i')
         .replaceAll('\u1ecb', 'i').replaceAll('\u1ec9', 'i')
         .replaceAll('\u0129', 'i');
    // o-variants
    r = r.replaceAll('\u00f2', 'o').replaceAll('\u00f3', 'o')
         .replaceAll('\u1ecd', 'o').replaceAll('\u1ecf', 'o')
         .replaceAll('\u00f5', 'o')
         .replaceAll('\u00f4', 'o')
         .replaceAll('\u1ed3', 'o').replaceAll('\u1ed1', 'o')
         .replaceAll('\u1ed9', 'o').replaceAll('\u1ed5', 'o')
         .replaceAll('\u1ed7', 'o')
         .replaceAll('\u01a1', 'o')
         .replaceAll('\u1edd', 'o').replaceAll('\u1edb', 'o')
         .replaceAll('\u1ee3', 'o').replaceAll('\u1edf', 'o')
         .replaceAll('\u1ee1', 'o');
    // u-variants
    r = r.replaceAll('\u00f9', 'u').replaceAll('\u00fa', 'u')
         .replaceAll('\u1ee5', 'u').replaceAll('\u1ee7', 'u')
         .replaceAll('\u0169', 'u')
         .replaceAll('\u01b0', 'u')
         .replaceAll('\u1eeb', 'u').replaceAll('\u1ee9', 'u')
         .replaceAll('\u1ef1', 'u').replaceAll('\u1eed', 'u')
         .replaceAll('\u1eef', 'u');
    // y-variants
    r = r.replaceAll('\u1ef3', 'y').replaceAll('\u00fd', 'y')
         .replaceAll('\u1ef5', 'y').replaceAll('\u1ef7', 'y')
         .replaceAll('\u1ef9', 'y');
    // d
    r = r.replaceAll('\u0111', 'd');
    return r;
  }

  // ── Dialect number words → value ──────────────────────────────────────────

  /// Trả về số tiền từ từ ngữ vùng miền (ASCII sau khi removeAccents).
  /// Trả về 0 nếu không khớp.
  static double _dialectToAmount(String t) {
    // "ham lam" / "nham lam" = 25k (hăm lăm — miền Nam)
    if (t.contains('ham lam') || t.contains('nham lam')) return 25000;
    if (t.contains('ham mot'))  return 21000;
    if (t.contains('ham hai'))  return 22000;
    if (t.contains('ham ba'))   return 23000;
    if (t.contains('ham bon'))  return 24000;
    if (t.contains('ham sau'))  return 26000;
    if (t.contains('ham bay'))  return 27000;
    if (t.contains('ham tam'))  return 28000;
    if (t.contains('ham chin')) return 29000;
    // "ham" đứng một mình = 20k
    if (RegExp(r'\bham\b').hasMatch(t)) return 20000;

    // X chuc = X0k
    if (t.contains('chin chuc')) return 90000;
    if (t.contains('tam chuc'))  return 80000;
    if (t.contains('bay chuc'))  return 70000;
    if (t.contains('sau chuc'))  return 60000;
    if (t.contains('nam chuc'))  return 50000;
    if (t.contains('bon chuc'))  return 40000;
    if (t.contains('ba chuc'))   return 30000;
    if (t.contains('hai chuc'))  return 20000;
    if (t.contains('mot chuc'))  return 10000;

    // muoi X = 1Xk
    if (t.contains('muoi lam') || t.contains('muoi lam')) return 15000;
    if (t.contains('muoi mot'))  return 11000;
    if (t.contains('muoi hai'))  return 12000;
    if (t.contains('muoi ba'))   return 13000;
    if (t.contains('muoi bon'))  return 14000;
    if (t.contains('muoi sau'))  return 16000;
    if (t.contains('muoi bay'))  return 17000;
    if (t.contains('muoi tam'))  return 18000;
    if (t.contains('muoi chin')) return 19000;

    return 0;
  }

  double _extractAmount(String text) {
    // Chuẩn hóa về ASCII để xử lý tiếng địa phương
    final t = _removeAccents(text.toLowerCase());

    // ── 1. Số đếm vùng miền (hăm lăm, hai chục, ...) ─────────────────────
    final dialectAmt = _dialectToAmount(t);
    if (dialectAmt > 0) return dialectAmt;

    // ── 2. "45k" / "45K" → 45000 ─────────────────────────────────────────
    final kMatch = RegExp(r'(\d+(?:[.,]\d+)?)\s*k\b', caseSensitive: false).firstMatch(t);
    if (kMatch != null) {
      return (double.tryParse(kMatch.group(1)!.replaceAll(',', '.')) ?? 0) * 1000;
    }

    // ── 3. "45 nghìn" / "45 ngàn" / "45 ngan" ────────────────────────────
    final nghienMatch = RegExp(r'(\d+)\s*(?:nghin|ngan|nghi\w*|nga\w*)').firstMatch(t);
    if (nghienMatch != null) {
      return (double.tryParse(nghienMatch.group(1)!) ?? 0) * 1000;
    }

    // ── 4. "45.000" / "45,000" ────────────────────────────────────────────
    final dotMatch = RegExp(r'(\d{1,3}(?:[.,]\d{3})+)').firstMatch(t);
    if (dotMatch != null) {
      return double.tryParse(
              dotMatch.group(1)!.replaceAll('.', '').replaceAll(',', '')) ??
          0;
    }

    // ── 5. Số nguyên >= 4 chữ số ──────────────────────────────────────────
    final plainMatch = RegExp(r'\b(\d{4,})\b').firstMatch(t);
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
