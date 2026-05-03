import axios from 'axios'

// ── Base URL ──────────────────────────────────────────────────────────────────
// Đọc từ .env (VITE_API_URL) hoặc fallback về localhost:5261
const BASE_URL = import.meta.env.VITE_API_URL ?? 'http://127.0.0.1:5261/api'

const api = axios.create({
  baseURL: BASE_URL,
  timeout: 15000,
  headers: { 'Content-Type': 'application/json' },
})

// ── Request interceptor — đính kèm JWT token ─────────────────────────────────
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('admin_token')
    if (token) {
      config.headers.Authorization = `Bearer ${token}`
    }
    return config
  },
  (error) => Promise.reject(error)
)

// ── Response interceptor — xử lý lỗi tập trung ───────────────────────────────
api.interceptors.response.use(
  (response) => response,
  (error) => {
    const status = error.response?.status

    if (status === 401) {
      // Token hết hạn hoặc không hợp lệ → xóa session và redirect về login
      localStorage.removeItem('admin_token')
      localStorage.removeItem('admin_user')
      window.location.href = '/login'
    }

    if (status === 403) {
      console.error('[API] Forbidden — không đủ quyền Admin')
    }

    // Chuẩn hóa error message
    const message =
      error.response?.data?.message ??
      error.response?.data?.title ??
      error.message ??
      'Lỗi không xác định'

    return Promise.reject(new Error(message))
  }
)

export default api
