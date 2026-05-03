import { TrendingUp, TrendingDown } from 'lucide-react'

export default function MetricCard({ icon: Icon, iconBg, title, value, badge, badgeColor, sub, trend, trendUp }) {
  return (
    <div className="bg-white dark:bg-gray-900 rounded-2xl p-5 shadow-sm border border-gray-100 dark:border-gray-800 hover:shadow-md transition-shadow">
      <div className="flex items-start justify-between mb-4">
        <div className={`w-11 h-11 rounded-xl flex items-center justify-center ${iconBg}`}>
          <Icon size={20} className="text-white" />
        </div>
        {trend && (
          <span className={`flex items-center gap-1 text-xs font-semibold px-2 py-1 rounded-full ${
            trendUp
              ? 'bg-emerald-50 text-emerald-600 dark:bg-emerald-900/30 dark:text-emerald-400'
              : 'bg-red-50 text-red-500 dark:bg-red-900/30 dark:text-red-400'
          }`}>
            {trendUp ? <TrendingUp size={11} /> : <TrendingDown size={11} />}
            {trend}
          </span>
        )}
      </div>
      <p className="text-2xl font-extrabold text-gray-900 dark:text-white tracking-tight">{value}</p>
      <p className="text-sm text-gray-500 dark:text-gray-400 mt-0.5">{title}</p>
      {sub && <p className="text-xs text-gray-400 dark:text-gray-500 mt-1">{sub}</p>}
      {badge && (
        <span className={`inline-block mt-2 text-[10px] font-semibold px-2 py-0.5 rounded-full ${badgeColor}`}>
          {badge}
        </span>
      )}
    </div>
  )
}
