import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_ext.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/mobile_layout.dart';
import '../auth/login_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _teal     = Color(0xFF00897B);
const _tealDark = Color(0xFF00695C);
const _cyan     = Color(0xFF00BCD4);
const _bg       = Color(0xFFF5F7FA);
const _white    = Colors.white;
const _textDark = Color(0xFF1A2340);
const _textGrey = Color(0xFF8A94A6);
const _green    = Color(0xFF43A047);

// ── ProfileScreen ─────────────────────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  bool _aiReminder  = true;
  bool _autoOcr     = false;
  late AnimationController _scoreAnim;
  late Animation<double> _scoreProgress;

  @override
  void initState() {
    super.initState();
    _scoreAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scoreProgress = Tween<double>(begin: 0, end: 850 / 1000)
        .animate(CurvedAnimation(parent: _scoreAnim, curve: Curves.easeOutCubic));
    // Delay slightly so the screen renders first
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _scoreAnim.forward();
    });
  }

  @override
  void dispose() {
    _scoreAnim.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.w800, color: _textDark)),
        content: const Text('Bạn có chắc muốn đăng xuất khỏi SmartPrice?', style: TextStyle(color: _textGrey)),
        actions: [
          TextButton(
            onPressed: () => WidgetsBinding.instance.addPostFrameCallback(
                (_) => Navigator.pop(context, false)),
            child: const Text('Huy', style: TextStyle(color: _textGrey)),
          ),
          ElevatedButton(
            onPressed: () => WidgetsBinding.instance.addPostFrameCallback(
                (_) => Navigator.pop(context, true)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: _white,
              shape: const StadiumBorder(),
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await AuthService.instance.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: MobileLayout(
        child: CustomScrollView(
          slivers: [
            // ── Header gradient ──────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildHeader()),

            // ── Financial health card ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: _HealthCard(animation: _scoreProgress),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── Smart assistant ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildSection(
                  label: 'TRỢ LÝ THÔNG MINH',
                  child: Column(children: [
                    _ToggleTile(
                      icon: Icons.smart_toy_outlined,
                      iconColor: const Color(0xFF1565C0),
                      title: 'Trợ lý AI nhắc nhở chi tiêu',
                      subtitle: 'Cảnh báo khi vượt ngân sách',
                      value: _aiReminder,
                      onChanged: (v) => setState(() => _aiReminder = v),
                    ),
                    const Divider(height: 1, indent: 56),
                    _ToggleTile(
                      icon: Icons.document_scanner_outlined,
                      iconColor: _teal,
                      title: 'Tự động phân tích hóa đơn OCR',
                      subtitle: 'Nhận diện và phân loại tự động',
                      value: _autoOcr,
                      onChanged: (v) => setState(() => _autoOcr = v),
                    ),
                  ]),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── Appearance ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildSection(
                  label: 'GIAO DIỆN',
                  child: _DarkModeToggle(),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── Account settings ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildSection(
                  label: 'CÀI ĐẶT TÀI KHOẢN',
                  child: Column(children: [
                    _SettingRow(
                      icon: Icons.account_balance_outlined,
                      iconColor: _teal,
                      title: 'Ngân hàng đã liên kết',
                      trailing: _BankLogos(),
                      onTap: () => _showSnack('Ngân hàng đã liên kết'),
                    ),
                    const Divider(height: 1, indent: 56),
                    _SettingRow(
                      icon: Icons.description_outlined,
                      iconColor: const Color(0xFFE65100),
                      title: 'Xuất báo cáo tài chính',
                      onTap: () => _showSnack('Xuất báo cáo'),
                    ),
                    const Divider(height: 1, indent: 56),
                    _SettingRow(
                      icon: Icons.speed_outlined,
                      iconColor: const Color(0xFF1565C0),
                      title: 'Hạn mức chi tiêu tháng',
                      onTap: () => _showSnack('Hạn mức chi tiêu'),
                    ),
                    const Divider(height: 1, indent: 56),
                    _SettingRow(
                      icon: Icons.face_retouching_natural,
                      iconColor: const Color(0xFFC62828),
                      title: 'Bảo mật & FaceID',
                      onTap: () => _showSnack('Bảo mật'),
                    ),
                  ]),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),

            // ── Logout ───────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _LogoutButton(onTap: _logout),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_tealDark, _teal, _cyan],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 32),
      child: Column(children: [
        // Top bar
        Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: _white, size: 20),
            onPressed: () => WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) Navigator.pop(context);
            }),
          ),
          const Expanded(
            child: Text('Cá nhân', textAlign: TextAlign.center,
                style: TextStyle(color: _white, fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: _white, size: 20),
            onPressed: () => WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) _showSnack('Chỉnh sửa thông tin');
            }),
          ),
        ]),
        const SizedBox(height: 20),

        // Avatar with gradient border
        Stack(alignment: Alignment.bottomCenter, children: [
          Container(
            width: 96, height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_white, _cyan],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            padding: const EdgeInsets.all(3),
            child: const CircleAvatar(
              radius: 45,
              backgroundColor: Color(0xFFE0F2F1),
              child: Text('A', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: _teal)),
            ),
          ),
          // Verified badge
          Positioned(
            bottom: 0, right: 0,
            child: Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: _green,
                shape: BoxShape.circle,
                border: Border.all(color: _white, width: 2.5),
              ),
              child: const Icon(Icons.check, color: _white, size: 14),
            ),
          ),
        ]),
        const SizedBox(height: 14),

        // Name
        const Text('Nguyen Van A',
            style: TextStyle(color: _white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        const SizedBox(height: 8),

        // Gold member badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9C4),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.3), blurRadius: 8)],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: const [
            Icon(Icons.star_rounded, color: Color(0xFFF9A825), size: 14),
            SizedBox(width: 4),
            Text('THANH VIEN VANG',
                style: TextStyle(color: Color(0xFFF57F17), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
          ]),
        ),
      ]),
    );
  }

  // ── Section wrapper ─────────────────────────────────────────────────────────
  Widget _buildSection({required String label, required Widget child}) {
    final c = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                letterSpacing: 1.2, color: _textGrey)),
      ),
      Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: c.cardShadow,
        ),
        child: child,
      ),
    ]);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: _teal, duration: const Duration(seconds: 1)),
    );
  }
}

