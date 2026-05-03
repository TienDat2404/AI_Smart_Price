import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/api_service.dart';
import 'confirm_invoice_screen.dart';

// ── Platform helper ───────────────────────────────────────────────────────────
bool get _isWindowsDesktop => defaultTargetPlatform == TargetPlatform.windows;

// ── Teal palette ──────────────────────────────────────────────────────────────
const _teal      = Color(0xFF00897B);
const _tealLight = Color(0xFFB2DFDB);
const _tealDark  = Color(0xFF00695C);

// ── OCR result model ──────────────────────────────────────────────────────────
class OcrResult {
  final String store;
  final double total;
  final String date;
  final String category;
  final String invoiceId;
  final double confidence;
  const OcrResult({
    required this.store,
    required this.total,
    required this.date,
    required this.category,
    this.invoiceId = '',
    this.confidence = 0.0,
  });
}

// ── ScanReceiptScreen ─────────────────────────────────────────────────────────
class ScanReceiptScreen extends StatefulWidget {
  const ScanReceiptScreen({super.key});
  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen>
    with TickerProviderStateMixin {
  // Camera
  CameraController? _cameraCtrl;
  bool _cameraReady = false;
  String? _cameraError;

  // Scan line — dùng CurvedAnimation để mượt hơn
  late AnimationController _scanAnim;
  late Animation<double> _scanLine;

  // State
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();

    // Scan line: ease-in-out, 2.5s mỗi chiều
    _scanAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _scanLine = CurvedAnimation(parent: _scanAnim, curve: Curves.easeInOut);
  }

