import { useState, useEffect, useCallback } from 'react'
import { Users, DollarSign, ScanLine, AlertTriangle, MoreHorizontal, Play, Activity, RefreshCw } from 'lucide-react'
import {
  AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend
} from 'recharts'
import MetricCard from '../components/MetricCard'
import { chartData6M, chartData12M, recentUsers, systemHealth } from '../data/mockData'
import { adminService } from '../api/adminService'
import { walletService, formatVND, formatVNDShort } from '../api/walletService'
import { useApi } from '../hooks/useApi'

// ── Tier badge ────────────────────────────────────────────────────────────────
function TierBadge({ tier }) {
  const styles = {
    'Hạng vàng':  'bg-amber-50  text-amber-600  dark:bg-amber-900/30  dark:text-amber-400',
    'Hạng bạc':   'bg-emerald-50 text-emerald-600 dark:bg-emerald-900/30 dark:text-emerald-400',
    'Hạng đồng':  'bg-gray-100  text-gray-500   dark:bg-gray-800      dark:text-gray-400',
  }
  return (
    <span className={`text-[11px] font-semibold px-2.5 py-0.5 rounded-full ${styles[tier] || styles['Hạng đồng']}`}>
      {tier}
    </span>
  )
}

// ── Custom tooltip ────────────────────────────────────────────────────────────
function CustomTooltip({ active, payload, label }) {
  if (!active || !payload?.length) return null
  return (
    <div className="bg-white dark:bg-gray-800 border border-gray-100 dark:border-gray-700 rounded-xl p-3 shadow-lg text-xs">
      <p className="font-bold text-gray-700 dark:text-gray-200 mb-2">{label}</p>
      {payload.map(p => (
        <p key={p.name} style={{ color: p.color }} className="font-medium">
          {p.name}: {p.value.toLocaleString()}$
        </p>
      ))}
    </div>
  )
}

