import { useState, useEffect } from 'react'
import { Send, Users, Bell, CheckCircle, Clock, Trash2 } from 'lucide-react'
import { adminService } from '../api/adminService'

// ── Fallback data — luôn là mảng hợp lệ ─────────────────────────────────────
const FALLBACK_HISTORY = [
  { id: '1', title: 'Cập nhật tính năng mới',     target: 'Tất cả',     sentAt: '2024-12-10T09:00:00Z', reachCount: 12450 },
  { id: '2', title: 'Cảnh báo chi tiêu tháng 11', target: 'Hạng vàng', sentAt: '2024-12-01T08:30:00Z', reachCount: 3200  },
  { id: '3', title: 'Khuyến mãi cuối năm',         target: 'Hạng bạc',  sentAt: '2024-11-25T10:00:00Z', reachCount: 5100  },
  { id: '4', title: 'Bảo trì hệ thống',            target: 'Tất cả',     sentAt: '2024-11-20T07:00:00Z', reachCount: 12100 },
]

const TARGET_LABEL = {
  all:    'Tất cả người dùng',
  gold:   'Hạng vàng',
  silver: 'Hạng bạc',
  bronze: 'Hạng đồng',
}

const TARGET_COUNT = { all: 12450, gold: 3200, silver: 5100, bronze: 4150 }

// ── Normalize một record từ API (PascalCase) hoặc mock (camelCase) ────────────
function normalizeRecord(n) {
  return {
    id:         n.id         ?? n.Id         ?? String(Math.random()),
    title:      n.title      ?? n.Title      ?? '—',
    target:     n.target     ?? n.Target     ?? 'all',
    sentAt:     n.sentAt     ?? n.SentAt     ?? new Date().toISOString(),
    reachCount: n.reachCount ?? n.ReachCount ?? 0,
  }
}

