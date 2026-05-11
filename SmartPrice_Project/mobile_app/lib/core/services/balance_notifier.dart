import 'package:flutter/foundation.dart';
import 'package:mobile_app/mobile_ui/wallet/wallet_model.dart';

/// Global notifier — khi có giao dịch mới được lưu,
/// trừ số tiền vào mockWallets và notify listeners.
///
/// Dashboard lắng nghe notifier này để rebuild balance card ngay lập tức
/// mà không cần gọi lại API.
class BalanceNotifier extends ChangeNotifier {
  BalanceNotifier._();
  static final BalanceNotifier instance = BalanceNotifier._();

  /// Tổng tài sản hiện tại (tính từ mockWallets)
  double get totalBalance => mockWallets.fold(0.0, (s, w) => s + w.balance);

  /// Gọi sau khi lưu giao dịch thành công.
  /// [amount] — số tiền giao dịch (dương)
  /// [isExpense] — true = chi tiêu (trừ), false = thu nhập (cộng)
  /// [walletIndex] — index ví bị ảnh hưởng (mặc định 0 = Vietcombank)
  void applyTransaction({
    required double amount,
    required bool isExpense,
    int walletIndex = 0,
  }) {
    if (walletIndex < 0 || walletIndex >= mockWallets.length) return;
    if (isExpense) {
      mockWallets[walletIndex].balance -= amount;
    } else {
      mockWallets[walletIndex].balance += amount;
    }
    notifyListeners();
  }

  /// Reset về giá trị ban đầu (dùng khi logout)
  void reset() {
    mockWallets[0].balance = 84200000;
    mockWallets[1].balance = 12500000;
    mockWallets[2].balance = 29050000;
    notifyListeners();
  }
}