// ── Dark Mode Toggle ──────────────────────────────────────────────────────────
class _DarkModeToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = ThemeProviderScope.of(context);
    final isDark = theme.isDarkMode;

    return GestureDetector(
      onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {
        theme.toggleTheme();
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isDark
              ? LinearGradient(
                  colors: [AppColors.darkSurface, AppColors.darkSurface2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.06),
                    AppColors.neonCyan.withValues(alpha: 0.04),
                  ],
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? AppColors.neonBlue.withValues(alpha: 0.35)
                : AppColors.primary.withValues(alpha: 0.12),
            width: 1.5,
          ),
          boxShadow: isDark
              ? [BoxShadow(color: AppColors.neonBlue.withValues(alpha: 0.12), blurRadius: 16)]
              : null,
        ),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.neonBlue.withValues(alpha: 0.15)
                  : AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
              boxShadow: isDark
                  ? [BoxShadow(color: AppColors.neonBlue.withValues(alpha: 0.28), blurRadius: 10)]
                  : null,
            ),
            child: Icon(
              isDark ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded,
              color: isDark ? AppColors.neonBlue : AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                isDark ? 'Neon Dark Mode' : 'Light Mode',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : _textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isDark ? 'Giao diện tối với hiệu ứng Neon' : 'Giao diện sáng mặc định',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextSecondary : _textGrey,
                ),
              ),
            ]),
          ),
          Switch(
            value: isDark,
            onChanged: (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
              theme.toggleTheme();
            }),
            activeColor: AppColors.neonBlue,
            activeTrackColor: AppColors.neonBlue.withValues(alpha: 0.3),
          ),
        ]),
      ),
    );
  }
}

