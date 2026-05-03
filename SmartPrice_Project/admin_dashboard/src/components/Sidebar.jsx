import {
  LayoutDashboard, Users, ArrowLeftRight,
  Bot, Bell, Settings, LogOut, Sparkles
} from 'lucide-react'

const NAV = [
  { id: 'overview',      icon: LayoutDashboard, label: 'Tổng quan' },
  { id: 'users',         icon: Users,           label: 'Người dùng' },
  { id: 'transactions',  icon: ArrowLeftRight,  label: 'Giao dịch' },
  { id: 'ai',            icon: Bot,             label: 'Thiết lập AI' },
  { id: 'notifications', icon: Bell,            label: 'Thông báo' },
]

export default function Sidebar({ active, onNavigate }) {
  return (
    <aside className="w-64 bg-white dark:bg-gray-900 border-r border-gray-100 dark:border-gray-800 flex flex-col h-full shadow-sm flex-shrink-0">
      {/* Logo */}
      <div className="px-6 py-5 border-b border-gray-100 dark:border-gray-800">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-teal-600 to-cyan-400 flex items-center justify-center shadow-md">
            <Sparkles size={18} className="text-white" />
          </div>
          <div>
            <p className="text-sm font-800 font-extrabold text-gray-900 dark:text-white leading-tight">SmartPrice AI</p>
            <p className="text-[10px] text-teal-600 font-semibold tracking-wide uppercase">Admin Panel</p>
          </div>
        </div>
      </div>

      {/* Nav */}
      <nav className="flex-1 px-3 py-4 space-y-1 overflow-y-auto">
        <p className="px-3 mb-2 text-[10px] font-bold text-gray-400 uppercase tracking-widest">Menu chính</p>
        {NAV.map(({ id, icon: Icon, label }) => {
          const isActive = active === id
          return (
            <button
              key={id}
              onClick={() => onNavigate(id)}
              className={`
                w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium
                transition-all duration-150 relative group
                ${isActive
                  ? 'bg-teal-50 dark:bg-teal-900/30 text-teal-700 dark:text-teal-300 font-semibold'
                  : 'text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800 hover:text-gray-700 dark:hover:text-gray-200'
                }
              `}
            >
              {/* Active indicator */}
              {isActive && (
                <span className="absolute left-0 top-1/2 -translate-y-1/2 w-1 h-6 bg-teal-600 rounded-r-full" />
              )}
              <Icon size={18} className={isActive ? 'text-teal-600 dark:text-teal-400' : ''} />
              {label}
            </button>
          )
        })}
      </nav>

      {/* Bottom */}
      <div className="px-3 py-4 border-t border-gray-100 dark:border-gray-800 space-y-1">
        <button className="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800 transition-all">
          <Settings size={18} />
          Cài đặt hệ thống
        </button>
        <button className="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20 transition-all">
          <LogOut size={18} />
          Đăng xuất
        </button>
        {/* Admin info */}
        <div className="mt-3 px-3 py-3 bg-gray-50 dark:bg-gray-800 rounded-xl flex items-center gap-3">
          <div className="w-8 h-8 rounded-full bg-gradient-to-br from-teal-500 to-cyan-400 flex items-center justify-center text-white text-xs font-bold flex-shrink-0">
            A
          </div>
          <div className="min-w-0">
            <p className="text-xs font-semibold text-gray-800 dark:text-gray-200 truncate">Admin</p>
            <p className="text-[10px] text-gray-400 truncate">admin@smartprice.ai</p>
          </div>
        </div>
      </div>
    </aside>
  )
}
