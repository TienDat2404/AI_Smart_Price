import api from './axiosInstance'

/**
 * adminService — tất cả API calls cho Admin Dashboard.
 * Mỗi method trả về data đã unwrap (không cần .data ở component).
 */
export const adminService = {

  // ── Overview ───────────────────────────────────────────────────────────────

  /** GET /api/admin/overview → AdminOverviewDto */
  async getOverview() {
    const { data } = await api.get('/admin/overview')
    return data
  },

  /**
   * GET /api/admin/chart?months=6|12 → MonthlyChartPointDto[]
   * Trả về mảng { month, income, expense, transactions }
   */
  async getChartData(months = 6) {
    const { data } = await api.get('/admin/chart', { params: { months } })
    return data
  },

  // ── Users ──────────────────────────────────────────────────────────────────

  /**
   * GET /api/admin/users → { data: AdminUserDto[], total, page, limit }
   * @param {{ search?, status?, page?, limit? }} params
   */
  async getUsers(params = {}) {
    const { data } = await api.get('/admin/users', { params })
    return data
  },

  /**
   * PATCH /api/admin/users/{id}/toggle-lock → { isActive: bool }
   */
  async toggleUserLock(userId) {
    const { data } = await api.patch(`/admin/users/${userId}/toggle-lock`)
    return data
  },

  // ── Transactions ───────────────────────────────────────────────────────────

  /**
   * GET /api/admin/transactions → { data: AdminTransactionDto[], total, page, limit }
   * @param {{ search?, type?, page?, limit? }} params
   */
  async getTransactions(params = {}) {
    const { data } = await api.get('/admin/transactions', { params })
    return data
  },

  /** GET /api/admin/transactions/stats → TransactionStatsDto */
  async getTransactionStats() {
    const { data } = await api.get('/admin/transactions/stats')
    return data
  },

  // ── OCR Logs ───────────────────────────────────────────────────────────────

  /** GET /api/admin/ocr-logs?limit=20 → OcrLogDto[] */
  async getOcrLogs(limit = 20) {
    const { data } = await api.get('/admin/ocr-logs', { params: { limit } })
    return data
  },

  // ── Notifications ──────────────────────────────────────────────────────────

  /**
   * POST /api/admin/notifications → NotificationHistoryDto
   * @param {{ title: string, body: string, target: string }} payload
   */
  async sendNotification(payload) {
    const { data } = await api.post('/admin/notifications', payload)
    return data
  },

  /** GET /api/admin/notifications → NotificationHistoryDto[] */
  async getNotificationHistory() {
    const { data } = await api.get('/admin/notifications')
    return data
  },
}