  Future<void> _initCamera() async {
    if (_isWindowsDesktop) return;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _cameraError = 'Khong tim thay camera.');
        return;
      }
      _cameraCtrl = CameraController(
        cameras.first,
        ResolutionPreset.medium, // medium = ~1280x720, đủ cho OCR, upload nhanh hơn high
        enableAudio: false,
      );
      await _cameraCtrl!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      debugPrint('[Camera] $e');
      if (mounted) setState(() => _cameraError = 'Che do gia lap (Windows Preview)');
    }
  }

  @override
  void dispose() {
    _cameraCtrl?.dispose();
    _scanAnim.dispose();
    super.dispose();
  }

  // ── Capture ───────────────────────────────────────────────────────────────

  Future<void> _onCapture() async {
    if (_isProcessing) return;

    // Trên Windows không có camera thật — dùng ảnh giả lập
    if (_isWindowsDesktop || !_cameraReady || _cameraCtrl == null) {
      await _runOcrWithMockFallback();
      return;
    }

    setState(() => _isProcessing = true);
    try {
      // Chụp ảnh từ camera — dùng medium resolution để cân bằng chất lượng/tốc độ
      final xFile = await _cameraCtrl!.takePicture();
      await _sendToApi(xFile.path);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> _onPickImage() async {
    // Windows: image_picker không hỗ trợ — dùng mock fallback
    if (_isWindowsDesktop) {
      await _runOcrWithMockFallback();
      return;
    }

    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (file == null || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      await _sendToApi(file.path);
    } catch (e) {
      _handleError(e);
    }
  }

  /// Gửi ảnh lên API và hiển thị kết quả
  Future<void> _sendToApi(String imagePath) async {
    if (!mounted) return;
    setState(() => _isProcessing = true);

    try {
      // scanInvoice đã normalize keys về camelCase
      final json = await ApiService.instance.scanInvoice(imagePath);

      if (!mounted) return;
      setState(() => _isProcessing = false);

      final result = OcrResult(
        store:      json['storeName']   as String? ?? 'Khong ro',
        total:      (json['totalAmount'] as num? ?? 0).toDouble(),
        date:       json['date']        as String? ?? '',
        category:   json['category']    as String? ?? 'Khac',
        invoiceId:  json['invoiceId']   as String? ?? '',
        confidence: (json['confidence'] as num? ?? 0).toDouble(),
      );
      _showResult(result);
    } on Exception catch (e) {
      _handleError(e);
    }
  }

  /// Fallback cho Windows / không có camera — giả lập 2s rồi hiện kết quả demo
  Future<void> _runOcrWithMockFallback() async {
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _isProcessing = false);
    _showResult(const OcrResult(
      store: 'WinMart (Demo)',
      total: 450000,
      date: '24/04/2026',
      category: 'Mua sam',
      invoiceId: 'INV-DEMO-0001',
      confidence: 0.92,
    ));
  }

  void _handleError(Object e) {
    if (!mounted) return;
    setState(() => _isProcessing = false);

    debugPrint('[Scan] Error: ${e.runtimeType}: $e');

    // Phân loại lỗi
    final bool isOcrFail = e is ApiException && e.statusCode == 422;
    final bool isTimeout = e is ApiException && e.statusCode == 408;

    final String title = isOcrFail
        ? 'Khong nhan dien duoc'
        : isTimeout
            ? 'Qua thoi gian cho'
            : 'Co loi xay ra';

    final String message = e is ApiException
        ? e.message
        : e is Exception
            ? e.toString().replaceFirst('Exception: ', '')
            : 'Khong the nhan dien hoa don nay, vui long thu lai hoac nhap tay.';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(
            isOcrFail ? Icons.document_scanner_outlined : Icons.error_outline,
            color: isOcrFail ? const Color(0xFFF9A825) : const Color(0xFFE53935),
            size: 22,
          ),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(message, style: const TextStyle(fontSize: 14, color: Colors.black87)),
          if (isOcrFail) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Goi y:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
                SizedBox(height: 4),
                Text('• Chup lai voi anh ro net hon', style: TextStyle(fontSize: 12, color: Colors.black54)),
                Text('• Dam bao du anh sang', style: TextStyle(fontSize: 12, color: Colors.black54)),
                Text('• Hoac nhap thu cong ben duoi', style: TextStyle(fontSize: 12, color: Colors.black54)),
              ]),
            ),
          ],
        ]),
        actions: [
          TextButton(
            onPressed: () => WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.pop(context)),
            child: const Text('Thu lai', style: TextStyle(color: _teal, fontWeight: FontWeight.w700)),
          ),
          if (isOcrFail)
            TextButton(
              onPressed: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pop(context);
                Navigator.pop(context);
              }),
              child: const Text('Nhap thu cong', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  void _showResult(OcrResult result) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        slideUpRoute(ConfirmInvoiceScreen(ocrResult: result)),
      );
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final frameW = w * 0.78;
            final frameH = (h * 0.45).clamp(200.0, 400.0);

            return Stack(children: [
              // ── Background ────────────────────────────────────────────────
              if (_cameraReady && _cameraCtrl != null)
                Positioned.fill(child: CameraPreview(_cameraCtrl!))
              else
                Positioned.fill(child: _MockCameraBackground(errorMsg: _cameraError)),

              // ── Scan overlay — vùng quét sạch sẽ ─────────────────────────
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _scanLine,
                  builder: (_, __) => CustomPaint(
                    painter: _ScanOverlayPainter(
                      scanProgress: _scanLine.value,
                      frameWidth: frameW,
                      frameHeight: frameH,
                      isProcessing: _isProcessing,
                    ),
                  ),
                ),
              ),

              // ── Top bar ───────────────────────────────────────────────────
              Positioned(
                top: 0, left: 0, right: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _GlassButton(icon: Icons.arrow_back_ios_new, onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (context.mounted) Navigator.of(context).pop();
                      })),
                      const Text('Quet hoa don', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                      _GlassButton(icon: Icons.flash_off, onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) => _cameraCtrl?.setFlashMode(FlashMode.torch))),
                    ],
                  ),
                ),
              ),

              // ── Hint text ─────────────────────────────────────────────────
              if (!_isProcessing)
                Positioned(
                  top: h / 2 + frameH / 2 + 16,
                  left: 0, right: 0,
                  child: const Text(
                    'Dat hoa don vao trong khung de quet',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),

              // ── Processing overlay ────────────────────────────────────────
              if (_isProcessing)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.72),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Spinner lớn hơn, rõ hơn
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                            border: Border.all(color: _teal.withValues(alpha: 0.3), width: 1),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(18),
                            child: CircularProgressIndicator(color: _teal, strokeWidth: 3),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'AI dang phan tich du lieu hoa don...',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Vui long giu nguyen hoa don trong khung',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Bottom controls ───────────────────────────────────────────
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: _BottomControls(
                  onCapture: _onCapture,
                  onPickImage: _onPickImage,
                  onHistory: () {},
                  isProcessing: _isProcessing,
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

// ── Mock Camera Background ────────────────────────────────────────────────────
class _MockCameraBackground extends StatelessWidget {
  final String? errorMsg;
  const _MockCameraBackground({this.errorMsg});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(fit: StackFit.expand, children: [
        CustomPaint(painter: _MockReceiptPainter()),
        if (_isWindowsDesktop || errorMsg != null)
          Align(
            alignment: const Alignment(0, -0.72),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _teal.withValues(alpha: 0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.desktop_windows_outlined, size: 13, color: _tealLight),
                const SizedBox(width: 6),
                Text(
                  errorMsg ?? 'Che do gia lap camera (Windows Preview)',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _MockReceiptPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF0D1B2A), Color(0xFF1B2838), Color(0xFF0D1B2A)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    final cx = size.width / 2;
    final cy = size.height / 2;
    const rW = 200.0; const rH = 280.0;
    final rr = RRect.fromLTRBR(cx - rW / 2, cy - rH / 2, cx + rW / 2, cy + rH / 2, const Radius.circular(8));
    canvas.drawRRect(rr.shift(const Offset(4, 6)), Paint()..color = Colors.black.withValues(alpha: 0.4));
    canvas.drawRRect(rr, Paint()..color = const Color(0xFFF5F5F0));
    final lx1 = cx - rW / 2 + 16; final lx2 = cx + rW / 2 - 16; final sy = cy - rH / 2 + 24;
    final lp = Paint()..color = Colors.grey.withValues(alpha: 0.3)..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(lx1 + 20, sy), Offset(lx2 - 20, sy), Paint()..color = Colors.grey.withValues(alpha: 0.6)..strokeWidth = 3..strokeCap = StrokeCap.round);
    for (int i = 1; i <= 8; i++) { canvas.drawLine(Offset(lx1, sy + i * 26.0), Offset(i % 2 == 0 ? lx2 - 20 : lx2, sy + i * 26.0), lp); }
    canvas.drawLine(Offset(lx1, sy + 9 * 26.0), Offset(lx2, sy + 9 * 26.0), Paint()..color = Colors.grey.withValues(alpha: 0.5)..strokeWidth = 1);
    canvas.drawLine(Offset(lx1, sy + 10 * 26.0), Offset(lx2, sy + 10 * 26.0), Paint()..color = _teal.withValues(alpha: 0.6)..strokeWidth = 2.5..strokeCap = StrokeCap.round);
  }
  @override bool shouldRepaint(_MockReceiptPainter old) => false;
}

// ── Scan Overlay Painter ──────────────────────────────────────────────────────
/// Vùng quét hoàn toàn sạch — chỉ có dark mask, frame, corner accents và scan line.
/// Không có bất kỳ widget nào đè lên vùng quét.
class _ScanOverlayPainter extends CustomPainter {
  final double scanProgress;   // 0.0 → 1.0 (CurvedAnimation)
  final double frameWidth;
  final double frameHeight;
  final bool isProcessing;

  const _ScanOverlayPainter({
    required this.scanProgress,
    required this.frameWidth,
    required this.frameHeight,
    required this.isProcessing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final left   = cx - frameWidth / 2;
    final top    = cy - frameHeight / 2;
    final right  = cx + frameWidth / 2;
    final bottom = cy + frameHeight / 2;
    final frameRect = RRect.fromLTRBR(left, top, right, bottom, const Radius.circular(20));

    // ── Dark mask ngoài khung ─────────────────────────────────────────────
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(frameRect),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );

    // ── Frame border — sáng hơn khi đang xử lý ───────────────────────────
    canvas.drawRRect(
      frameRect,
      Paint()
        ..color = isProcessing ? _tealLight : _teal
        ..style = PaintingStyle.stroke
        ..strokeWidth = isProcessing ? 2.0 : 2.5,
    );

    // ── Corner accents ────────────────────────────────────────────────────
    _drawCorners(canvas, left, top, right, bottom);

    // ── Scan line — mượt mà, glow rõ hơn ─────────────────────────────────
    if (!isProcessing) {
      final lineY = top + (bottom - top) * scanProgress;

      // Glow area phía dưới line
      canvas.drawRect(
        Rect.fromLTWH(left + 1, lineY, frameWidth - 2, 40),
        Paint()..shader = LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [_teal.withValues(alpha: 0.3), Colors.transparent],
        ).createShader(Rect.fromLTWH(left, lineY, frameWidth, 40)),
      );

      // Đường line chính — gradient ngang
      canvas.drawLine(
        Offset(left + 8, lineY),
        Offset(right - 8, lineY),
        Paint()
          ..shader = LinearGradient(
            colors: [Colors.transparent, _tealLight, Colors.white, _tealLight, Colors.transparent],
          ).createShader(Rect.fromLTWH(left, lineY - 1, frameWidth, 2))
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );

      // Dot sáng ở giữa line
      canvas.drawCircle(
        Offset(cx, lineY),
        4,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
    }
  }

  void _drawCorners(Canvas canvas, double l, double t, double r, double b) {
    const len = 28.0; const cr = 20.0;
    final p = Paint()
      ..color = _teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(l, t + cr), Offset(l, t + len), p);
    canvas.drawLine(Offset(l + cr, t), Offset(l + len, t), p);
    canvas.drawLine(Offset(r, t + cr), Offset(r, t + len), p);
    canvas.drawLine(Offset(r - cr, t), Offset(r - len, t), p);
    canvas.drawLine(Offset(l, b - cr), Offset(l, b - len), p);
    canvas.drawLine(Offset(l + cr, b), Offset(l + len, b), p);
    canvas.drawLine(Offset(r, b - cr), Offset(r, b - len), p);
    canvas.drawLine(Offset(r - cr, b), Offset(r - len, b), p);
  }

  @override
  bool shouldRepaint(_ScanOverlayPainter old) =>
      old.scanProgress != scanProgress || old.isProcessing != isProcessing;
}

// ── Glass Button ──────────────────────────────────────────────────────────────
class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) => onTap()),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}

