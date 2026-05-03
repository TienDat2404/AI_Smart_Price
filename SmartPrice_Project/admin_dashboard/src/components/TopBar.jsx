import { Bell, Search, Sun, Moon, RefreshCw } from 'lucide-react'

const PAGE_TITLES = {
  overview:      'Tổng quan hệ thống',
  users:         'Quản lý người dùng',
  transactions:  'Thống kê giao dịch',
  ai:            'Thiết lập AI',
  notifications: 'Hệ thống thông báo',
}

export default function TopBar({ darkMode, onToggleDark, activePage }) {
  return (
    <header className="h-16 bg-white dark:bg-gray-900 border-b border-gray-100 dark:border-gray-800 flex items-center px-6 gap-4 flex-shrink-0">
      {/* Title */}
      <div className="flex-1">
        <h1 className="text-base font-bold text-gray-900 dark:text-white">
          {PAGE_TITLES[activePage] || 'Admin'}
        </h1>
        <p className="text-xs text-gray-400">
          {new Date().toLocaleDateString('vi-VN', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}
        </p>
      </div>

      {/* Search */}
      <div className="relative hidden md:block">
        <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
        <input
          type="text"
          placeholder="Tìm kiếm..."
          className="pl-9 pr-4 py-2 text-sm bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl w-56 focus:outline-none focus:ring-2 focus:ring-teal-500/30 focus:border-teal-500 dark:text-gray-200 transition-all"
        />
      </div>

      {/* Actions */}
      <div className="flex items-center gap-2">
        <button
          onClick={onToggleDark}
          className="w-9 h-9 rounded-xl bg-gray-50 dark:bg-gray-800 flex items-center justify-center text-gray-500 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-700 transition-all"
          title={darkMode ? 'Light mode' : 'Dark mode'}
        >
          {darkMode ? <Sun size={16} /> : <Moon size={16} />}
        </button>

        <button className="w-9 h-9 rounded-xl bg-gray-50 dark:bg-gray-800 flex items-center justify-center text-gray-500 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-700 transition-all">
          <RefreshCw size={16} />
        </button>

        <button className="relative w-9 h-9 rounded-xl bg-gray-50 dark:bg-gray-800 flex items-center justify-center text-gray-500 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-700 transition-all">
          <Bell size={16} />
          <span className="absolute top-1.5 right-1.5 w-2 h-2 bg-red-500 rounded-full" />
        </button>

        <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-teal-500 to-cyan-400 flex items-center justify-center text-white text-xs font-bold cursor-pointer">
          A
        </div>
      </div>
    </header>
  )
}
