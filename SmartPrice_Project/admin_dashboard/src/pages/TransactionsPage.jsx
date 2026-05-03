import { useState } from 'react'
import { Search, ArrowUpRight, ArrowDownLeft, RefreshCw, Download } from 'lucide-react'
import { recentTransactions, chartData6M } from '../data/mockData'
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend
} from 'recharts'

function TypeBadge({ type }) {
  const styles = {
    'Chi tiêu':   'bg-red-50   text-red-500   dark:bg-red-900/30   dark:text-red-400',
    'Thu nhập':   'bg-teal-50  text-teal-600  dark:bg-teal-900/30  dark:text-teal-400',
    'Điều chỉnh': 'bg-purple-50 text-purple-600 dark:bg-purple-900/30 dark:text-purple-400',
  }
  return (
    <span className={`text-[11px] font-semibold px-2.5 py-0.5 rounded-full ${styles[type] || ''}`}>
      {type}
    </span>
  )
}

function StatusBadge({ status }) {
  return (
    <span className={`text-[11px] font-semibold px-2.5 py-0.5 rounded-full ${
      status === 'completed'
        ? 'bg-emerald-50 text-emerald-600 dark:bg-emerald-900/30 dark:text-emerald-400'
        : 'bg-amber-50 text-amber-600 dark:bg-amber-900/30 dark:text-amber-400'
    }`}>
      {status === 'completed' ? 'Hoàn thành' : 'Đang xử lý'}
    </span>
  )
}

const fmt = (n) => {
  const abs = Math.abs(n)
  return (n < 0 ? '-' : '+') + abs.toLocaleString('vi-VN') + 'đ'
}