// ── Bottom Controls ───────────────────────────────────────────────────────────
class _BottomControls extends StatelessWidget {
  final VoidCallback onCapture, onPickImage, onHistory;
  final bool isProcessing;
  const _BottomControls({required this.onCapture, required this.onPickImage, required this.onHistory, required this.isProcessing});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _ControlBtn(icon: Icons.image_outlined, label: 'Thu vien', onTap: isProcessing ? () {} : onPickImage),
            // Capture FAB
            GestureDetector(
              onTap: isProcessing ? null : () => WidgetsBinding.instance.addPostFrameCallback((_) => onCapture()),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isProcessing ? [Colors.grey.shade700, Colors.grey.shade600] : [_teal, const Color(0xFF26A69A)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  boxShadow: isProcessing ? [] : [BoxShadow(color: _teal.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 2)],
                ),
                child: isProcessing
                    ? const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Icon(Icons.camera_alt, color: Colors.white, size: 30),
              ),
            ),
            _ControlBtn(icon: Icons.history, label: 'Lich su', onTap: isProcessing ? () {} : onHistory),
          ]),
        ),
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _ControlBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) => onTap()),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.2))),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ]),
    );
  }
}

// ── Result Bottom Sheet ───────────────────────────────────────────────────────
class _ResultBottomSheet extends StatelessWidget {
  final OcrResult result;
  const _ResultBottomSheet({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),

        // Header
        Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_teal, Color(0xFF26A69A)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.receipt_long, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Ket qua nhan dien', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1A2340))),
              if (result.invoiceId.isNotEmpty)
                Text(result.invoiceId, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
          ),
          // Confidence badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2F1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.auto_awesome, size: 13, color: _teal),
              SizedBox(width: 4),
              Text('92%', style: TextStyle(fontSize: 13, color: _teal, fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),

        const SizedBox(height: 20),

        // Divider với label
        Row(children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('Thong tin hoa don', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ),
          const Expanded(child: Divider()),
        ]),

        const SizedBox(height: 16),

        // Data fields — card style
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
          ),
          child: Column(children: [
            _DataRow(icon: Icons.store_outlined, label: 'Cua hang', value: result.store, isFirst: true),
            const _RowDivider(),
            _DataRow(
              icon: Icons.attach_money,
              label: 'Tong tien',
              value: '${_fmt(result.total)} d',
              valueColor: const Color(0xFFE53935),
              valueFontSize: 18,
              valueFontWeight: FontWeight.w900,
            ),
            const _RowDivider(),
            _DataRow(icon: Icons.calendar_today_outlined, label: 'Ngay', value: result.date),
            const _RowDivider(),
            _DataRow(icon: Icons.label_outline, label: 'Hang muc', value: result.category, isLast: true),
          ]),
        ),

        const SizedBox(height: 20),

        // Note
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFE082)),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline, size: 15, color: Color(0xFFF9A825)),
            SizedBox(width: 8),
            Expanded(child: Text('Kiem tra lai thong tin truoc khi luu', style: TextStyle(fontSize: 12, color: Color(0xFF795548)))),
          ]),
        ),

        const SizedBox(height: 20),

        // Action buttons
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) Navigator.pop(context);
              }),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Chinh sua'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _teal,
                side: const BorderSide(color: _teal),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(children: [
                      const Icon(Icons.check_circle, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text('Da luu: ${result.store} - ${_fmt(result.total)} d'),
                    ]),
                    backgroundColor: _tealDark,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Luu giao dich', style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  static String _fmt(double v) {
    final parts = v.toStringAsFixed(0).split('');
    final buf = StringBuffer();
    for (int i = 0; i < parts.length; i++) { if (i > 0 && (parts.length - i) % 3 == 0) buf.write('.'); buf.write(parts[i]); }
    return buf.toString();
  }
}

class _DataRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? valueColor;
  final double valueFontSize;
  final FontWeight valueFontWeight;
  final bool isFirst, isLast;

  const _DataRow({
    required this.icon, required this.label, required this.value,
    this.valueColor, this.valueFontSize = 15, this.valueFontWeight = FontWeight.w700,
    this.isFirst = false, this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, isFirst ? 14 : 10, 16, isLast ? 14 : 10),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: _teal.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 17, color: _teal),
        ),
        const SizedBox(width: 12),
        SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey))),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: valueFontSize, fontWeight: valueFontWeight, color: valueColor ?? const Color(0xFF1A2340)),
            textAlign: TextAlign.right,
          ),
        ),
      ]),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();
  @override
  Widget build(BuildContext context) => const Divider(height: 1, indent: 62, endIndent: 16);
}
