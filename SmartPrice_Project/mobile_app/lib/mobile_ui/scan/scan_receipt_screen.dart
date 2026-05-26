import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
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
        if (mounted) setState(() => _cameraError = 'Không tìm thấy camera.');
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
      if (mounted) setState(() => _cameraError = 'Chế độ giả lập (Windows Preview)');
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
    // Windows: dùng file_picker để mở File Explorer chọn ảnh
    if (_isWindowsDesktop) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'bmp', 'webp'],
        dialogTitle: 'Chọn ảnh hóa đơn',
      );

      if (result == null || result.files.isEmpty || !mounted) return;
      final path = result.files.single.path;
      if (path == null) return;

      setState(() => _isProcessing = true);
      try {
        await _sendToApi(path);
      } catch (e) {
        _handleError(e);
      }
      return;
    }

    // Android / iOS: dùng image_picker
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
      final json = await ApiService.instance.scanInvoice(imagePath);

      if (!mounted) return;
      setState(() => _isProcessing = false);

      final status     = json['status'] as String? ?? 'success';
      final confidence = (json['confidence'] as num? ?? 0).toDouble();
      final suggestions = (json['suggestions'] as List?)
          ?.map((e) => e.toString())
          .toList() ?? [];

      // ── Thất bại hoàn toàn: không đọc được → màn hình chụp lại ──────────
      if (status == 'failed') {
        _showRetakeScreen(
          reason: json['fail_reason'] as String? ?? 'low_quality',
          rawText: json['raw_text'] as String? ?? '',
          suggestions: suggestions,
        );
        return;
      }

      final result = OcrResult(
        store:      json['store']      as String? ?? json['storeName']   as String? ?? 'Không rõ',
        total:      (json['total']     as num?    ?? json['totalAmount'] as num? ?? 0).toDouble(),
        date:       json['date']       as String? ?? '',
        category:   json['category']   as String? ?? 'Khác',
        invoiceId:  json['invoice_id'] as String? ?? json['invoiceId']  as String? ?? '',
        confidence: confidence,
      );

      // ── Confidence thấp: hiển thị kết quả + banner cảnh báo ─────────────
      if (status == 'low_confidence') {
        _showResult(result, lowConfidence: true, suggestions: suggestions);
      } else {
        _showResult(result);
      }
    } on Exception catch (e) {
      final isConnectionError = e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('TimeoutException') ||
          e.toString().contains('408') ||
          (e is ApiException && (e.statusCode == 0 || e.statusCode >= 500));

      if (isConnectionError) {
        debugPrint('[Scan] API không khả dụng, dùng smart mock fallback');
        await _runSmartMockFallback(imagePath);
      } else {
        _handleError(e);
      }
    }
  }

  /// Smart mock fallback — chỉ dùng khi AI Engine (Python) chưa chạy
  /// Hiển thị thông báo rõ ràng thay vì trả dữ liệu giả gây nhầm lẫn
  Future<void> _runSmartMockFallback(String imagePath) async {
    if (!mounted) return;
    setState(() => _isProcessing = false);

    // Hiển thị dialog thông báo AI Engine chưa chạy
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.cloud_off_outlined, color: Color(0xFFE65100), size: 22),
          SizedBox(width: 8),
          Text('AI Engine chưa chạy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            'Không thể kết nối đến Python AI Engine tại localhost:8000.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Để dùng OCR thực tế, hãy chạy:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
              SizedBox(height: 6),
              Text('cd ai_service', style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFF00695C))),
              Text('uvicorn main:app --port 8000', style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFF00695C))),
            ]),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.pop(context)),
            child: const Text('Đóng', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pop(context);
                _onPickImage(); // cho chọn lại ảnh khi engine đã chạy
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: _teal, foregroundColor: Colors.white),
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  /// Fallback cho Windows / không có camera
  Future<void> _runOcrWithMockFallback() async {
    await _runSmartMockFallback('demo');
  }

  void _handleError(Object e) {
    if (!mounted) return;
    setState(() => _isProcessing = false);

    debugPrint('[Scan] Error: ${e.runtimeType}: $e');

    // Phân loại lỗi
    final bool isOcrFail = e is ApiException && e.statusCode == 422;
    final bool isTimeout = e is ApiException && e.statusCode == 408;

    final String title = isOcrFail
        ? 'Không nhận diện được'
        : isTimeout
            ? 'Quá thời gian chờ'
            : 'Có lỗi xảy ra';

    final String message = e is ApiException
        ? e.message
        : e is Exception
            ? e.toString().replaceFirst('Exception: ', '')
            : 'Không thể nhận diện hóa đơn này, vui lòng thử lại hoặc nhập tay.';

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
                Text('Gợi ý:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
                SizedBox(height: 4),
                Text('• Chụp lại với ảnh rõ nét hơn', style: TextStyle(fontSize: 12, color: Colors.black54)),
                Text('• Đảm bảo đủ ánh sáng', style: TextStyle(fontSize: 12, color: Colors.black54)),
                Text('• Hoặc nhập thủ công bên dưới', style: TextStyle(fontSize: 12, color: Colors.black54)),
              ]),
            ),
          ],
        ]),
        actions: [
          TextButton(
            onPressed: () => WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.pop(context)),
            child: const Text('Thử lại', style: TextStyle(color: _teal, fontWeight: FontWeight.w700)),
          ),
          if (isOcrFail)
            TextButton(
              onPressed: () => WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pop(context);
                Navigator.pop(context);
              }),
              child: const Text('Nhập thủ công', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  void _showResult(OcrResult result, {bool lowConfidence = false, List<String> suggestions = const []}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        slideUpRoute(ConfirmInvoiceScreen(
          ocrResult: result,
          lowConfidence: lowConfidence,
          suggestions: suggestions,
        )),
      );
    });
  }

  /// Màn hình chụp lại — hiển thị khi OCR thất bại hoàn toàn
  void _showRetakeScreen({
    required String reason,
    required String rawText,
    required List<String> suggestions,
  }) {
    if (!mounted) return;
    setState(() => _isProcessing = false);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RetakeSheet(
        suggestions: suggestions,
        rawText: rawText,
        onRetake: () {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pop(); // đóng sheet
          });
        },
        onPickImage: () {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pop();
            _onPickImage();
          });
        },
      ),
    );
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
                      const Text('Quét hóa đơn', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
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
                    'Đặt hóa đơn vào trong khung để quét',
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
                          'AI đang phân tích dữ liệu hóa đơn...',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Vui lòng giữ nguyên hóa đơn trong khung',
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
                  errorMsg ?? 'Chế độ giả lập camera (Windows Preview)',
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
            _ControlBtn(icon: Icons.image_outlined, label: 'Thư viện', onTap: isProcessing ? () {} : onPickImage),
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
            _ControlBtn(icon: Icons.history, label: 'Lịch sử', onTap: isProcessing ? () {} : onHistory),
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

// ── Retake Sheet — hiển thị khi OCR thất bại ────────────────────────────────
class _RetakeSheet extends StatelessWidget {
  final List<String> suggestions;
  final String rawText;
  final VoidCallback onRetake;
  final VoidCallback onPickImage;

  const _RetakeSheet({
    required this.suggestions,
    required this.rawText,
    required this.onRetake,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28), topRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 16, 24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 20),

        // Icon + tiêu đề
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.document_scanner_outlined, color: Color(0xFFE65100), size: 30),
        ),
        const SizedBox(height: 14),
        const Text(
          'Không đọc được hóa đơn',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A2340)),
        ),
        const SizedBox(height: 6),
        const Text(
          'Ảnh chưa đủ rõ để nhận diện. Hãy thử lại theo gợi ý bên dưới.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 20),

        // Gợi ý cụ thể
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.tips_and_updates_outlined, size: 16, color: _teal),
                SizedBox(width: 6),
                Text('Gợi ý để chụp tốt hơn:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _teal)),
              ]),
              const SizedBox(height: 10),
              ...suggestions.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('• ', style: TextStyle(color: _teal, fontWeight: FontWeight.w700)),
                  Expanded(child: Text(tip, style: const TextStyle(fontSize: 12, color: Color(0xFF455A64)))),
                ]),
              )),
            ],
          ),
        ),

        // Raw text (nếu có — để user tham khảo)
        if (rawText.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('AI đọc được (không chắc chắn):',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFF57F17))),
              const SizedBox(height: 4),
              Text(
                rawText.length > 120 ? '${rawText.substring(0, 120)}...' : rawText,
                style: const TextStyle(fontSize: 11, color: Color(0xFF795548), fontStyle: FontStyle.italic),
              ),
            ]),
          ),
        ],

        const SizedBox(height: 24),

        // Nút hành động
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => WidgetsBinding.instance.addPostFrameCallback((_) => onPickImage()),
              icon: const Icon(Icons.image_outlined, size: 16),
              label: const Text('Chọn ảnh khác'),
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
              onPressed: () => WidgetsBinding.instance.addPostFrameCallback((_) => onRetake()),
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('Chụp lại', style: TextStyle(fontWeight: FontWeight.w700)),
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
}
