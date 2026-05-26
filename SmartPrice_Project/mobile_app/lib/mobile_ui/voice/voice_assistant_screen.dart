
import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/api_service.dart';
import '../../core/services/balance_notifier.dart';
import '../../core/models/transaction.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _teal      = Color(0xFF00897B);
const _tealLight = Color(0xFFE0F2F1);
const _cyan      = Color(0xFF00BCD4);
const _bg        = Color(0xFFF8FAFB);
const _textDark  = Color(0xFF1A2340);
const _textGrey  = Color(0xFF8A94A6);

// ── Kết quả sau khi processAndTranslate ──────────────────────────────────────
class _ParsedResult {
  final String category;
  final double amount;
  final String timeLabel;
  final String note;
  const _ParsedResult({
    required this.category,
    required this.amount,
    required this.timeLabel,
    required this.note,
  });
}

// ── Bảng từ khóa tiếng Anh → tiếng Việt ─────────────────────────────────────
const _enCategoryMap = {
  'eat': 'Ăn uống',   'food': 'Ăn uống',   'lunch': 'Ăn uống',
  'dinner': 'Ăn uống','breakfast': 'Ăn uống','coffee': 'Ăn uống',
  'drink': 'Ăn uống', 'pho': 'Ăn uống',    'rice': 'Ăn uống',
  'grab': 'Di chuyển','taxi': 'Di chuyển',  'bus': 'Di chuyển',
  'uber': 'Di chuyển','ride': 'Di chuyển',  'gas': 'Di chuyển',
  'fuel': 'Di chuyển','transport': 'Di chuyển',
  'shop': 'Mua sắm',  'buy': 'Mua sắm',    'purchase': 'Mua sắm',
  'clothes': 'Mua sắm','shirt': 'Mua sắm', 'shoes': 'Mua sắm',
  'movie': 'Giải trí','game': 'Giải trí',  'netflix': 'Giải trí',
  'play': 'Giải trí', 'entertainment': 'Giải trí',
  'doctor': 'Sức khỏe','medicine': 'Sức khỏe','gym': 'Sức khỏe',
  'hospital': 'Sức khỏe','health': 'Sức khỏe',
  'electric': 'Hóa đơn','water': 'Hóa đơn','internet': 'Hóa đơn',
  'bill': 'Hóa đơn',  'rent': 'Hóa đơn',
  'salary': 'Thu nhập','income': 'Thu nhập','bonus': 'Thu nhập',
  'freelance': 'Thu nhập','earn': 'Thu nhập',
};

// ── Bảng từ khóa thời gian ────────────────────────────────────────────────────
const _enTimeMap = {
  'today': 'Hôm nay',     'now': 'Hôm nay',
  'yesterday': 'Hôm qua', 'morning': 'Sáng nay',
  'noon': 'Trưa nay',     'evening': 'Tối nay',
  'night': 'Tối nay',     'this week': 'Tuần này',
  'last week': 'Tuần trước',
};

// ── Helper mở sheet ───────────────────────────────────────────────────────────
Future<dynamic> showVoiceAssistant(BuildContext context) {
  return showModalBottomSheet<dynamic>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _VoiceAssistantSheet(),
  );
}

// ── Sheet ─────────────────────────────────────────────────────────────────────
class _VoiceAssistantSheet extends StatefulWidget {
  const _VoiceAssistantSheet();
  @override
  State<_VoiceAssistantSheet> createState() => _VoiceAssistantSheetState();
}

