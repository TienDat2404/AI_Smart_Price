import { useState, useEffect } from 'react'
import { Search, UserCheck, UserX, Eye, MoreHorizontal } from 'lucide-react'
import { recentUsers } from '../data/mockData'
import { adminService } from '../api/adminService'

function ScoreBar({ score }) {
  const pct = Math.min(score / 1000 * 100, 100)
  const color = score >= 800 ? 'bg-teal-500' : score >= 600 ? 'bg-amber-400' : 'bg-red-400'
  return (
    <div className="flex items-center gap-2">
      <div className="flex-1 h-1.5 bg-gray-100 dark:bg-gray-800 rounded-full overflow-hidden">
        <div className={`h-full ${color} rounded-full`} style={{ width: `${pct}%` }} />
      </div>
      <span className="text-xs font-bold text-gray-700 dark:text-gray-300 w-8 text-right">{score}</span>
    </div>
  )
}

export default function UsersPage() {
  const [search, setSearch]   = useState('')
  const [filter, setFilter]   = useState('all')
  const [users, setUsers]     = useState(recentUsers)
  const [loading, setLoading] = useState(false)
  const [total, setTotal]     = useState(recentUsers.length)

  useEffect(() => {
    const params = { search: search || undefined, status: filter === 'all' ? undefined : filter, limit: 20 }
    setLoading(true)
    adminService.getUsers(params)
      .then(res => { setUsers(res.data ?? recentUsers); setTotal(res.total ?? res.data?.length ?? 0) })
      .catch(() => { setUsers(recentUsers); setTotal(recentUsers.length) })
      .finally(() => setLoading(false))
  }, [search, filter])

  const toggleLock = async (id) => {
    try {
      const res = await adminService.toggleUserLock(id)
      setUsers(prev => prev.map(u => (u.id === id || u.Id === id) ? { ...u, active: res.isActive, IsActive: res.isActive } : u))
    } catch {
      setUsers(prev => prev.map(u => (u.id === id || u.Id === id) ? { ...u, active: !u.active } : u))
    }
  }

  const normalize = (u) => ({
    id:     u.id     ?? u.Id     ?? String(Math.random()),
    name:   u.name   ?? u.FullName ?? '?',
    email:  u.email  ?? u.Email  ?? '',
    joined: u.joined ?? (u.CreatedAt ? new Date(u.CreatedAt).toLocaleDateString('vi-VN') : '—'),
    score:  u.score  ?? u.HealthScore ?? 0,
    active: u.active ?? u.IsActive ?? true,
  })

  const filtered = users.map(normalize)

  return (
    <div className="space-y-6">

      {/* Stats row — bỏ ô Hạng vàng */}
      <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
        {[
          { label: 'Tổng thành viên', value: total,                                  color: 'text-teal-600' },
          { label: 'Đang hoạt động',  value: filtered.filter(u => u.active).length,  color: 'text-emerald-600' },
          { label: 'Bị khóa',         value: filtered.filter(u => !u.active).length, color: 'text-red-500' },
        ].map(s => (
          <div key={s.label} className="bg-white dark:bg-gray-900 rounded-2xl p-4 shadow-sm border border-gray-100 dark:border-gray-800">
            <p className={`text-2xl font-extrabold ${s.color}`}>{s.value}</p>
            <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">{s.label}</p>
          </div>
        ))}
      </div>

      {/* Table */}
      <div className="bg-white dark:bg-gray-900 rounded-2xl shadow-sm border border-gray-100 dark:border-gray-800 overflow-hidden">
        {/* Toolbar */}
        <div className="px-6 py-4 border-b border-gray-100 dark:border-gray-800 flex flex-col sm:flex-row gap-3 items-start sm:items-center justify-between">
          <div className="relative">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              value={search}
              onChange={e => setSearch(e.target.value)}
              placeholder="Tìm theo tên hoặc email..."
              className="pl-9 pr-4 py-2 text-sm bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl w-64 focus:outline-none focus:ring-2 focus:ring-teal-500/30 focus:border-teal-500 dark:text-gray-200"
            />
          </div>
          <div className="flex gap-2">
            {['all', 'active', 'locked'].map(f => (
              <button
                key={f}
                onClick={() => setFilter(f)}
                className={`px-3 py-1.5 text-xs font-semibold rounded-xl transition-all ${
                  filter === f
                    ? 'bg-teal-600 text-white'
                    : 'bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700'
                }`}
              >
                {f === 'all' ? 'Tất cả' : f === 'active' ? 'Hoạt động' : 'Bị khóa'}
              </button>
            ))}
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="bg-gray-50 dark:bg-gray-800/50">
                {['Người dùng', 'Email', 'Ngày đăng ký', 'Điểm sức khỏe TC', 'Trạng thái', 'Hành động'].map(h => (
                  <th key={h} className="px-6 py-3 text-left text-[11px] font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider whitespace-nowrap">
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50 dark:divide-gray-800">
              {filtered.map(user => (
                <tr key={user.id} className="hover:bg-gray-50/50 dark:hover:bg-gray-800/30 transition-colors">
                  <td className="px-6 py-4">
                    <div className="flex items-center gap-3">
                      <div className="w-9 h-9 rounded-full bg-gradient-to-br from-teal-400 to-cyan-500 flex items-center justify-center text-white text-sm font-bold flex-shrink-0">
                        {(user.name ?? '?').charAt(0)}
                      </div>
                      <div>
                        <p className="text-sm font-semibold text-gray-800 dark:text-gray-200 whitespace-nowrap">{user.name}</p>
                        <p className="text-[10px] text-gray-400">ID: {String(user.id).slice(0, 12)}</p>
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4 text-sm text-gray-500 dark:text-gray-400">{user.email}</td>
                  <td className="px-6 py-4 text-sm text-gray-500 dark:text-gray-400 whitespace-nowrap">{user.joined}</td>
                  <td className="px-6 py-4 w-40"><ScoreBar score={user.score} /></td>
                  <td className="px-6 py-4">
                    <span className={`inline-flex items-center gap-1.5 text-[11px] font-semibold px-2.5 py-0.5 rounded-full ${
                      user.active
                        ? 'bg-emerald-50 text-emerald-600 dark:bg-emerald-900/30 dark:text-emerald-400'
                        : 'bg-red-50 text-red-500 dark:bg-red-900/30 dark:text-red-400'
                    }`}>
                      <span className={`w-1.5 h-1.5 rounded-full ${user.active ? 'bg-emerald-500' : 'bg-red-400'}`} />
                      {user.active ? 'Hoạt động' : 'Bị khóa'}
                    </span>
                  </td>
                  <td className="px-6 py-4">
                    <div className="flex items-center gap-1">
                      <button
                        title="Xem chi tiết"
                        className="w-7 h-7 rounded-lg hover:bg-teal-50 dark:hover:bg-teal-900/30 flex items-center justify-center text-teal-600 transition-colors"
                      >
                        <Eye size={14} />
                      </button>
                      <button
                        title={user.active ? 'Khóa tài khoản' : 'Mở khóa'}
                        onClick={() => toggleLock(user.id)}
                        className={`w-7 h-7 rounded-lg flex items-center justify-center transition-colors ${
                          user.active
                            ? 'hover:bg-red-50 dark:hover:bg-red-900/30 text-red-400'
                            : 'hover:bg-emerald-50 dark:hover:bg-emerald-900/30 text-emerald-500'
                        }`}
                      >
                        {user.active ? <UserX size={14} /> : <UserCheck size={14} />}
                      </button>
                      <button className="w-7 h-7 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 flex items-center justify-center text-gray-400 transition-colors">
                        <MoreHorizontal size={14} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {filtered.length === 0 && (
            <div className="py-12 text-center text-gray-400 text-sm">
              {loading ? 'Đang tải...' : 'Không tìm thấy người dùng nào.'}
            </div>
          )}
        </div>

        {/* Pagination */}
        <div className="px-6 py-3 border-t border-gray-100 dark:border-gray-800 flex items-center justify-between">
          <p className="text-xs text-gray-400">Hiển thị {filtered.length} / {total} người dùng</p>
          <div className="flex gap-1">
            {[1, 2, 3].map(p => (
              <button key={p} className={`w-7 h-7 rounded-lg text-xs font-semibold transition-all ${
                p === 1 ? 'bg-teal-600 text-white' : 'text-gray-500 hover:bg-gray-100 dark:hover:bg-gray-800'
              }`}>{p}</button>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}
