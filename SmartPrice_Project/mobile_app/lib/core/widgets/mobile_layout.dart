import 'package:flutter/material.dart';

/// Wrapper đảm bảo giao diện mobile luôn hiển thị đúng trên mọi kích thước màn hình.
///
/// - Trên mobile (< 480px): full-width, không thay đổi gì.
/// - Trên tablet / web (>= 480px): giới hạn 480px và căn giữa,
///   tránh form/content bị kéo dài bất thường.
///
/// Cách dùng — bọc toàn bộ body của Scaffold:
/// ```dart
/// Scaffold(
///   body: MobileLayout(child: YourContent()),
/// )
/// ```
/// Hoặc dùng [MobileLayout.scrollable] cho màn hình có SingleChildScrollView:
/// ```dart
/// Scaffold(
///   body: MobileLayout.scrollable(
///     padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
///     child: YourContent(),
///   ),
/// )
/// ```
class MobileLayout extends StatelessWidget {
  final Widget child;

  /// Chiều rộng tối đa — 480px phù hợp với màn hình mobile lớn nhất.
  static const double maxWidth = 480;

  const MobileLayout({super.key, required this.child});

  /// Factory cho màn hình có scroll — tích hợp SafeArea + SingleChildScrollView.
  factory MobileLayout.scrollable({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 24,
      vertical: 32,
    ),
    ScrollPhysics? physics,
    ScrollController? controller,
  }) {
    return MobileLayout(
      key: key,
      child: SafeArea(
        child: SingleChildScrollView(
          controller: controller,
          physics: physics,
          padding: padding,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
