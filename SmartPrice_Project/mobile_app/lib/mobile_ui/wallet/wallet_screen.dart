import 'package:flutter/material.dart';
import '../../core/models/transaction.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/theme_ext.dart';
import '../../core/widgets/mobile_layout.dart';
import 'edit_wallet_screen.dart';
import 'linked_banks_screen.dart';
import 'transfer_screen.dart';
import 'wallet_model.dart';
import 'wallet_report_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _teal      = Color(0xFF00897B);
const _tealDark  = Color(0xFF00695C);
const _tealLight = Color(0xFFE0F2F1);
const _bg        = Color(0xFFF5F7FA);
const _textDark  = Color(0xFF1A2340);
const _textGrey  = Color(0xFF8A94A6);
const _red       = Color(0xFFE53935);
const _green     = Color(0xFF43A047);

const _sparkline = [0.6, 0.4, 0.7, 0.5, 0.8, 0.65, 0.9];

// ── WalletScreen ──────────────────────────────────────────────────────────────
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  double get _totalBalance => mockWallets.fold(0.0, (s, w) => s + w.balance);

  List<Transaction> _transactions = [];
  bool _loadingTx = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadBankBalance(), _loadTransactions()]);
  }

  /// Load số dư thực từ API → cập nhật mockWallets[0] (MB Bank)
  Future<void> _loadBankBalance() async {
    try {
      final data = await ApiService.instance.getBankBalance('user_01');
      final hasBankLink = data['hasBankLink'] as bool? ?? false;
      if (hasBankLink && mounted) {
        final balance = (data['balance'] as num?)?.toDouble() ?? 0.0;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => mockWallets[0].balance = balance);
        });
      }
    } catch (_) {}
  }

  /// Load giao dịch thực từ API
  Future<void> _loadTransactions() async {
    try {
      final txs = await ApiService.instance.getTransactions('user_01');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() { _transactions = txs; _loadingTx = false; });
      });
    } catch (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _loadingTx = false);
      });
    }
  }

  void _refreshOnReturn() => _loadAll();


  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: MobileLayout(
        child: CustomScrollView(
          slivers: [
            // Header gradient với tổng tài sản
            SliverToBoxAdapter(child: _HeaderCard(totalBalance: _totalBalance)),

            // Quick actions — truyền callback để refresh sau khi pop
            SliverToBoxAdapter(child: _QuickActions(onReturn: _refreshOnReturn)),

            // Wallets section
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Text('Tài khoản của bạn',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textDark)),
              ),
            ),
            SliverToBoxAdapter(child: _WalletsSection()),

            // Recent transactions header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Lịch sử giao dịch',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textDark)),
                    GestureDetector(
                      onTap: () {},
                      child: const Text('Xem tất cả',
                          style: TextStyle(fontSize: 13, color: _teal, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),

            // Recent transactions — thực từ API
            if (_loadingTx)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator(color: _teal)),
                ),
              )
            else if (_transactions.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text('Chưa có giao dịch nào.',
                        style: TextStyle(color: _textGrey, fontSize: 14)),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _TxItem(tx: _transactions[i]),
                  childCount: _transactions.length > 10 ? 10 : _transactions.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

// ── Header Card ───────────────────────────────────────────────────────────────
class _HeaderCard extends StatelessWidget {
  final double totalBalance;
  const _HeaderCard({required this.totalBalance});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF004D40), _teal, Color(0xFF26A69A)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top bar
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          GestureDetector(
            onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) Navigator.of(context).pop();
            }),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
            ),
          ),
          const Text('Ví của tôi',
              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
          Row(children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
              onPressed: () {},
            ),
            const CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              child: Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ]),
        ]),

        const SizedBox(height: 16),

        // Total balance + sparkline
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Tổng tài sản',
                  style: TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 4),
              Text('${_fmt(totalBalance)} d',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 28,
                      fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.trending_up, color: Color(0xFF80CBC4), size: 14),
                  SizedBox(width: 4),
                  Text('+2.4% tháng này',
                      style: TextStyle(color: Color(0xFF80CBC4), fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
          ),
          SizedBox(
            width: 100, height: 50,
            child: CustomPaint(painter: _SparklinePainter()),
          ),
        ]),
      ]),
    );
  }
}