export default function TransactionsPage() {
  const [search, setSearch] = useState('')

  const filtered = recentTransactions.filter(t =>
    t.user.toLowerCase().includes(search.toLowerCase()) ||
    t.category.toLowerCase().includes(search.toLowerCase())
  )

  const totalIncome  = recentTransactions.filter(t => t.amount > 0).reduce((s, t) => s + t.amount, 0)
  const totalExpense = recentTransactions.filter(t => t.amount < 0).reduce((s, t) => s + Math.abs(t.amount), 0)

  return (
    <div className="space-y-6">

      {/* Summary cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="bg-white dark:bg-gray-900 rounded-2xl p-5 shadow-sm border border-gray-100 dark:border-gray-800">
          <div className="flex items-center gap-3 mb-3">
            <div className="w-9 h-9 rounded-xl bg-teal-50 dark:bg-teal-900/30 flex items-center justify-center">
              <ArrowDownLeft size={18} className="text-teal-600" />
            </div>
            <span className="text-sm text-gray-500 dark:text-gray-400">Tổng thu nhập</span>
          </div>
          <p className="text-2xl font-extrabold text-teal-600">{totalIncome.toLocaleString('vi-VN')}đ</p>
        </div>
        <div className="bg-white dark:bg-gray-900 rounded-2xl p-5 shadow-sm border border-gray-100 dark:border-gray-800">
          <div className="flex items-center gap-3 mb-3">
            <div className="w-9 h-9 rounded-xl bg-red-50 dark:bg-red-900/30 flex items-center justify-center">
              <ArrowUpRight size={18} className="text-red-500" />
            </div>
            <span className="text-sm text-gray-500 dark:text-gray-400">Tổng chi tiêu</span>
          </div>
          <p className="text-2xl font-extrabold text-red-500">{totalExpense.toLocaleString('vi-VN')}đ</p>
        </div>
        <div className="bg-white dark:bg-gray-900 rounded-2xl p-5 shadow-sm border border-gray-100 dark:border-gray-800">
          <div className="flex items-center gap-3 mb-3">
            <div className="w-9 h-9 rounded-xl bg-purple-50 dark:bg-purple-900/30 flex items-center justify-center">
              <RefreshCw size={18} className="text-purple-600" />
            </div>
            <span className="text-sm text-gray-500 dark:text-gray-400">Giao dịch điều chỉnh</span>
          </div>
          <p className="text-2xl font-extrabold text-purple-600">
            {recentTransactions.filter(t => t.type === 'Điều chỉnh').length}
          </p>
        </div>
      </div>

      {/* Bar chart */}
      <div className="bg-white dark:bg-gray-900 rounded-2xl p-6 shadow-sm border border-gray-100 dark:border-gray-800">
        <h2 className="text-base font-bold text-gray-900 dark:text-white mb-4">Biểu đồ giao dịch 6 tháng</h2>
        <ResponsiveContainer width="100%" height={220}>
          <BarChart data={chartData6M} margin={{ top: 5, right: 10, left: -10, bottom: 0 }} barGap={4}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
            <XAxis dataKey="month" tick={{ fontSize: 11, fill: '#94a3b8' }} axisLine={false} tickLine={false} />
            <YAxis tick={{ fontSize: 11, fill: '#94a3b8' }} axisLine={false} tickLine={false} tickFormatter={v => `${(v/1000).toFixed(0)}k`} />
            <Tooltip formatter={(v) => [`${v.toLocaleString()}$`, '']} />
            <Legend iconType="circle" iconSize={8} wrapperStyle={{ fontSize: 12 }} />
            <Bar dataKey="income"  name="Thu nhập" fill="#0d9488" radius={[4,4,0,0]} />
            <Bar dataKey="expense" name="Chi tiêu"  fill="#06b6d4" radius={[4,4,0,0]} />
          </BarChart>
        </ResponsiveContainer>
      </div>

      {/* Table */}
      <div className="bg-white dark:bg-gray-900 rounded-2xl shadow-sm border border-gray-100 dark:border-gray-800 overflow-hidden">
        <div className="px-6 py-4 border-b border-gray-100 dark:border-gray-800 flex items-center justify-between gap-3">
          <div className="relative">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              value={search}
              onChange={e => setSearch(e.target.value)}
              placeholder="Tìm giao dịch..."
              className="pl-9 pr-4 py-2 text-sm bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl w-56 focus:outline-none focus:ring-2 focus:ring-teal-500/30 focus:border-teal-500 dark:text-gray-200"
            />
          </div>
          <button className="flex items-center gap-2 px-3 py-2 text-xs font-semibold text-gray-600 dark:text-gray-400 bg-gray-50 dark:bg-gray-800 rounded-xl hover:bg-gray-100 dark:hover:bg-gray-700 transition-all border border-gray-200 dark:border-gray-700">
            <Download size={13} />
            Xuất CSV
          </button>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="bg-gray-50 dark:bg-gray-800/50">
                {['Người dùng', 'Loại', 'Danh mục', 'Số tiền', 'Ngày', 'Trạng thái'].map(h => (
                  <th key={h} className="px-6 py-3 text-left text-[11px] font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider whitespace-nowrap">
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50 dark:divide-gray-800">
              {filtered.map(tx => (
                <tr key={tx.id} className="hover:bg-gray-50/50 dark:hover:bg-gray-800/30 transition-colors">
                  <td className="px-6 py-3.5">
                    <div className="flex items-center gap-2">
                      <div className="w-7 h-7 rounded-full bg-gradient-to-br from-teal-400 to-cyan-500 flex items-center justify-center text-white text-xs font-bold flex-shrink-0">
                        {tx.user.charAt(0)}
                      </div>
                      <span className="text-sm font-medium text-gray-800 dark:text-gray-200 whitespace-nowrap">{tx.user}</span>
                    </div>
                  </td>
                  <td className="px-6 py-3.5"><TypeBadge type={tx.type} /></td>
                  <td className="px-6 py-3.5 text-sm text-gray-500 dark:text-gray-400">{tx.category}</td>
                  <td className="px-6 py-3.5">
                    <span className={`text-sm font-bold ${tx.amount >= 0 ? 'text-teal-600 dark:text-teal-400' : 'text-red-500 dark:text-red-400'}`}>
                      {fmt(tx.amount)}
                    </span>
                  </td>
                  <td className="px-6 py-3.5 text-sm text-gray-500 dark:text-gray-400 whitespace-nowrap">{tx.date}</td>
                  <td className="px-6 py-3.5"><StatusBadge status={tx.status} /></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}