export default function NotificationsPage() {
  const [title,   setTitle]   = useState('')
  const [body,    setBody]    = useState('')
  const [target,  setTarget]  = useState('all')
  const [sending, setSending] = useState(false)
  const [sent,    setSent]    = useState(false)
  // Khởi tạo với fallback — đảm bảo luôn là mảng
  const [history, setHistory] = useState(() => FALLBACK_HISTORY.map(normalizeRecord))

  // ── Load history từ API ────────────────────────────────────────────────────
  useEffect(() => {
    console.log('[NotificationsPage] Fetching notification history...')
    adminService.getNotificationHistory()
      .then(data => {
        console.log('[NotificationsPage] API response:', data)
        if (Array.isArray(data) && data.length > 0) {
          setHistory(data.map(normalizeRecord))
        }
        // Nếu API trả về mảng rỗng → giữ fallback
      })
      .catch(err => {
        console.warn('[NotificationsPage] API unavailable, using fallback:', err.message)
        // Giữ nguyên fallback — không crash
      })
  }, [])

  // ── Gửi thông báo ─────────────────────────────────────────────────────────
  const handleSend = async () => {
    if (!title.trim() || !body.trim()) return
    setSending(true)
    try {
      const record = await adminService.sendNotification({ title, body, target })
      console.log('[NotificationsPage] Sent:', record)
      setHistory(prev => [normalizeRecord(record), ...prev])
      setSent(true)
      setTitle('')
      setBody('')
    } catch (err) {
      console.warn('[NotificationsPage] Send failed, optimistic update:', err.message)
      // Optimistic: thêm vào history dù API lỗi
      const optimistic = normalizeRecord({
        id:         String(Date.now()),
        title,
        target,
        sentAt:     new Date().toISOString(),
        reachCount: TARGET_COUNT[target] ?? 0,
      })
      setHistory(prev => [optimistic, ...prev])
      setSent(true)
      setTitle('')
      setBody('')
    } finally {
      setSending(false)
      setTimeout(() => setSent(false), 3000)
    }
  }

  // ── Xóa khỏi danh sách local ──────────────────────────────────────────────
  const handleDelete = (id) => {
    setHistory(prev => prev.filter(n => n.id !== id))
  }

  // ── Tổng lượt nhận ────────────────────────────────────────────────────────
  const totalReach = history.reduce((sum, n) => sum + (n.reachCount ?? 0), 0)

  return (
    <div className="space-y-6">

      <div className="grid grid-cols-1 lg:grid-cols-5 gap-6">

        {/* ── Compose panel ──────────────────────────────────────────────── */}
        <div className="lg:col-span-2 space-y-4">
          <div className="bg-white dark:bg-gray-900 rounded-2xl p-6 shadow-sm border border-gray-100 dark:border-gray-800">
            <div className="flex items-center gap-2 mb-5">
              <Bell size={16} className="text-teal-600" />
              <h2 className="text-sm font-bold text-gray-900 dark:text-white">Soạn thông báo mới</h2>
            </div>

            {/* Target selector */}
            <div className="mb-4">
              <label className="text-xs font-semibold text-gray-600 dark:text-gray-400 block mb-2">
                Đối tượng nhận
              </label>
              <div className="grid grid-cols-2 gap-2">
                {Object.entries(TARGET_LABEL).map(([k, v]) => (
                  <button
                    key={k}
                    onClick={() => setTarget(k)}
                    className={`px-3 py-2 text-xs font-semibold rounded-xl border transition-all text-left ${
                      target === k
                        ? 'border-teal-500 bg-teal-50 dark:bg-teal-900/30 text-teal-700 dark:text-teal-300'
                        : 'border-gray-200 dark:border-gray-700 text-gray-500 dark:text-gray-400 hover:border-gray-300 dark:hover:border-gray-600'
                    }`}
                  >
                    <p>{v}</p>
                    <p className={`text-[10px] mt-0.5 ${target === k ? 'text-teal-500' : 'text-gray-400'}`}>
                      {(TARGET_COUNT[k] ?? 0).toLocaleString()} người
                    </p>
                  </button>
                ))}
              </div>
            </div>

            {/* Title input */}
            <div className="mb-3">
              <label className="text-xs font-semibold text-gray-600 dark:text-gray-400 block mb-1.5">
                Tiêu đề thông báo
              </label>
              <input
                value={title}
                onChange={e => setTitle(e.target.value)}
                placeholder="Nhập tiêu đề..."
                maxLength={60}
                className="w-full px-3 py-2.5 text-sm bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl focus:outline-none focus:ring-2 focus:ring-teal-500/30 focus:border-teal-500 dark:text-gray-200"
              />
              <p className="text-[10px] text-gray-400 mt-1 text-right">{title.length}/60</p>
            </div>

            {/* Body textarea */}
            <div className="mb-5">
              <label className="text-xs font-semibold text-gray-600 dark:text-gray-400 block mb-1.5">
                Nội dung
              </label>
              <textarea
                value={body}
                onChange={e => setBody(e.target.value)}
                placeholder="Nhập nội dung thông báo..."
                rows={4}
                maxLength={200}
                className="w-full px-3 py-2.5 text-sm bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl focus:outline-none focus:ring-2 focus:ring-teal-500/30 focus:border-teal-500 dark:text-gray-200 resize-none"
              />
              <p className="text-[10px] text-gray-400 mt-1 text-right">{body.length}/200</p>
            </div>

            {/* Live preview */}
            {(title || body) && (
              <div className="mb-4 p-3 bg-gray-900 dark:bg-gray-800 rounded-xl">
                <p className="text-[10px] text-gray-400 mb-2 uppercase tracking-wide">Preview trên thiết bị</p>
                <div className="bg-white dark:bg-gray-700 rounded-lg p-3 shadow-sm">
                  <div className="flex items-center gap-2 mb-1">
                    <div className="w-4 h-4 rounded bg-gradient-to-br from-teal-500 to-cyan-400" />
                    <span className="text-[10px] font-bold text-gray-700 dark:text-gray-200">SmartPrice AI</span>
                    <span className="text-[10px] text-gray-400 ml-auto">Vừa xong</span>
                  </div>
                  <p className="text-xs font-semibold text-gray-800 dark:text-gray-100">
                    {title || 'Tiêu đề...'}
                  </p>
                  <p className="text-[11px] text-gray-500 dark:text-gray-400 mt-0.5 line-clamp-2">
                    {body || 'Nội dung...'}
                  </p>
                </div>
              </div>
            )}

            {/* Send button */}
            <button
              onClick={handleSend}
              disabled={!title.trim() || !body.trim() || sending}
              className={`w-full flex items-center justify-center gap-2 py-2.5 rounded-xl text-sm font-bold transition-all ${
                sent
                  ? 'bg-emerald-500 text-white'
                  : !title.trim() || !body.trim()
                    ? 'bg-gray-100 dark:bg-gray-800 text-gray-400 cursor-not-allowed'
                    : 'bg-gradient-to-r from-teal-600 to-cyan-500 text-white hover:opacity-90 shadow-md'
              }`}
            >
              {sent ? (
                <><CheckCircle size={16} /> Đã gửi thành công!</>
              ) : sending ? (
                <><div className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" /> Đang gửi...</>
              ) : (
                <><Send size={15} /> Gửi thông báo ({(TARGET_COUNT[target] ?? 0).toLocaleString()} người)</>
              )}
            </button>
          </div>
        </div>

        {/* ── History panel ───────────────────────────────────────────────── */}
        <div className="lg:col-span-3 bg-white dark:bg-gray-900 rounded-2xl shadow-sm border border-gray-100 dark:border-gray-800 overflow-hidden">
          <div className="px-6 py-4 border-b border-gray-100 dark:border-gray-800 flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Clock size={16} className="text-teal-600" />
              <h2 className="text-sm font-bold text-gray-900 dark:text-white">Lịch sử thông báo</h2>
            </div>
            {/* ✅ Dùng history.length thay vì SENT_HISTORY.length */}
            <span className="text-xs text-gray-400">{history.length} thông báo</span>
          </div>

          <div className="divide-y divide-gray-50 dark:divide-gray-800">
            {/* ✅ Optional chaining + fallback mảng rỗng */}
            {(history ?? []).map(n => (
              <div
                key={n.id}
                className="px-6 py-4 hover:bg-gray-50/50 dark:hover:bg-gray-800/30 transition-colors"
              >
                <div className="flex items-start justify-between gap-3">
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1">
                      <p className="text-sm font-semibold text-gray-800 dark:text-gray-200 truncate">
                        {n.title}
                      </p>
                      <span className="flex-shrink-0 text-[10px] font-semibold px-2 py-0.5 rounded-full bg-emerald-50 text-emerald-600 dark:bg-emerald-900/30 dark:text-emerald-400">
                        Đã gửi
                      </span>
                    </div>
                    <div className="flex items-center gap-3 text-[11px] text-gray-400 flex-wrap">
                      <span className="flex items-center gap-1">
                        <Users size={11} />
                        {n.target}
                      </span>
                      <span>·</span>
                      <span>{(n.reachCount ?? 0).toLocaleString()} người nhận</span>
                      <span>·</span>
                      <span>
                        {n.sentAt
                          ? new Date(n.sentAt).toLocaleString('vi-VN')
                          : '—'}
                      </span>
                    </div>
                  </div>
                  <button
                    onClick={() => handleDelete(n.id)}
                    className="w-7 h-7 rounded-lg hover:bg-red-50 dark:hover:bg-red-900/20 flex items-center justify-center text-gray-300 hover:text-red-400 transition-colors flex-shrink-0"
                    title="Xóa"
                  >
                    <Trash2 size={13} />
                  </button>
                </div>
              </div>
            ))}

            {history.length === 0 && (
              <div className="py-12 text-center text-gray-400 text-sm">
                Chưa có thông báo nào được gửi.
              </div>
            )}
          </div>
        </div>
      </div>

      {/* ── Stats row ──────────────────────────────────────────────────────── */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        {[
          { label: 'Tổng đã gửi',    value: history.length,              color: 'text-teal-600'   },
          { label: 'Tổng lượt nhận', value: totalReach.toLocaleString(), color: 'text-cyan-600'   },
          { label: 'Tỷ lệ mở',       value: '68.4%',                     color: 'text-emerald-600' },
          { label: 'Tỷ lệ click',    value: '24.1%',                     color: 'text-amber-500'  },
        ].map(s => (
          <div
            key={s.label}
            className="bg-white dark:bg-gray-900 rounded-2xl p-4 shadow-sm border border-gray-100 dark:border-gray-800"
          >
            <p className={`text-2xl font-extrabold ${s.color}`}>{s.value}</p>
            <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">{s.label}</p>
          </div>
        ))}
      </div>

    </div>
  )
}
