import '../models/transaction.dart';
import '../models/budget.dart';

/// Dữ liệu giả dùng trong quá trình phát triển UI.
/// Thay thế bằng ApiService khi backend sẵn sàng.
class MockData {
  MockData._();

  static final DateTime _today = DateTime.now();

  // ── Transactions ──────────────────────────────────────────────────────────

  /// 14 giao dịch trải đều trong 7 ngày gần nhất.
  static List<Transaction> get transactions => [
        // Ngày -6
        Transaction(
          id: 't1',
          userId: 'user_01',
          amount: 45000,
          category: 'Ăn uống',
          note: 'Phở bò buổi sáng',
          date: _today.subtract(const Duration(days: 6)),
          isExpense: true,
        ),
        Transaction(
          id: 't2',
          userId: 'user_01',
          amount: 25000,
          category: 'Di chuyển',
          note: 'Grab đi làm',
          date: _today.subtract(const Duration(days: 6)),
          isExpense: true,
        ),
        // Ngày -5
        Transaction(
          id: 't3',
          userId: 'user_01',
          amount: 120000,
          category: 'Mua sắm',
          note: 'Siêu thị VinMart',
          date: _today.subtract(const Duration(days: 5)),
          isExpense: true,
        ),
        Transaction(
          id: 't4',
          userId: 'user_01',
          amount: 5000000,
          category: 'Thu nhập',
          note: 'Lương tháng',
          date: _today.subtract(const Duration(days: 5)),
          isExpense: false,
        ),
        // Ngày -4
        Transaction(
          id: 't5',
          userId: 'user_01',
          amount: 85000,
          category: 'Ăn uống',
          note: 'Cơm văn phòng + trà sữa',
          date: _today.subtract(const Duration(days: 4)),
          isExpense: true,
        ),
        Transaction(
          id: 't6',
          userId: 'user_01',
          amount: 200000,
          category: 'Giải trí',
          note: 'Xem phim CGV',
          date: _today.subtract(const Duration(days: 4)),
          isExpense: true,
        ),
        // Ngày -3
        Transaction(
          id: 't7',
          userId: 'user_01',
          amount: 60000,
          category: 'Ăn uống',
          note: 'Bún bò Huế',
          date: _today.subtract(const Duration(days: 3)),
          isExpense: true,
        ),
        Transaction(
          id: 't8',
          userId: 'user_01',
          amount: 350000,
          category: 'Sức khỏe',
          note: 'Khám bác sĩ',
          date: _today.subtract(const Duration(days: 3)),
          isExpense: true,
        ),
        // Ngày -2
        Transaction(
          id: 't9',
          userId: 'user_01',
          amount: 50000,
          category: 'Di chuyển',
          note: 'Đổ xăng xe máy',
          date: _today.subtract(const Duration(days: 2)),
          isExpense: true,
        ),
        Transaction(
          id: 't10',
          userId: 'user_01',
          amount: 500000,
          category: 'Thu nhập',
          note: 'Freelance thiết kế',
          date: _today.subtract(const Duration(days: 2)),
          isExpense: false,
        ),
        // Ngày -1
        Transaction(
          id: 't11',
          userId: 'user_01',
          amount: 75000,
          category: 'Ăn uống',
          note: 'Lẩu với bạn bè',
          date: _today.subtract(const Duration(days: 1)),
          isExpense: true,
        ),
        Transaction(
          id: 't12',
          userId: 'user_01',
          amount: 180000,
          category: 'Mua sắm',
          note: 'Quần áo sale',
          date: _today.subtract(const Duration(days: 1)),
          isExpense: true,
        ),
        // Hôm nay
        Transaction(
          id: 't13',
          userId: 'user_01',
          amount: 35000,
          category: 'Ăn uống',
          note: 'Bánh mì ốp la',
          date: _today,
          isExpense: true,
        ),
        Transaction(
          id: 't14',
          userId: 'user_01',
          amount: 30000,
          category: 'Di chuyển',
          note: 'Grab về nhà',
          date: _today,
          isExpense: true,
        ),
      ];

  // ── Budgets ───────────────────────────────────────────────────────────────

  static List<Budget> get budgets => [
        Budget(
          id: 'b1',
          userId: 'user_01',
          category: 'Ăn uống',
          limit: 2000000,
          spent: 1750000, // 87.5% → cảnh báo đỏ
        ),
        Budget(
          id: 'b2',
          userId: 'user_01',
          category: 'Di chuyển',
          limit: 500000,
          spent: 200000, // 40%
        ),
        Budget(
          id: 'b3',
          userId: 'user_01',
          category: 'Mua sắm',
          limit: 1000000,
          spent: 820000, // 82% → cảnh báo đỏ
        ),
        Budget(
          id: 'b4',
          userId: 'user_01',
          category: 'Giải trí',
          limit: 600000,
          spent: 200000, // 33%
        ),
        Budget(
          id: 'b5',
          userId: 'user_01',
          category: 'Sức khỏe',
          limit: 500000,
          spent: 350000, // 70%
        ),
      ];

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Tổng số dư = tổng thu nhập - tổng chi tiêu.
  static double get totalBalance {
    return transactions.fold(0.0, (sum, t) {
      return sum + (t.isExpense ? -t.amount : t.amount);
    });
  }

  /// Giả lập độ trễ mạng (200ms) để FutureBuilder hoạt động thực tế hơn.
  static Future<List<Transaction>> fetchTransactions() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return transactions;
  }

  static Future<List<Budget>> fetchBudgets() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return budgets;
  }

  static Future<double> fetchBalance() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return totalBalance;
  }
}