// ── Sparkline Painter ─────────────────────────────────────────────────────────
class _SparklinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pts   = _sparkline;
    final paint = Paint()
      ..color      = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 2
      ..style      = PaintingStyle.stroke
      ..strokeCap  = StrokeCap.round;

    final path = Path();
    for (int i = 0; i < pts.length; i++) {
      final x = size.width * i / (pts.length - 1);
      final y = size.height * (1 - pts[i]);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.1)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => false;
}

// ── Quick Actions ─────────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  /// Callback để WalletScreen rebuild sau khi pop từ sub-screen
  final VoidCallback onReturn;
  const _QuickActions({required this.onReturn});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      color: c.card,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _ActionBtn(
          icon: Icons.account_balance,
          label: 'Ngân hàng',
          color: const Color(0xFF00897B),
          onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) =>
                    const LinkedBanksScreen(userId: 'user_01'),
                transitionDuration: const Duration(milliseconds: 320),
                transitionsBuilder: (_, anim, __, child) => SlideTransition(
                  position: Tween<Offset>(
                          begin: const Offset(1, 0), end: Offset.zero)
                      .animate(CurvedAnimation(
                          parent: anim, curve: Curves.easeOutCubic)),
                  child: child,
                ),
              ),
            ).then((_) => onReturn());
          }),
        ),
        _ActionBtn(
          icon: Icons.swap_horiz_rounded,
          label: 'Chuyển tiền',
          color: _teal,
          onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const TransferScreen(),
                transitionDuration: const Duration(milliseconds: 320),
                transitionsBuilder: (_, anim, __, child) => SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                      .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                  child: child,
                ),
              ),
            ).then((_) => onReturn()); // ✅ Rebuild sau khi pop
          }),
        ),
        _ActionBtn(
          icon: Icons.edit_outlined,
          label: 'Chỉnh sửa',
          color: const Color(0xFF7C4DFF),
          onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => EditWalletScreen(
                  wallet: WalletData(
                    name:    mockWallets[0].name,
                    balance: mockWallets[0].balance, // luôn đọc balance mới nhất
                    icon:    mockWallets[0].icon,
                  ),
                ),
                transitionDuration: const Duration(milliseconds: 320),
                transitionsBuilder: (_, anim, __, child) => SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                      .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                  child: child,
                ),
              ),
            ).then((_) => onReturn()); // ✅ Rebuild sau khi pop
          }),
        ),
        _ActionBtn(
          icon: Icons.bar_chart_rounded,
          label: 'Báo cáo',
          color: const Color(0xFFFF9800),
          onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => WalletReportScreen(wallet: mockWallets[0]),
                transitionDuration: const Duration(milliseconds: 320),
                transitionsBuilder: (_, anim, __, child) => SlideTransition(
                  position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                      .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                  child: child,
                ),
              ),
            );
          }),
        ),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.icon, required this.label,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) => onTap()),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(fontSize: 11, color: _textGrey, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ── Wallets Section ───────────────────────────────────────────────────────────
class _WalletsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        _MainWalletCard(wallet: mockWallets[0]),
        // Chỉ hiện thêm ví phụ nếu có nhiều hơn 1
        if (mockWallets.length > 1) ...[
          const SizedBox(height: 12),
          Row(children: [
            for (int i = 1; i < mockWallets.length && i <= 2; i++) ...[
              if (i > 1) const SizedBox(width: 12),
              Expanded(child: _SmallWalletCard(wallet: mockWallets[i])),
            ],
          ]),
        ],
      ]),
    );
  }
}

