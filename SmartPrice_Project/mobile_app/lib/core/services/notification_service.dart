import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Quản lý Local Notifications cho SmartPrice AI.
///
/// Sử dụng:
/// ```dart
/// // Khởi tạo một lần trong main()
/// await NotificationService.instance.init();
///
/// // Hiển thị cảnh báo chi tiêu
/// await NotificationService.instance.showBudgetWarning(usedPercent: 85);
/// ```
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  // Callback khi user nhấn vào notification — set từ main.dart
  void Function(String? payload)? onNotificationTap;

  // ── Khởi tạo ─────────────────────────────────────────────────────────────

  Future<void> init() async {
    // Windows không hỗ trợ flutter_local_notifications — skip
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      debugPrint('[Notification] Platform không hỗ trợ, bỏ qua init.');
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('[Notification] Tapped: ${details.payload}');
        onNotificationTap?.call(details.payload);
      },
    );

    // Yêu cầu quyền trên Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    debugPrint('[Notification] Initialized.');
  }

  // ── Hiển thị cảnh báo chi tiêu ───────────────────────────────────────────

  /// Hiển thị notification cảnh báo khi chi tiêu vượt 80% ngân sách.
  ///
  /// [usedPercent] — phần trăm đã dùng (0–100)
  /// [payload] — dữ liệu truyền khi user nhấn (mặc định: "analytics")
  Future<void> showBudgetWarning({
    required double usedPercent,
    String payload = 'analytics',
  }) async {
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      debugPrint('[Notification] Windows: skip showBudgetWarning (${usedPercent.toStringAsFixed(0)}%)');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'budget_warning',
      'Canh bao ngan sach',
      channelDescription: 'Thong bao khi chi tieu vuot nguong an toan',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final pct = usedPercent.toStringAsFixed(0);
    final body = 'Ban da su dung $pct% ngan sach thang nay. Hay can nhac cac khoan chi tiep theo nhe!';

    await _plugin.show(
      1001,                        // notification id
      'Canh bao chi tieu',
      body,
      details,
      payload: payload,
    );

    debugPrint('[Notification] Budget warning shown: $pct%');
  }

  // ── Hiển thị thông báo thông thường ──────────────────────────────────────

  Future<void> showGeneral({
    required String title,
    required String body,
    String payload = '',
    int id = 1000,
  }) async {
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      debugPrint('[Notification] Windows: skip showGeneral');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'general', 'Thong bao chung',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(id, title, body, details, payload: payload);
  }
}
