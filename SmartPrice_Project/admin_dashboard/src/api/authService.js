import api from './axiosInstance'

/**
 * authService — xử lý đăng nhập / đăng xuất Admin.
 *
 * Backend endpoint: POST /api/users/login
 * Response: { token, userId, name, email, isAdmin }
 */

export const authService = {
  /**
   * Đăng nhập — lưu token + user vào localStorage.
   * @returns {{ token, userId, name, email, isAdmin }}
   */
  async login(email, password) {
    const { data } = await api.post('/users/login', { email, password })

    if (!data.isAdmin) {
      throw new Error('Tài khoản này không có quyền Admin.')
    }

    localStorage.setItem('admin_token', data.token)
    localStorage.setItem('admin_user', JSON.stringify({
      userId: data.userId,
      name:   data.name,
      email:  data.email,
    }))

    return data
  },

  /** Đăng xuất — xóa session. */
  logout() {
    localStorage.removeItem('admin_token')
    localStorage.removeItem('admin_user')
  },

  /** Lấy user hiện tại từ localStorage. */
  getCurrentUser() {
    try {
      const raw = localStorage.getItem('admin_user')
      return raw ? JSON.parse(raw) : null
    } catch {
      return null
    }
  },

  /** Kiểm tra đã đăng nhập chưa. */
  isAuthenticated() {
    return !!localStorage.getItem('admin_token')
  },
}
