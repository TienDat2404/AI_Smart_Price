import 'package:flutter/material.dart';
import '../../core/models/transaction.dart';
import '../../core/services/api_service.dart';
import '../../core/services/current_user.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/mobile_layout.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  late Future<List<Transaction>> _future;
  String _selectedCategory = 'Tất cả';

  static const List<String> _categories = [
    'Tất cả',
    'Ăn uống',
    'Di chuyển',
    'Mua sắm',
    'Giải trí',
    'Sức khỏe',
    'Hóa đơn',
    'Thu nhập',
  ];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final uid = await CurrentUser.id;
    if (mounted) setState(() { _future = ApiService.instance.getTransactions(uid); });
  }

  void _refresh() {
    _loadTransactions();
  }

  List<Transaction> _applyFilter(List<Transaction> all) {
    if (_selectedCategory == 'Tất cả') return all;
    return all.where((t) => t.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Lịch sử giao dịch',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.primary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => WidgetsBinding.instance.addPostFrameCallback((_) => _refresh()),
          ),
        ],
      ),
      body: MobileLayout(
        child: Column(
          children: [
            // ── Bộ lọc hạng mục ─────────────────────────────────────────
            _CategoryFilter(
              categories: _categories,
              selected: _selectedCategory,
              onChanged: (cat) => setState(() => _selectedCategory = cat),
            ),

            // ── Danh sách giao dịch ──────────────────────────────────────
            Expanded(
              child: FutureBuilder<List<Transaction>>(
                future: _future,
                builder: (context, snapshot) {
                  // ── Loading ────────────────────────────────────────────
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.neonCyan,
                      ),
                    );
                  }

                  // ── Error ──────────────────────────────────────────────
                  if (snapshot.hasError) {
                    return _ErrorView(
                      error: snapshot.error.toString(),
                      onRetry: _refresh,
                    );
                  }

                  // ── Empty ──────────────────────────────────────────────
                  final filtered = _applyFilter(snapshot.data ?? []);
                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 56,
                            color: AppColors.textSecondary.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _selectedCategory == 'Tất cả'
                                ? 'Chưa có giao dịch nào.'
                                : 'Không có giao dịch "$_selectedCategory".',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // ── Data — ListView.builder ────────────────────────────
                  return RefreshIndicator(
                    color: AppColors.neonCyan,
                    onRefresh: () async {
                      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final t = filtered[index];

                        // Hiển thị header ngày nếu khác ngày trước
                        final showDateHeader = index == 0 ||
                            !_isSameDay(
                              filtered[index - 1].date,
                              t.date,
                            );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showDateHeader)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 16,
                                  bottom: 6,
                                ),
                                child: Text(
                                  _formatDateHeader(t.date),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            _TransactionCard(transaction: t),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(date.year, date.month, date.day))
        .inDays;

    if (diff == 0) return 'HÔM NAY';
    if (diff == 1) return 'HÔM QUA';

    const weekdays = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
    return '${weekdays[date.weekday % 7]}, ${date.day}/${date.month}/${date.year}';
  }
}

// ── Transaction Card ──────────────────────────────────────────────────────────

class _TransactionCard extends StatelessWidget {
  final Transaction transaction;

  const _TransactionCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // ── Icon hạng mục ──────────────────────────────────────────
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.neonCyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _categoryIcon(t.category),
                color: AppColors.primary,
                size: 22,
              ),
            ),

            const SizedBox(width: 12),

            // ── Tên + hạng mục ─────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.itemName.isNotEmpty ? t.itemName : t.category,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      // Badge hạng mục
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.neonCyan.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          t.category,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (t.note.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            t.note,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ── Số tiền ────────────────────────────────────────────────
            Text(
              '${t.isExpense ? '-' : '+'}${_formatAmount(t.amount)} đ',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: t.isExpense ? AppColors.expense : AppColors.income,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Ăn uống':   return Icons.restaurant;
      case 'Di chuyển': return Icons.directions_bike;
      case 'Mua sắm':   return Icons.shopping_bag;
      case 'Giải trí':  return Icons.movie;
      case 'Sức khỏe':  return Icons.local_hospital;
      case 'Hóa đơn':   return Icons.receipt;
      case 'Thu nhập':  return Icons.account_balance_wallet;
      default:          return Icons.attach_money;
    }
  }

  String _formatAmount(double amount) {
    final parts = amount.toStringAsFixed(0).split('');
    final buffer = StringBuffer();
    for (int i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) buffer.write('.');
      buffer.write(parts[i]);
    }
    return buffer.toString();
  }
}

// ── Category Filter ───────────────────────────────────────────────────────────

class _CategoryFilter extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onChanged;

  const _CategoryFilter({
    required this.categories,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = cat == selected;
          return GestureDetector(
            onTap: () => WidgetsBinding.instance.addPostFrameCallback((_) => onChanged(cat)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.inputBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                cat,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Error View ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    // Hiển thị thông báo lỗi thân thiện + chi tiết kỹ thuật
    final isNetworkError = error.contains('SocketException') ||
        error.contains('Connection refused') ||
        error.contains('TimeoutException');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isNetworkError ? Icons.wifi_off_rounded : Icons.error_outline,
              color: AppColors.alert,
              size: 52,
            ),
            const SizedBox(height: 16),
            Text(
              isNetworkError
                  ? 'Không thể kết nối đến server'
                  : 'Đã xảy ra lỗi',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isNetworkError
                  ? 'Kiểm tra backend đang chạy tại\nhttp://10.0.2.2:5148/api'
                  : error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => WidgetsBinding.instance.addPostFrameCallback((_) => onRetry()),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}