export default function OverviewPage() {
  const [chartRange, setChartRange] = useState('6M')

  // ── Live balance state – cập nhật real-time ──────────────────────────────
  const [totalBalance, setTotalBalance]   = useState(null)
  const [balanceLoading, setBalanceLoading] = useState(true)

  const fetchBalance = useCallback(async () => {
    setBalanceLoading(true)
    try {
      const data = await walletService.getBalance('user_01')
      setTotalBalance(data?.balance ?? null)
    } catch {
      setTotalBalance(null) // fallback về overview.totalRevenue
    } finally {
      setBalanceLoading(false)
    }
  }, [])

  useEffect(() => { fetchBalance() }, [fetchBalance])

  // ── Live data – fallback về mock nếu API chưa chạy ───────────────────────
  const { data: overview } = useApi(() => adminService.getOverview(), [])
  const { data: liveChart } = useApi(
    () => adminService.getChartData(chartRange === '6M' ? 6 : 12),
    [chartRange]
  )
  const { data: usersData } = useApi(() => adminService.getUsers({ limit: 6 }), [])

  // Số dư hiển thị: ưu tiên live balance từ /api/wallet/balance
  const displayBalance = totalBalance !== null
    ? totalBalance
    : (overview?.totalRevenue ?? 45200)

  // Dùng live data nếu có, fallback về mock
  const chartData = (liveChart?.length ? liveChart : chartRange === '6M' ? chartData6M : chartData12M)

  // ✦ Normalize user fields – API trả PascalCase, mock dùng camelCase
  const normalizeUser = (u) => ({
    id:     u.id     ?? u.Id     ?? String(Math.random()),
    name:   u.name   ?? u.FullName ?? '?',
    email:  u.email  ?? u.Email  ?? '',
    joined: u.joined ?? (u.CreatedAt ? new Date(u.CreatedAt).toLocaleDateString('vi-VN') : '—'),
    tier:   u.tier   ?? u.Tier   ?? 'Hạng đồng',
    score:  u.score  ?? u.HealthScore ?? 0,
    active: u.active ?? u.IsActive ?? true,
  })

  const rawUsers     = usersData?.data?.length ? usersData.data : recentUsers
  const displayUsers = rawUsers.map(normalizeUser)

  return (
    <div className="space-y-6">

      {/* ── Metric cards ──────────────────────────────────────────────────────── */}
      <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
        <MetricCard
          icon={Users}
          iconBg="bg-gradient-to-br from-teal-500 to-teal-600"
          title="Tổng người dùng"
          value={(overview?.totalUsers ?? 12450).toLocaleString()}
          trend={`+${overview?.userGrowthPercent ?? 12}%`}
          trendUp={true}
          sub="So với tháng trước"
        />
        <MetricCard
          icon={DollarSign}
          iconBg="bg-gradient-to-br from-cyan-500 to-teal-500"
          title="Doanh thu / Tháng"
          value={`${((overview?.totalRevenue ?? 45200) / 1000).toFixed(1)}k`}
          trend={`+${overview?.revenueGrowthPercent ?? 8.3}%`}
          trendUp={true}
          sub={`${(overview?.totalTransactions ?? 3200).toLocaleString()} giao dịch`}
        />
        <MetricCard
          icon={ScanLine}
          iconBg="bg-gradient-to-br from-emerald-500 to-teal-500"
          title="Tỷ lệ OCR thành công"
          value={`${overview?.ocrSuccessRate ?? 98.5}%`}
          badge="Ổn định"
          badgeColor="bg-emerald-50 text-emerald-600 dark:bg-emerald-900/30 dark:text-emerald-400"
          sub="Trong 30 ngày qua"
        />
        <MetricCard
          icon={AlertTriangle}
          iconBg="bg-gradient-to-br from-red-400 to-rose-500"
          title="Lỗi hệ thống"
          value={<span className="text-red-500 dark:text-red-400">{overview?.activeErrors ?? 24}</span>}
          trend="-8%"
          trendUp={false}
          sub="Active incidents"
        />
      </div>

      {/* ── Main chart + Users table ──────────────────────────────────────────── */}
      <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">

        {/* Area Chart */}
        <div className="xl:col-span-2 bg-white dark:bg-gray-900 rounded-2xl p-6 shadow-sm border border-gray-100 dark:border-gray-800">
          <div className="flex items-center justify-between mb-6">
            <div>
              <h2 className="text-base font-bold text-gray-900 dark:text-white">So sánh khối lượng giao dịch</h2>
              <p className="text-xs text-gray-400 mt-0.5">Thu nhập vs Chi tiêu theo tháng</p>
            </div>
            <div className="flex gap-1 bg-gray-100 dark:bg-gray-800 rounded-xl p-1">
              {['6M', '12M'].map(r => (
                <button
                  key={r}
                  onClick={() => setChartRange(r)}
                  className={`px-3 py-1.5 text-xs font-semibold rounded-lg transition-all ${
                    chartRange === r
                      ? 'bg-white dark:bg-gray-700 text-teal-600 dark:text-teal-400 shadow-sm'
                      : 'text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200'
                  }`}
                >
                  {r}
                </button>
              ))}
            </div>
          </div>
          <ResponsiveContainer width="100%" height={260}>
            <AreaChart data={chartData} margin={{ top: 5, right: 10, left: -10, bottom: 0 }}>
              <defs>
                <linearGradient id="incomeGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%"  stopColor="#0d9488" stopOpacity={0.25} />
                  <stop offset="95%" stopColor="#0d9488" stopOpacity={0} />
                </linearGradient>
                <linearGradient id="expenseGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%"  stopColor="#06b6d4" stopOpacity={0.2} />
                  <stop offset="95%" stopColor="#06b6d4" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
              <XAxis dataKey="month" tick={{ fontSize: 11, fill: '#94a3b8' }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fontSize: 11, fill: '#94a3b8' }} axisLine={false} tickLine={false} tickFormatter={v => `${(v/1000).toFixed(0)}k`} />
              <Tooltip content={<CustomTooltip />} />
              <Legend iconType="circle" iconSize={8} wrapperStyle={{ fontSize: 12, paddingTop: 12 }} />
              <Area type="monotone" dataKey="income"  name="Thu nhập" stroke="#0d9488" strokeWidth={2.5} fill="url(#incomeGrad)"  dot={false} activeDot={{ r: 5, fill: '#0d9488' }} />
              <Area type="monotone" dataKey="expense" name="Chi tiêu"  stroke="#06b6d4" strokeWidth={2.5} fill="url(#expenseGrad)" dot={false} activeDot={{ r: 5, fill: '#06b6d4' }} />
            </AreaChart>
          </ResponsiveContainer>
        </div>

        {/* Quick stats sidebar */}
        <div className="space-y-4">
          {/* Activity feed */}
          <div className="bg-white dark:bg-gray-900 rounded-2xl p-5 shadow-sm border border-gray-100 dark:border-gray-800">
            <div className="flex items-center gap-2 mb-4">
              <Activity size={16} className="text-teal-600" />
              <h3 className="text-sm font-bold text-gray-900 dark:text-white">Hoạt động gần đây</h3>
            </div>
            <div className="space-y-3">
              {[
                { text: 'User mới đăng ký', time: '2 phút trước', dot: 'bg-teal-500' },
                { text: 'OCR scan thành công', time: '5 phút trước', dot: 'bg-emerald-500' },
                { text: 'Lỗi API timeout', time: '12 phút trước', dot: 'bg-red-400' },
                { text: 'Backup hoàn thành', time: '1 giờ trước', dot: 'bg-cyan-500' },
                { text: 'AI model cập nhật', time: '3 giờ trước', dot: 'bg-purple-500' },
              ].map((item, i) => (
                <div key={i} className="flex items-start gap-3">
                  <div className={`w-2 h-2 rounded-full mt-1.5 flex-shrink-0 ${item.dot}`} />
                  <div className="min-w-0">
                    <p className="text-xs font-medium text-gray-700 dark:text-gray-300">{item.text}</p>
                    <p className="text-[10px] text-gray-400">{item.time}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Category breakdown */}
          <div className="bg-white dark:bg-gray-900 rounded-2xl p-5 shadow-sm border border-gray-100 dark:border-gray-800">
            <h3 className="text-sm font-bold text-gray-900 dark:text-white mb-4">Top danh mục chi tiêu</h3>
            <div className="space-y-3">
              {[
                { label: 'Ăn uống',    pct: 34, color: 'bg-teal-500' },
                { label: 'Mua sắm',   pct: 28, color: 'bg-cyan-500' },
                { label: 'Di chuyển', pct: 18, color: 'bg-emerald-500' },
                { label: 'Giải trí',  pct: 12, color: 'bg-amber-400' },
                { label: 'Khác',      pct: 8,  color: 'bg-gray-300' },
              ].map(item => (
                <div key={item.label}>
                  <div className="flex justify-between text-xs mb-1">
                    <span className="text-gray-600 dark:text-gray-400">{item.label}</span>
                    <span className="font-semibold text-gray-800 dark:text-gray-200">{item.pct}%</span>
                  </div>
                  <div className="h-1.5 bg-gray-100 dark:bg-gray-800 rounded-full overflow-hidden">
                    <div className={`h-full ${item.color} rounded-full`} style={{ width: `${item.pct}%` }} />
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* ── Users table ───────────────────────────────────────────────────────── */}
      <div className="bg-white dark:bg-gray-900 rounded-2xl shadow-sm border border-gray-100 dark:border-gray-800 overflow-hidden">
        <div className="px-6 py-4 border-b border-gray-100 dark:border-gray-800 flex items-center justify-between">
          <div>
            <h2 className="text-base font-bold text-gray-900 dark:text-white">Người dùng mới nhất</h2>
            <p className="text-xs text-gray-400 mt-0.5">6 thành viên đăng ký gần đây</p>
          </div>
          <button className="text-xs font-semibold text-teal-600 dark:text-teal-400 hover:underline">Xem tất cả →</button>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="bg-gray-50 dark:bg-gray-800/50">
                {['Người dùng', 'Email', 'Ngày đăng ký', 'Tư cách', 'Điểm TC', 'Trạng thái', ''].map(h => (
                  <th key={h} className="px-6 py-3 text-left text-[11px] font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider whitespace-nowrap">
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50 dark:divide-gray-800">
              {displayUsers.map(user => (
                <tr key={user.id} className="hover:bg-gray-50/50 dark:hover:bg-gray-800/30 transition-colors">
                  <td className="px-6 py-3.5">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded-full bg-gradient-to-br from-teal-400 to-cyan-500 flex items-center justify-center text-white text-xs font-bold flex-shrink-0">
                        {(user.name ?? '?').charAt(0)}
                      </div>
                      <span className="text-sm font-semibold text-gray-800 dark:text-gray-200 whitespace-nowrap">{user.name}</span>
                    </div>
                  </td>
                  <td className="px-6 py-3.5 text-sm text-gray-500 dark:text-gray-400">{user.email}</td>
                  <td className="px-6 py-3.5 text-sm text-gray-500 dark:text-gray-400 whitespace-nowrap">{user.joined}</td>
                  <td className="px-6 py-3.5"><TierBadge tier={user.tier} /></td>
                  <td className="px-6 py-3.5">
                    <span className="text-sm font-bold text-teal-600 dark:text-teal-400">{user.score}</span>
                  </td>
                  <td className="px-6 py-3.5">
                    <span className={`inline-flex items-center gap-1.5 text-[11px] font-semibold px-2.5 py-0.5 rounded-full ${
                      user.active
                        ? 'bg-emerald-50 text-emerald-600 dark:bg-emerald-900/30 dark:text-emerald-400'
                        : 'bg-red-50 text-red-500 dark:bg-red-900/30 dark:text-red-400'
                    }`}>
                      <span className={`w-1.5 h-1.5 rounded-full ${user.active ? 'bg-emerald-500' : 'bg-red-400'}`} />
                      {user.active ? 'Hoạt động' : 'Bị khóa'}
                    </span>
                  </td>
                  <td className="px-6 py-3.5">
                    <button className="w-7 h-7 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 flex items-center justify-center text-gray-400 transition-colors">
                      <MoreHorizontal size={15} />
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* ── Bottom section ────────────────────────────────────────────────────── */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">

        {/* AI Banner */}
        <div className="lg:col-span-2 rounded-2xl overflow-hidden relative"
          style={{ background: 'linear-gradient(135deg, #0d9488 0%, #06b6d4 50%, #0891b2 100%)' }}>
          <div className="absolute inset-0 opacity-10"
            style={{ backgroundImage: 'radial-gradient(circle at 80% 20%, white 1px, transparent 1px)', backgroundSize: '24px 24px' }} />
          <div className="relative p-6 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
            <div>
              <div className="flex items-center gap-2 mb-2">
                <div className="w-8 h-8 rounded-xl bg-white/20 flex items-center justify-center">
                  <Activity size={16} className="text-white" />
                </div>
                <span className="text-white/80 text-xs font-semibold uppercase tracking-wide">AI Diagnostics</span>
              </div>
              <h3 className="text-xl font-extrabold text-white mb-1">Tối ưu hóa hệ thống AI</h3>
              <p className="text-white/70 text-sm max-w-md">
                Phát hiện 3 điểm có thể cải thiện trong pipeline OCR. Chạy chẩn đoán để tăng độ chính xác lên ~2.1%.
              </p>
              <div className="flex gap-4 mt-3">
                {[['98.5%', 'OCR Accuracy'], ['12ms', 'Avg Latency'], ['99.9%', 'Uptime']].map(([v, l]) => (
                  <div key={l}>
                    <p className="text-white font-extrabold text-lg leading-tight">{v}</p>
                    <p className="text-white/60 text-[10px]">{l}</p>
                  </div>
                ))}
              </div>
            </div>
            <button className="flex-shrink-0 flex items-center gap-2 bg-white text-teal-700 font-bold text-sm px-5 py-2.5 rounded-xl hover:bg-teal-50 transition-colors shadow-lg">
              <Play size={14} />
              Run Diagnostics
            </button>
          </div>
        </div>

        {/* System health */}
        <div className="bg-white dark:bg-gray-900 rounded-2xl p-5 shadow-sm border border-gray-100 dark:border-gray-800">
          <h3 className="text-sm font-bold text-gray-900 dark:text-white mb-4">Tình trạng hệ thống</h3>
          <div className="space-y-4">
            {systemHealth.map(item => (
              <div key={item.label}>
                <div className="flex justify-between items-center mb-1.5">
                  <span className="text-xs text-gray-600 dark:text-gray-400">{item.label}</span>
                  <div className="flex items-center gap-2">
                    <span className="text-xs font-bold text-gray-800 dark:text-gray-200">
                      {item.value}{item.unit}
                    </span>
                    <span className="text-[10px] text-emerald-600 dark:text-emerald-400 font-medium">{item.status}</span>
                  </div>
                </div>
                <div className="h-2 bg-gray-100 dark:bg-gray-800 rounded-full overflow-hidden">
                  <div
                    className={`h-full ${item.color} rounded-full transition-all duration-700`}
                    style={{ width: `${item.value}%` }}
                  />
                </div>
              </div>
            ))}
          </div>

          {/* Status dots */}
          <div className="mt-5 pt-4 border-t border-gray-100 dark:border-gray-800 space-y-2">
            {[
              { label: 'MongoDB Atlas',    ok: true  },
              { label: 'AI Engine (Flask)', ok: true  },
              { label: 'Push Notification', ok: true  },
              { label: 'Email Service',     ok: false },
            ].map(s => (
              <div key={s.label} className="flex items-center justify-between">
                <span className="text-xs text-gray-500 dark:text-gray-400">{s.label}</span>
                <span className={`flex items-center gap-1.5 text-[10px] font-semibold ${s.ok ? 'text-emerald-600' : 'text-red-400'}`}>
                  <span className={`w-1.5 h-1.5 rounded-full ${s.ok ? 'bg-emerald-500' : 'bg-red-400'}`} />
                  {s.ok ? 'Online' : 'Offline'}
                </span>
              </div>
            ))}
          </div>
        </div>
      </div>

    </div>
  )
}
