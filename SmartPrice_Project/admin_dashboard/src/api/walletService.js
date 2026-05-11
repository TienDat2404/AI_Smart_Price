import api from './axiosInstance'

/**
 * walletService — quản lý số dư ví người dùng.
 */
export const walletService = {
  /**
   * GET /api/wallet/balance?userId=user_01
   * Trả về { balance, totalIncome, totalExpense, monthBalance, ... }
   */
  async getBalance(userId = 'user_01') {
    const { data } = await api.get('/wallet/balance', { params: { userId } })
    return data
  },

  /**
   * POST /api/wallet/deposit — nạp tiền vào ví
   */
  async deposit(userId, amount, note) {
    const { data } = await api.post('/wallet/deposit', { userId, amount, note })
    return data
  },
}

/**
 * Định dạng số tiền VNĐ: 10500000 → "10.500.000 VNĐ"
 */
export function formatVND(amount) {
  if (amount == null || isNaN(amount)) return '0 VNĐ'
  return Math.round(amount).toLocaleString('vi-VN') + ' VNĐ'
}

/**
 * Định dạng ngắn gọn: 10500000 → "10.5M" hoặc "10.500k"
 */
export function formatVNDShort(amount) {
  if (amount == null || isNaN(amount)) return '0'
  if (Math.abs(amount) >= 1_000_000) {
    return (amount / 1_000_000).toFixed(1) + 'M VNĐ'
  }
  if (Math.abs(amount) >= 1_000) {
    return (amount / 1_000).toFixed(0) + 'k VNĐ'
  }
  return amount.toLocaleString('vi-VN') + ' VNĐ'
}
