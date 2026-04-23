import 'package:flutter/material.dart';
import '../../core/data/mock_data.dart';
import '../../core/models/transaction.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/mobile_layout.dart';
import '../../core/widgets/neon_line_painter.dart';
import 'widgets/balance_card.dart';
import 'widgets/recent_transactions.dart';

/// Dữ liệu tổng hợp cho Dashboard — load một lần duy nhất.
class _DashboardData {
  final List<Transaction> transactions;
  final double balance;

  const _DashboardData({
    required this.transactions,
    required this.balance,
  });
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Future được khởi tạo một lần trong initState để tránh rebuild liên tục.
  late final Future<_DashboardData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_DashboardData> _loadData() async {
    // Gọi song song để nhanh hơn
    final results = await Future.wait([
      MockData.fetchTransactions(),
      MockData.fetchBalance(),
    ]);
    return _DashboardData(
      transactions: results[0] as List<Transaction>,
      balance: results[1] as double,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: MobileLayout(
        child: SafeArea(
          child: FutureBuilder<_DashboardData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            // ── Loading ──────────────────────────────────────────────────
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.neonCyan),
              );
            }

            // ── Error ────────────────────────────────────────────────────
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.alert, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Không thể tải dữ liệu\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              );
            }

            // ── Data ─────────────────────────────────────────────────────
            final data = snapshot.data!;

            // Tính tổng chi tiêu 7 ngày để truyền vào NeonLinePainter
            final dailyTotals = NeonLinePainter.buildDailyTotals(
              data.transactions,
              days: 7,
            );

            return RefreshIndicator(
              color: AppColors.neonCyan,
              onRefresh: () async {
                // TODO: Thay bằng ApiService khi backend sẵn sàng
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),

                    // ── Header ───────────────────────────────────────────
                    _buildHeader(),

                    const SizedBox(height: 20),

                    // ── Smart Input Bar ──────────────────────────────────
                    _buildSmartInputBar(context),

                    const SizedBox(height: 24),

                    // ── Balance Card + Biểu đồ 7 ngày ───────────────────
                    // dailyTotals được tính từ transactions thực tế
                    // và truyền thẳng vào NeonLinePainter bên trong BalanceCard
                    BalanceCard(
                      balance: data.balance,
                      dailyTotals: dailyTotals,
                    ),

                    const SizedBox(height: 28),

                    // ── Recent Transactions ──────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Giao dịch gần đây',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // TODO: Navigate to TransactionHistoryScreen
                          },
                          child: const Text(
                            'Xem tất cả',
                            style: TextStyle(color: AppColors.neonCyan),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    RecentTransactions(transactions: data.transactions),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),

      // ── Bottom Nav (placeholder) ─────────────────────────────────────────
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chào bạn,',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            Text(
              'Nguyễn Văn A',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.neonCyan.withValues(alpha: 0.15),
          child: const Icon(Icons.person, color: AppColors.primary),
        ),
      ],
    );
  }

  Widget _buildSmartInputBar(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // TODO: Navigate to SmartInputScreen
      },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.inputBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  "Hôm nay bạn chi gì? 'Ăn phở 50k'",
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.neonCyan],
                ),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondary,
      currentIndex: 0,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Nhập'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), label: 'Phân tích'),
        BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Ngân sách'),
        BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Cài đặt'),
      ],
    );
  }
}