class _MainWalletCard extends StatelessWidget {
  final WalletModel wallet;
  const _MainWalletCard({required this.wallet});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: wallet.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: wallet.color.withValues(alpha: 0.3),
          blurRadius: 16, offset: const Offset(0, 6),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(wallet.icon, color: wallet.textColor, size: 20),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(wallet.name,
                  style: TextStyle(color: wallet.textColor, fontSize: 14, fontWeight: FontWeight.w700)),
              Text(wallet.subtitle,
                  style: TextStyle(color: wallet.textColor.withValues(alpha: 0.6), fontSize: 11)),
            ]),
          ]),
          Icon(Icons.more_horiz, color: wallet.textColor.withValues(alpha: 0.6)),
        ]),
        const SizedBox(height: 20),
        Text('Số dư', style: TextStyle(color: wallet.textColor.withValues(alpha: 0.6), fontSize: 12)),
        const SizedBox(height: 4),
        Text('${_fmt(wallet.balance)} d',
            style: TextStyle(
                color: wallet.textColor, fontSize: 22,
                fontWeight: FontWeight.w900, letterSpacing: -0.5)),
      ]),
    );
  }
}

class _SmallWalletCard extends StatelessWidget {
  final WalletModel wallet;
  const _SmallWalletCard({required this.wallet});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: wallet.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 8, offset: const Offset(0, 3),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Icon(wallet.icon, color: wallet.textColor, size: 22),
          Icon(Icons.more_horiz, color: wallet.textColor.withValues(alpha: 0.5), size: 18),
        ]),
        const SizedBox(height: 12),
        Text(wallet.name,
            style: TextStyle(color: wallet.textColor, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('${_fmt(wallet.balance)} d',
            style: TextStyle(color: wallet.textColor, fontSize: 14, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

// ── Transaction Item — dùng Transaction thực từ API (giống trang chủ) ─────────
class _TxItem extends StatelessWidget {
  final Transaction tx;
  const _TxItem({required this.tx});

  IconData _icon(String cat) {
    switch (cat) {
      case 'Ăn uống': case 'An uong':     return Icons.restaurant;
      case 'Di chuyển': case 'Di chuyen': return Icons.directions_bike;
      case 'Mua sắm': case 'Mua sam':     return Icons.shopping_bag_outlined;
      case 'Giải trí': case 'Giai tri':   return Icons.play_circle_outline;
      case 'Sức khỏe': case 'Suc khoe':   return Icons.local_hospital;
      case 'Thu nhập': case 'Thu nhap':   return Icons.account_balance_wallet;
      case 'Hóa đơn': case 'Hoa don':     return Icons.receipt_long;
      case 'Chuyển khoản':                return Icons.swap_horiz;
      default:                            return Icons.attach_money;
    }
  }

  Color _iconBg(String cat, bool isExpense) {
    if (!isExpense) return const Color(0xFFE0F2F1);
    switch (cat) {
      case 'Ăn uống': case 'An uong':     return const Color(0xFFFFF3E0);
      case 'Di chuyển': case 'Di chuyen': return const Color(0xFFE8F5E9);
      case 'Mua sắm': case 'Mua sam':     return const Color(0xFFFFF3E0);
      case 'Giải trí': case 'Giai tri':   return const Color(0xFFFFEBEE);
      case 'Sức khỏe': case 'Suc khoe':   return const Color(0xFFE3F2FD);
      case 'Hóa đơn': case 'Hoa don':     return const Color(0xFFF3E5F5);
      default:                            return const Color(0xFFF5F5F5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final now  = DateTime.now();
    final diff = now.difference(tx.date).inDays;
    final timeStr = diff == 0 ? 'Hôm nay'
                  : diff == 1 ? 'Hôm qua'
                  : '${tx.date.day}/${tx.date.month}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: c.cardShadow,
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: _iconBg(tx.category, tx.isExpense),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon(tx.category), size: 20,
                color: tx.isExpense ? c.textPrimary : _teal),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              tx.itemName.isNotEmpty ? tx.itemName : tx.category,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
            Text(
              '$timeStr · ${tx.category}',
              style: TextStyle(fontSize: 11, color: c.textSecondary),
            ),
          ])),
          Text(
            '${tx.isExpense ? '-' : '+'}${_fmt(tx.amount)} d',
            style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: tx.isExpense ? c.red : c.green,
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Helper ────────────────────────────────────────────────────────────────────
String _fmt(double v) {
  final parts = v.toStringAsFixed(0).split('');
  final buf   = StringBuffer();
  for (int i = 0; i < parts.length; i++) {
    if (i > 0 && (parts.length - i) % 3 == 0) buf.write('.');
    buf.write(parts[i]);
  }
  return buf.toString();
}