class _VoiceAssistantSheetState extends State<_VoiceAssistantSheet>
    with TickerProviderStateMixin {

  // ── Speech ────────────────────────────────────────────────────────────────
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening      = false;
  String _liveText       = '';   // raw English text from STT

  // ── Result state ──────────────────────────────────────────────────────────
  bool _hasData      = false;
  bool _isProcessing = false;
  String _processingLabel = 'AI đang phân tích...'; // label thay đổi theo giai đoạn
  _ParsedResult? _result;
  String? _normalizedText;   // text sau khi chuẩn hóa dialect
  bool _dialectDetected = false; // có phát hiện từ địa phương không

  // ── Card animation ────────────────────────────────────────────────────────
  late AnimationController _cardAnim;
  late Animation<double>   _cardFade;
  late Animation<Offset>   _cardSlide;

  // ── Blinking dot ──────────────────────────────────────────────────────────
  late AnimationController _dotAnim;

  @override
  void initState() {
    super.initState();
    _cardAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _cardFade  = CurvedAnimation(parent: _cardAnim, curve: Curves.easeOut);
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(parent: _cardAnim, curve: Curves.easeOutCubic));
    _dotAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _initSpeech();
  }

  @override
  void dispose() {
    _cardAnim.dispose();
    _dotAnim.dispose();
    _speech.stop();
    super.dispose();
  }

  // ── Init STT ──────────────────────────────────────────────────────────────
  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (e) => debugPrint('[STT] Error: $e'),
      onStatus: (s) => debugPrint('[STT] Status: $s'),
    );
    if (mounted) setState(() {});
  }

  // ── Toggle listening ──────────────────────────────────────────────────────
  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      if (_liveText.trim().isNotEmpty) {
        _processAndTranslate(_liveText.trim());
      }
      return;
    }

    setState(() {
      _hasData      = false;
      _liveText     = '';
      _isProcessing = false;
      _result       = null;
    });
    _cardAnim.reset();

    if (!_speechAvailable) {
      _showManualInputDialog();
      return;
    }

    setState(() => _isListening = true);
    await _speech.listen(
      onResult: _onSpeechResult,
      // en_US — hoạt động tốt trên Windows
      // Để nhận tiếng Việt tốt hơn trên Android/iOS, đổi thành 'vi_VN'
      localeId: 'en_US',
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 4),
      partialResults: true,
      cancelOnError: false,
      // onDevice: false → ưu tiên xử lý qua cloud (Google/Apple) để tăng độ chính xác
      // Đặc biệt quan trọng cho tiếng Việt vùng miền
    );

    // Auto-fallback nếu không nhận được gì sau 20s
    Future.delayed(const Duration(seconds: 20), () {
      if (mounted && _isListening && _liveText.isEmpty) {
        _speech.stop();
        setState(() => _isListening = false);
        _showManualInputDialog();
      }
    });
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() => _liveText = result.recognizedWords);
    if (result.finalResult && _liveText.trim().isNotEmpty) {
      setState(() => _isListening = false);
      _processAndTranslate(_liveText.trim());
    }
  }

  // ── processAndTranslate: gọi Python AI Engine (hỗ trợ tiếng Việt vùng miền)
  // Fallback về xử lý local nếu AI Engine chưa chạy
  Future<void> _processAndTranslate(String inputText) async {
    setState(() {
      _isProcessing    = true;
      _processingLabel = 'AI đang lắng nghe...';
      _normalizedText  = null;
      _dialectDetected = false;
    });

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _processingLabel = 'AI đang hiểu bạn...');

    try {
      // ── Gọi Python AI Engine (hỗ trợ dialect đầy đủ) ──────────────────
      final response = await AiService.instance.parseText(inputText);
      if (!mounted) return;

      final item = response.first;
      // Phát hiện dialect: nếu category khác "Khác" và note khác input gốc
      final dialectFound = item.note.toLowerCase() != inputText.toLowerCase() &&
                           item.amount > 0;

      setState(() {
        _result = _ParsedResult(
          category:  item.category,
          amount:    item.amount,
          timeLabel: _detectTimeLabel(inputText),
          note:      item.note,
        );
        _normalizedText  = dialectFound ? item.note : null;
        _dialectDetected = dialectFound;
        _isProcessing    = false;
        _hasData         = true;
      });
      _cardAnim.forward();
    } catch (e) {
      // ── Fallback: xử lý local nếu AI Engine lỗi ───────────────────────
      debugPrint('[Voice] AI Engine lỗi, dùng local: $e');
      if (!mounted) return;
      _processLocal(inputText);
    }
  }

  /// Xử lý local khi AI Engine không khả dụng
  void _processLocal(String inputText) {
    final lower = inputText.toLowerCase();

    // Thử extract số tiền từ text gốc TRƯỚC (trước khi normalize có thể làm mất context)
    double amount = _extractAmountDialect(lower);

    final normalized = _normalizeDialect(lower);
    final dialectFound = normalized != lower;

    // Nếu chưa tìm được từ text gốc, thử từ normalized
    if (amount == 0) amount = _extractAmountDialect(normalized);

    String category = 'Khác';
    for (final entry in _enCategoryMap.entries) {
      if (lower.contains(entry.key) || normalized.contains(entry.key)) {
        category = entry.value; break;
      }
    }
    for (final entry in _viCategoryMap.entries) {
      if (lower.contains(entry.key) || normalized.contains(entry.key)) {
        category = entry.value; break;
      }
    }

    final note = _buildVietnameseNote(normalized, category, amount);

    setState(() {
      _result = _ParsedResult(
        category:  category,
        amount:    amount,
        timeLabel: _detectTimeLabel(inputText),
        note:      note,
      );
      _normalizedText  = dialectFound ? normalized : null;
      _dialectDetected = dialectFound;
      _isProcessing    = false;
      _hasData         = true;
    });
    _cardAnim.forward();
  }

  /// Phát hiện thời gian từ text
  String _detectTimeLabel(String text) {
    final lower = text.toLowerCase();
    for (final entry in _enTimeMap.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    const viTime = {
      'hôm nay': 'Hôm nay', 'hôm qua': 'Hôm qua',
      'sáng nay': 'Sáng nay', 'trưa nay': 'Trưa nay',
      'tối nay': 'Tối nay', 'chiều nay': 'Chiều nay',
    };
    for (final entry in viTime.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return 'Hôm nay';
  }

  // ── Từ điển vùng miền → từ phổ thông ─────────────────────────────────────
  static const Map<String, String> _dialectWords = {
    // Động từ
    'mần':    'ăn',    // Nghệ Tĩnh/Huế: "mần cái bánh" = ăn
    'nhậu':   'ăn',
    'kiếm':   'mua',   // miền Nam
    'chộp':   'mua',
    'coi':    'xem',
    'xài':    'dùng',
    // Đại từ
    'tui':    'tôi',
    'tau':    'tôi',   // Nghệ Tĩnh
    // Từ chỉ nơi chốn / thời gian
    'chừ':    'giờ',   // Huế/miền Trung
    'mô':     'đâu',
    'ni':     'này',
    'tê':     'kia',
    // Đơn vị tiền
    'ngàn':   'nghìn', // miền Nam
    'chục':   'mười',  // "hai chục" = hai mươi
  };

  // Từ khóa tiếng Việt → hạng mục (bổ sung cho _enCategoryMap)
  static const Map<String, String> _viCategoryMap = {
    'phở':       'Ăn uống',
    'cơm':       'Ăn uống',
    'bún':       'Ăn uống',
    'bánh':      'Ăn uống',
    'ăn':        'Ăn uống',
    'uống':      'Ăn uống',
    'cà phê':    'Ăn uống',
    'cafe':      'Ăn uống',
    'trà':       'Ăn uống',
    'mần':       'Ăn uống',   // dialect
    'tô':        'Ăn uống',   // "tô phở"
    'xe ôm':     'Di chuyển',
    'grab':      'Di chuyển',
    'xăng':      'Di chuyển',
    'xe':        'Di chuyển',
    'taxi':      'Di chuyển',
    'mua':       'Mua sắm',
    'shopee':    'Mua sắm',
    'quần':      'Mua sắm',
    'áo':        'Mua sắm',
    'thuốc':     'Sức khỏe',
    'khám':      'Sức khỏe',
    'điện':      'Hóa đơn',
    'nước':      'Hóa đơn',
    'lương':     'Thu nhập',
    'thưởng':    'Thu nhập',
  };

  String _normalizeDialect(String text) {
    var result = text;
    _dialectWords.forEach((dialect, standard) {
      result = result.replaceAll(RegExp(r'\b' + RegExp.escape(dialect) + r'\b'), standard);
    });
    return result;
  }

  /// Chuyển ký tự có dấu tiếng Việt sang ASCII không dấu
  /// Dùng để so sánh chuỗi mà không cần regex Unicode
  static String _removeAccents(String s) {
    // Dùng replaceAll tuần tự thay vì Map để tránh duplicate key
    var r = s;
    // a-variants
    r = r.replaceAll('\u00e0', 'a').replaceAll('\u00e1', 'a')
         .replaceAll('\u1ea1', 'a').replaceAll('\u1ea3', 'a')
         .replaceAll('\u00e3', 'a')
         .replaceAll('\u0103', 'a') // a breve (a)
         .replaceAll('\u1eb1', 'a').replaceAll('\u1eaf', 'a')
         .replaceAll('\u1eb3', 'a').replaceAll('\u1eb5', 'a')
         .replaceAll('\u1eab', 'a')
         .replaceAll('\u00e2', 'a') // a circumflex (a)
         .replaceAll('\u1ea7', 'a').replaceAll('\u1ea5', 'a')
         .replaceAll('\u1ead', 'a').replaceAll('\u1ea9', 'a')
         .replaceAll('\u1eab', 'a');
    // e-variants
    r = r.replaceAll('\u00e8', 'e').replaceAll('\u00e9', 'e')
         .replaceAll('\u1eb9', 'e').replaceAll('\u1ebb', 'e')
         .replaceAll('\u1ebd', 'e')
         .replaceAll('\u00ea', 'e') // e circumflex
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
         .replaceAll('\u00f4', 'o') // o circumflex
         .replaceAll('\u1ed3', 'o').replaceAll('\u1ed1', 'o')
         .replaceAll('\u1ed9', 'o').replaceAll('\u1ed5', 'o')
         .replaceAll('\u1ed7', 'o')
         .replaceAll('\u01a1', 'o') // o horn (o)
         .replaceAll('\u1edd', 'o').replaceAll('\u1edb', 'o')
         .replaceAll('\u1ee3', 'o').replaceAll('\u1edf', 'o')
         .replaceAll('\u1ee1', 'o');
    // u-variants
    r = r.replaceAll('\u00f9', 'u').replaceAll('\u00fa', 'u')
         .replaceAll('\u1ee5', 'u').replaceAll('\u1ee7', 'u')
         .replaceAll('\u0169', 'u')
         .replaceAll('\u01b0', 'u') // u horn (u)
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

  /// Bóc tách số tiền hỗ trợ số đếm vùng miền
  /// Dùng _removeAccents() để tránh regex Unicode trong character class
  double _extractAmountDialect(String text) {
    // Chuẩn hóa về ASCII không dấu để so sánh đơn giản
    final t = _removeAccents(text.toLowerCase());

    // ── Số đếm vùng miền ─────────────────────────────────────────────────
    // "ham lam" = 25k (miền Nam: hăm lăm)
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

    // X chuc = X0k (hai chục = 20k, ba chục = 30k, ...)
    if (t.contains('nam chuc'))  return 50000;
    if (t.contains('bon chuc'))  return 40000;
    if (t.contains('ba chuc'))   return 30000;
    if (t.contains('hai chuc'))  return 20000;
    if (t.contains('mot chuc'))  return 10000;
    if (t.contains('sau chuc'))  return 60000;
    if (t.contains('bay chuc'))  return 70000;
    if (t.contains('tam chuc'))  return 80000;
    if (t.contains('chin chuc')) return 90000;

    // muoi/muoi lam/mot/... = 15k/11k/...
    if (t.contains('muoi lam') || t.contains('muoi lam')) return 15000;
    if (t.contains('muoi mot'))  return 11000;
    if (t.contains('muoi hai'))  return 12000;
    if (t.contains('muoi ba'))   return 13000;
    if (t.contains('muoi bon'))  return 14000;
    if (t.contains('muoi sau'))  return 16000;
    if (t.contains('muoi bay'))  return 17000;
    if (t.contains('muoi tam'))  return 18000;
    if (t.contains('muoi chin')) return 19000;

    // ── Fallback: số thông thường ─────────────────────────────────────────
    // "50k"
    final kMatch = RegExp(r'(\d+(?:[.,]\d+)?)\s*k\b', caseSensitive: false).firstMatch(t);
    if (kMatch != null) {
      return (double.tryParse(kMatch.group(1)!.replaceAll(',', '.')) ?? 0) * 1000;
    }

    // "50 nghìn" / "50 ngàn" / "50 nghin" / "50 ngan"
    final nghinhMatch = RegExp(r'(\d+)\s*(?:nghin|ngan|nghi|nga)\w*').firstMatch(t);
    if (nghinhMatch != null) {
      return (double.tryParse(nghinhMatch.group(1)!) ?? 0) * 1000;
    }

    // "50.000" / "50,000"
    final sepMatches = RegExp(r'\b(\d{1,3}(?:[.,]\d{3})+)\b').allMatches(t);
    if (sepMatches.isNotEmpty) {
      final amounts = sepMatches
          .map((m) => double.tryParse(
                m.group(1)!.replaceAll('.', '').replaceAll(',', '')) ?? 0)
          .where((a) => a > 0)
          .toList();
      if (amounts.isNotEmpty) return amounts.reduce((a, b) => a > b ? a : b);
    }

    // "50000"
    final plainMatch = RegExp(r'\b(\d{4,})\b').firstMatch(t);
    if (plainMatch != null) return double.tryParse(plainMatch.group(1)!) ?? 0;

    return 0;
  }

  /// Tạo ghi chú tiếng Việt thông minh từ text tiếng Anh
  String _buildVietnameseNote(String lower, String category, double amount) {
    // Map một số cụm từ phổ biến
    const phrases = {
      'pho': 'Phở',
      'coffee': 'Cà phê',
      'lunch': 'Ăn trưa',
      'dinner': 'Ăn tối',
      'breakfast': 'Ăn sáng',
      'grab': 'Grab',
      'taxi': 'Taxi',
      'movie': 'Xem phim',
      'shopping': 'Mua sắm',
      'medicine': 'Thuốc',
      'gym': 'Gym',
      'salary': 'Lương',
      'bonus': 'Thưởng',
    };
    for (final entry in phrases.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    // Fallback: dùng tên hạng mục
    return category;
  }

  // ── Save transaction ──────────────────────────────────────────────────────
  Future<void> _onSave() async {
    if (_result == null || _result!.amount <= 0) return;
    try {
      final tx = Transaction(
        id:        '',
        userId:    'user_01',
        itemName:  _result!.note,
        amount:    _result!.amount,
        category:  _result!.category,
        note:      'Voice: $_liveText',
        date:      DateTime.now(),
        isExpense: _result!.category != 'Thu nhập',
      );
      await ApiService.instance.saveTransaction(tx);
      // ✅ Cập nhật số dư real-time
      BalanceNotifier.instance.applyTransaction(
        amount:    _result!.amount,
        isExpense: _result!.category != 'Thu nhập',
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text('Đã lưu: ${_result!.note} — ${_fmtAmount(_result!.amount)} đ'),
        ]),
        backgroundColor: _teal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi lưu: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ── Manual input dialog (fallback) ────────────────────────────────────────
  void _showManualInputDialog() {
    final ctrl = TextEditingController();
    const samples = [
      'I ate pho for 50k',
      'Grab ride home 35k',
      'Shopping at Shopee 200k',
      'Coffee this morning 30k',
      'Salary received 5000k',
      // Tiếng Việt vùng miền
      'Sáng nay uống cà phê hết hăm lăm ngàn',
      'Mần cái bánh mỳ mười lăm ngàn',
      'Đi xe ôm hết hai chục',
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_teal, _cyan]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.mic_none, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          const Text('Nhập bằng text', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
        content: SizedBox(
          width: 320,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _tealLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(children: [
                Icon(Icons.translate, size: 14, color: _teal),
                SizedBox(width: 6),
                Expanded(child: Text(
                  'Nhập tiếng Anh — AI sẽ tự dịch sang tiếng Việt',
                  style: TextStyle(fontSize: 11, color: _teal, fontWeight: FontWeight.w600),
                )),
              ]),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Tiếng Anh hoặc tiếng Việt vùng miền...',
                hintStyle: const TextStyle(color: _textGrey, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFF0F4F8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onSubmitted: (v) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.of(ctx).pop();
                  if (v.trim().isNotEmpty) {
                    setState(() => _liveText = v.trim());
                    _processAndTranslate(v.trim());
                  }
                });
              },
            ),
            const SizedBox(height: 10),
            const Text('Câu mẫu:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _textGrey)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: samples.map((s) => GestureDetector(
                onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                  ctrl.text = s;
                  ctrl.selection = TextSelection.fromPosition(TextPosition(offset: s.length));
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _tealLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _teal.withValues(alpha: 0.3)),
                  ),
                  child: Text(s, style: const TextStyle(fontSize: 10, color: _teal, fontWeight: FontWeight.w600)),
                ),
              )).toList(),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(ctx).pop()),
            child: const Text('Hủy', style: TextStyle(color: _textGrey)),
          ),
          ElevatedButton(
            onPressed: () {
              final text = ctrl.text.trim();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.of(ctx).pop();
                if (text.isNotEmpty) {
                  setState(() => _liveText = text);
                  _processAndTranslate(text);
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Phân tích', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return Container(
      height: screenH * 0.82,
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32), topRight: Radius.circular(32),
        ),
      ),
      child: Column(children: [
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(children: [
            GestureDetector(
              onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) Navigator.of(context).pop();
              }),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
                ),
                child: const Icon(Icons.close, size: 18, color: _textDark),
              ),
            ),
            const Expanded(
              child: Text('SmartPrice AI', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textDark)),
            ),
            // Language badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _tealLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.translate, size: 12, color: _teal),
                SizedBox(width: 4),
                Text('EN → VI', style: TextStyle(fontSize: 10, color: _teal, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        ),
        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(children: [
              const SizedBox(height: 8),
              _buildMicroSection(),
              const SizedBox(height: 28),
              if (_isProcessing)
                _buildProcessingIndicator()
              else if (_hasData && _result != null)
                _buildResultCards()
              else
                _buildIdleHint(),
              const SizedBox(height: 24),
            ]),
          ),
        ),
        _buildInputBar(),
      ]),
    );
  }

  // ── Micro section ─────────────────────────────────────────────────────────
  Widget _buildMicroSection() {
    return Column(children: [
      AvatarGlow(
        animate: _isListening,
        glowColor: _teal,
        glowRadiusFactor: 0.35,
        child: GestureDetector(
          onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) => _toggleListening()),
          child: Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isListening ? [_teal, _cyan] : [const Color(0xFF00695C), _teal],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                color: _teal.withValues(alpha: _isListening ? 0.5 : 0.3),
                blurRadius: _isListening ? 24 : 14,
                offset: const Offset(0, 6),
              )],
            ),
            child: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: Colors.white, size: 38,
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      if (_isListening)
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedBuilder(
            animation: _dotAnim,
            builder: (_, __) => Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: _teal.withValues(alpha: _dotAnim.value),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text('Đang lắng nghe (EN)...',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _teal)),
        ])
      else
        Column(children: [
          Text(
            _speechAvailable ? 'Nói tiếng Anh — AI dịch sang tiếng Việt' : 'Nhấn để nhập text',
            style: const TextStyle(fontSize: 12, color: _textGrey),
            textAlign: TextAlign.center,
          ),
          if (_speechAvailable) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _tealLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('🎤 en_US  →  🤖 AI  →  🇻🇳 Tiếng Việt',
                  style: TextStyle(fontSize: 10, color: _teal, fontWeight: FontWeight.w600)),
            ),
          ],
        ]),
    ]);
  }

  // ── Processing indicator ──────────────────────────────────────────────────
  Widget _buildProcessingIndicator() {
    return Column(children: [
      const SizedBox(height: 16),
      const CircularProgressIndicator(color: _teal, strokeWidth: 2.5),
      const SizedBox(height: 14),
      // Label thay đổi theo giai đoạn xử lý
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Text(
          _processingLabel,
          key: ValueKey(_processingLabel),
          style: const TextStyle(fontSize: 13, color: _textGrey),
        ),
      ),
      if (_liveText.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _teal.withValues(alpha: 0.2)),
          ),
          child: Text('"$_liveText"',
              style: const TextStyle(fontSize: 12, color: _textDark, fontStyle: FontStyle.italic)),
        ),
      ],
    ]);
  }

  // ── Idle hint ─────────────────────────────────────────────────────────────
  Widget _buildIdleHint() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _tealLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        const Icon(Icons.tips_and_updates_outlined, color: _teal, size: 26),
        const SizedBox(height: 10),
        const Text('Thử nói:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _teal)),
        const SizedBox(height: 6),
        ...[
          // Tiếng Anh (en_US STT)
          '"I ate pho for 50k today"',
          '"Grab ride home 35 thousand"',
          // Tiếng Việt vùng miền (nhập text)
          '"Sáng nay uống cà phê hết hăm lăm ngàn"',
          '"Mần cái bánh mỳ mười lăm ngàn"',
          '"Đi xe ôm hết hai chục"',
        ].map((s) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(s, style: const TextStyle(fontSize: 11, color: _textGrey, fontStyle: FontStyle.italic)),
        )),
      ]),
    );
  }

  // ── Result cards ──────────────────────────────────────────────────────────
  Widget _buildResultCards() {
    final r = _result!;
    return FadeTransition(
      opacity: _cardFade,
      child: SlideTransition(
        position: _cardSlide,
        child: Column(children: [
          // Raw text chip — hiển thị những gì AI "nghe" được
          if (_liveText.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _teal.withValues(alpha: 0.15)),
              ),
              child: Row(children: [
                const Icon(Icons.record_voice_over_outlined, size: 14, color: _textGrey),
                const SizedBox(width: 8),
                Expanded(child: Text('"$_liveText"',
                    style: const TextStyle(fontSize: 11, color: _textGrey, fontStyle: FontStyle.italic),
                    maxLines: 2, overflow: TextOverflow.ellipsis)),
                const Icon(Icons.arrow_forward, size: 12, color: _textGrey),
              ]),
            ),

          // Dialect badge — hiển thị khi phát hiện từ địa phương
          if (_dialectDetected && _normalizedText != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: Row(children: [
                const Icon(Icons.translate, size: 14, color: Color(0xFFF9A825)),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Đã nhận diện từ địa phương',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFF57F17))),
                  Text('→ "${_normalizedText}"',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF795548), fontStyle: FontStyle.italic),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ])),
              ]),
            )
          else
            const SizedBox(height: 4),
          // 3 cards
          Row(children: [
            Expanded(child: _ResultCard(
              icon: Icons.restaurant_outlined,
              iconBg: const Color(0xFFFFF3E0),
              iconColor: const Color(0xFFE65100),
              label: 'Hạng mục',
              value: r.category,
            )),
            const SizedBox(width: 12),
            Expanded(child: _ResultCard(
              icon: Icons.account_balance_wallet_outlined,
              iconBg: const Color(0xFFE8F5E9),
              iconColor: const Color(0xFF2E7D32),
              label: 'Số tiền',
              value: '${_fmtAmount(r.amount)} đ',
              valueColor: const Color(0xFF2E7D32),
            )),
          ]),
          const SizedBox(height: 12),
          _ResultCard(
            icon: Icons.access_time_outlined,
            iconBg: _tealLight,
            iconColor: _teal,
            label: 'Thời gian',
            value: r.timeLabel,
            fullWidth: true,
          ),
          if (r.note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _teal.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.notes, size: 16, color: _textGrey),
                const SizedBox(width: 8),
                Expanded(child: Text(r.note,
                    style: const TextStyle(fontSize: 13, color: _textDark))),
              ]),
            ),
          ],
          const SizedBox(height: 20),
          // Save button
          SizedBox(
            width: double.infinity, height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_teal, _cyan],
                  begin: Alignment.centerLeft, end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [BoxShadow(color: _teal.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 5))],
              ),
              child: ElevatedButton.icon(
                onPressed: () => WidgetsBinding.instance.addPostFrameCallback((_) => _onSave()),
                icon: const Icon(Icons.check_rounded, size: 20),
                label: const Text('Lưu giao dịch', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                  foregroundColor: Colors.white, shape: const StadiumBorder(),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, -3))],
      ),
      child: Row(children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(children: [
              Expanded(
                child: Text(
                  _liveText.isEmpty
                      ? (_speechAvailable ? 'Đang chờ giọng nói...' : 'Nhập text tiếng Anh...')
                      : _liveText,
                  style: TextStyle(
                    fontSize: 13,
                    color: _liveText.isEmpty ? _textGrey : _textDark,
                    fontStyle: _liveText.isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedBuilder(
                animation: _dotAnim,
                builder: (_, __) => Icon(
                  Icons.graphic_eq,
                  color: _isListening
                      ? _teal.withValues(alpha: 0.5 + _dotAnim.value * 0.5)
                      : _textGrey.withValues(alpha: 0.3),
                  size: 18,
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        // Send button
        GestureDetector(
          onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_liveText.trim().isNotEmpty && !_isProcessing) {
              _processAndTranslate(_liveText.trim());
            } else if (!_speechAvailable) {
              _showManualInputDialog();
            }
          }),
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_teal, _cyan]),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: _teal.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }
}

// ── Result Card ───────────────────────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconColor;
  final String label, value;
  final Color? valueColor;
  final bool fullWidth;

  const _ResultCard({
    required this.icon, required this.iconBg, required this.iconColor,
    required this.label, required this.value,
    this.valueColor, this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _textGrey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: valueColor ?? _textDark),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }
}

// ── Helper ────────────────────────────────────────────────────────────────────
String _fmtAmount(double v) {
  final parts = v.toStringAsFixed(0).split('');
  final buf   = StringBuffer();
  for (int i = 0; i < parts.length; i++) {
    if (i > 0 && (parts.length - i) % 3 == 0) buf.write('.');
    buf.write(parts[i]);
  }
  return buf.toString();
}