// ── Financial Health Card ─────────────────────────────────────────────────────
class _HealthCard extends StatelessWidget {
  final Animation<double> animation;
  const _HealthCard({required this.animation});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: c.cardShadow,
      ),
      child: Column(children: [
        // Score ring
        AnimatedBuilder(
          animation: animation,
          builder: (_, __) => SizedBox(
            width: 140, height: 140,
            child: CustomPaint(
              painter: _ScoreRingPainter(progress: animation.value),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    '${(animation.value * 1000).toInt()}',
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: _textDark, letterSpacing: -1),
                  ),
                  const Text('DIEM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _textGrey, letterSpacing: 1)),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Status
        RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 15, color: c.textPrimary, fontWeight: FontWeight.w600),
            children: const [
              TextSpan(text: 'Sức khỏe tài chính: '),
              TextSpan(text: 'Rất tốt', style: TextStyle(color: _green, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text('Bạn đang quản lý chi tiêu rất hiệu quả!',
            style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.4)),
        const SizedBox(height: 16),
        // Stats row
        Row(children: [
          _StatChip(label: 'Tiết kiệm', value: '+12%', color: _green),
          const SizedBox(width: 10),
          _StatChip(label: 'Chi tiêu', value: '-5%', color: _teal),
          const SizedBox(width: 10),
          _StatChip(label: 'Mục tiêu', value: '3/4', color: const Color(0xFF1565C0)),
        ]),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: _textGrey)),
        ]),
      ),
    );
  }
}

// ── Score Ring Painter ────────────────────────────────────────────────────────
class _ScoreRingPainter extends CustomPainter {
  final double progress;
  const _ScoreRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.width - 20) / 2;
    const strokeW = 12.0;
    const startAngle = -math.pi * 0.75;
    const sweepFull = math.pi * 1.5;

    // Background arc
    final bgPaint = Paint()
      ..color = const Color(0xFFECEFF1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      startAngle, sweepFull, false, bgPaint,
    );

    // Progress arc
    final fgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [_cyan, _teal],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      startAngle, sweepFull * progress, false, fgPaint,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) => old.progress != progress;
}

// ── Toggle Tile ───────────────────────────────────────────────────────────────
class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleTile({
    required this.icon, required this.iconColor,
    required this.title, required this.subtitle,
    required this.value, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _textDark)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: _textGrey)),
        ])),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: _cyan,
          activeTrackColor: _cyan.withValues(alpha: 0.3),
        ),
      ]),
    );
  }
}

// ── Setting Row ───────────────────────────────────────────────────────────────
class _SettingRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _SettingRow({
    required this.icon, required this.iconColor, required this.title,
    this.trailing, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        // addPostFrameCallback avoids mouse_tracker assertion on Windows
        onTap: onTap == null
            ? null
            : () => WidgetsBinding.instance.addPostFrameCallback((_) => onTap!()),
        splashColor: _teal.withValues(alpha: 0.08),
        highlightColor: _teal.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textDark))),
            if (trailing != null) trailing!
            else const Icon(Icons.chevron_right, color: _textGrey, size: 20),
          ]),
        ),
      ),
    );
  }
}

// ── Bank Logos ────────────────────────────────────────────────────────────────
class _BankLogos extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _BankDot(color: const Color(0xFF1B5E20), label: 'VCB'),
      const SizedBox(width: 4),
      _BankDot(color: const Color(0xFFAD1457), label: 'MM'),
      const SizedBox(width: 8),
      const Icon(Icons.chevron_right, color: _textGrey, size: 20),
    ]);
  }
}

class _BankDot extends StatelessWidget {
  final Color color;
  final String label;
  const _BankDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(child: Text(label, style: const TextStyle(color: _white, fontSize: 7, fontWeight: FontWeight.w800))),
    );
  }
}

// ── Logout Button ─────────────────────────────────────────────────────────────
class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) => onTap()),
        borderRadius: BorderRadius.circular(20),
        splashColor: Colors.red.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: c.cardShadow,
          ),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.logout_rounded, color: Colors.red, size: 20),
            SizedBox(width: 10),
            Text('Đăng xuất', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.red)),
          ]),
        ),
      ),
    );
  }
}
