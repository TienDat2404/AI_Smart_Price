import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/api_service.dart';
import '../../core/models/transaction.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _teal      = Color(0xFF00897B);
const _tealLight = Color(0xFFE0F2F1);
const _cyan      = Color(0xFF00BCD4);
const _bg        = Color(0xFFF8FAFB);
const _textDark  = Color(0xFF1A2340);
const _textGrey  = Color(0xFF8A94A6);

// ── Helper để mở sheet ────────────────────────────────────────────────────────
Future<dynamic> showVoiceAssistant(BuildContext context) {
  return showModalBottomSheet(
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
  String _liveText       = '';

  // ── AI result ─────────────────────────────────────────────────────────────
  bool _hasData      = false;
  bool _isProcessing = false;
  String _category   = '';
  double _amount     = 0;
  String _timeLabel  = 'Hôm nay';
  String _note       = '';

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _cardAnim;
  late Animation<double>   _cardFade;
  late Animation<Offset>   _cardSlide;

  // ── Blinking dot ──────────────────────────────────────────────────────────
  late AnimationController _dotAnim;

  @override
  void initState() {
    super.initState();

    // Card appear animation
    _cardAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _cardFade  = CurvedAnimation(parent: _cardAnim, curve: Curves.easeOut);
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _cardAnim, curve: Curves.easeOutCubic));

    // Blinking dot
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

  // ── Speech init ───────────────────────────────────────────────────────────
  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (e) => debugPrint('[STT] Error: $e'),
    );
    if (mounted) setState(() {});
  }

  // ── Start / Stop listening ────────────────────────────────────────────────
  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      if (_liveText.trim().isNotEmpty) {
        _runMockAI(_liveText.trim());
      }
      return;
    }

    // Reset state
    setState(() {
      _hasData      = false;
      _liveText     = '';
      _isProcessing = false;
    });
    _cardAnim.reset();

    if (!_speechAvailable) {
      // Fallback: giả lập trên Windows (không có mic thật)
      setState(() { _isListening = true; _liveText = ''; });
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _liveText    = 'Hôm nay đi ăn phở hết 50k';
      });
      _runMockAI(_liveText);
      return;
    }

    setState(() => _isListening = true);
    await _speech.listen(
      onResult: _onSpeechResult,
      localeId: 'vi_VN',
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() => _liveText = result.recognizedWords);
    if (result.finalResult) {
      setState(() => _isListening = false);
      if (_liveText.trim().isNotEmpty) _runMockAI(_liveText.trim());
    }
  }

  // ── Mock AI extraction ────────────────────────────────────────────────────
  Future<void> _runMockAI(String text) async {
    setState(() => _isProcessing = true);

    // Giả lập AI xử lý 1.5 giây
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    // Dùng AiService để parse
    final response = await AiService.instance.parseText(text);
    final item     = response.first;

    setState(() {
      _category   = item.category;
      _amount     = item.amount;
      _note       = item.note;
      _timeLabel  = 'Hôm nay';
      _isProcessing = false;
      _hasData    = true;
    });

    _cardAnim.forward();
  }

  // ── Save transaction ──────────────────────────────────────────────────────
  Future<void> _onSave() async {
    if (!_hasData || _amount <= 0) return;

    try {
      final tx = Transaction(
        id:        '',
        userId:    'user_01',
        itemName:  _note.isNotEmpty ? _note : _category,
        amount:    _amount,
        category:  _category,
        note:      _note,
        date:      DateTime.now(),
        isExpense: _category != 'Thu nhập',
      );
      await ApiService.instance.saveTransaction(tx);
      if (!mounted) return;
      Navigator.of(context).pop(true); // báo dashboard reload
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text('Đã lưu: $_note - ${_fmtAmount(_amount)} đ'),
        ]),
        backgroundColor: _teal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Lỗi lưu: $e'),
        backgroundColor: Colors.red,
      ));
    }
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
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
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
            const SizedBox(width: 36), // balance
          ]),
        ),

        // Main content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(children: [
              const SizedBox(height: 8),

              // ── Micro button ─────────────────────────────────────────────
              _buildMicroSection(),

              const SizedBox(height: 32),

              // ── Result cards (animated) ──────────────────────────────────
              if (_isProcessing)
                _buildProcessingIndicator()
              else if (_hasData)
                _buildResultCards()
              else
                _buildIdleHint(),

              const SizedBox(height: 24),
            ]),
          ),
        ),

        // ── Input bar ────────────────────────────────────────────────────────
        _buildInputBar(),
      ]),
    );
  }

  // ── Micro section ─────────────────────────────────────────────────────────
  Widget _buildMicroSection() {
    return Column(children: [
      // Glow + button
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
                colors: _isListening
                    ? [_teal, _cyan]
                    : [const Color(0xFF00695C), _teal],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _teal.withValues(alpha: _isListening ? 0.5 : 0.3),
                  blurRadius: _isListening ? 24 : 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: Colors.white,
              size: 38,
            ),
          ),
        ),
      ),

      const SizedBox(height: 16),

      // Status label
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
          const Text('Đang lắng nghe...',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _teal)),
        ])
      else
        Text(
          _speechAvailable ? 'Nhấn micro để bắt đầu' : 'Nhấn để nhập giọng nói',
          style: const TextStyle(fontSize: 13, color: _textGrey),
        ),
    ]);
  }

  // ── Processing indicator ──────────────────────────────────────────────────
  Widget _buildProcessingIndicator() {
    return Column(children: [
      const SizedBox(height: 16),
      const CircularProgressIndicator(color: _teal, strokeWidth: 2.5),
      const SizedBox(height: 14),
      const Text('AI đang phân tích...', style: TextStyle(fontSize: 13, color: _textGrey)),
    ]);
  }

  // ── Idle hint ─────────────────────────────────────────────────────────────
  Widget _buildIdleHint() {
    return Column(children: [
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _tealLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          const Icon(Icons.tips_and_updates_outlined, color: _teal, size: 28),
          const SizedBox(height: 10),
          const Text('Thử nói:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _teal)),
          const SizedBox(height: 6),
          ...[
            '"Hôm nay ăn phở hết 50k"',
            '"Đi Grab về nhà 35 nghìn"',
            '"Mua sắm Shopee 200k"',
          ].map((s) => Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(s, style: const TextStyle(fontSize: 12, color: _textGrey, fontStyle: FontStyle.italic)),
          )),
        ]),
      ),
    ]);
  }

  // ── Result cards ──────────────────────────────────────────────────────────
  Widget _buildResultCards() {
    return FadeTransition(
      opacity: _cardFade,
      child: SlideTransition(
        position: _cardSlide,
        child: Column(children: [
          // Row: Category + Amount
          Row(children: [
            Expanded(child: _ResultCard(
              icon: Icons.restaurant_outlined,
              iconBg: const Color(0xFFFFF3E0),
              iconColor: const Color(0xFFE65100),
              label: 'Hạng mục',
              value: _category.isNotEmpty ? _category : 'Khác',
            )),
            const SizedBox(width: 12),
            Expanded(child: _ResultCard(
              icon: Icons.account_balance_wallet_outlined,
              iconBg: const Color(0xFFE8F5E9),
              iconColor: const Color(0xFF2E7D32),
              label: 'Số tiền',
              value: '${_fmtAmount(_amount)} đ',
              valueColor: const Color(0xFF2E7D32),
            )),
          ]),
          const SizedBox(height: 12),
          // Time card (full width)
          _ResultCard(
            icon: Icons.access_time_outlined,
            iconBg: _tealLight,
            iconColor: _teal,
            label: 'Thời gian',
            value: _timeLabel,
            fullWidth: true,
          ),
          const SizedBox(height: 16),
          // Note if available
          if (_note.isNotEmpty)
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
                Expanded(child: Text(_note,
                    style: const TextStyle(fontSize: 13, color: _textDark))),
              ]),
            ),
          const SizedBox(height: 20),
          // Save button
          SizedBox(
            width: double.infinity, height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_teal, _cyan],
                    begin: Alignment.centerLeft, end: Alignment.centerRight),
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
        // Text display
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(children: [
              Expanded(
                child: Text(
                  _liveText.isEmpty ? 'Nói gì đó...' : _liveText,
                  style: TextStyle(
                    fontSize: 14,
                    color: _liveText.isEmpty ? _textGrey : _textDark,
                    fontStyle: _liveText.isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Sound wave icon
              AnimatedBuilder(
                animation: _dotAnim,
                builder: (_, __) => Icon(
                  Icons.graphic_eq,
                  color: _isListening
                      ? _teal.withValues(alpha: 0.5 + _dotAnim.value * 0.5)
                      : _textGrey.withValues(alpha: 0.4),
                  size: 20,
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
              _runMockAI(_liveText.trim());
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
              style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800,
                color: valueColor ?? _textDark,
              ),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
String _fmtAmount(double v) {
  final parts = v.toStringAsFixed(0).split('');
  final buf   = StringBuffer();
  for (int i = 0; i < parts.length; i++) {
    if (i > 0 && (parts.length - i) % 3 == 0) buf.write('.');
    buf.write(parts[i]);
  }
  return buf.toString();
}
