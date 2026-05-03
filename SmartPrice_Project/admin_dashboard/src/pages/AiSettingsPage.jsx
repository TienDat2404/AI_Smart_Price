import { useState } from 'react'
import { CheckCircle, XCircle, Bot, ScanLine, Sliders, RefreshCw } from 'lucide-react'
import { ocrLogs } from '../data/mockData'

function ConfidenceBadge({ value }) {
  const color = value >= 80 ? 'text-emerald-600 bg-emerald-50 dark:bg-emerald-900/30 dark:text-emerald-400'
              : value >= 50 ? 'text-amber-600 bg-amber-50 dark:bg-amber-900/30 dark:text-amber-400'
              : 'text-red-500 bg-red-50 dark:bg-red-900/30 dark:text-red-400'
  return (
    <span className={`text-[11px] font-bold px-2 py-0.5 rounded-full ${color}`}>{value}%</span>
  )
}

export default function AiSettingsPage() {
  const [ocrThreshold, setOcrThreshold] = useState(75)
  const [nlpModel, setNlpModel]         = useState('vi-finance-v2')
  const [autoRetry, setAutoRetry]       = useState(true)
  const [smartReminder, setSmartReminder] = useState(true)
  const [budgetAlert, setBudgetAlert]   = useState(80)

  const successCount = ocrLogs.filter(l => l.status === 'success').length
  const successRate  = Math.round(successCount / ocrLogs.length * 100)

  return (
    <div className="space-y-6">

      {/* OCR stats */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        {[
          { label: 'Tổng lần quét',    value: ocrLogs.length,  color: 'text-teal-600' },
          { label: 'Thành công',        value: successCount,    color: 'text-emerald-600' },
          { label: 'Thất bại',          value: ocrLogs.length - successCount, color: 'text-red-500' },
          { label: 'Tỷ lệ thành công', value: `${successRate}%`, color: 'text-cyan-600' },
        ].map(s => (
          <div key={s.label} className="bg-white dark:bg-gray-900 rounded-2xl p-4 shadow-sm border border-gray-100 dark:border-gray-800">
            <p className={`text-2xl font-extrabold ${s.color}`}>{s.value}</p>
            <p className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">{s.label}</p>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">

        {/* OCR Log table */}
        <div className="lg:col-span-2 bg-white dark:bg-gray-900 rounded-2xl shadow-sm border border-gray-100 dark:border-gray-800 overflow-hidden">
          <div className="px-6 py-4 border-b border-gray-100 dark:border-gray-800 flex items-center justify-between">
            <div className="flex items-center gap-2">
              <ScanLine size={16} className="text-teal-600" />
              <h2 className="text-sm font-bold text-gray-900 dark:text-white">Nhật ký OCR gần đây</h2>
            </div>
            <button className="w-7 h-7 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 flex items-center justify-center text-gray-400 transition-colors">
              <RefreshCw size={14} />
            </button>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="bg-gray-50 dark:bg-gray-800/50">
                  {['Thời gian', 'Người dùng', 'Cửa hàng', 'Số tiền', 'Độ tin cậy', 'Kết quả'].map(h => (
                    <th key={h} className="px-5 py-3 text-left text-[11px] font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider whitespace-nowrap">
                      {h}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-50 dark:divide-gray-800">
                {ocrLogs.map(log => (
                  <tr key={log.id} className="hover:bg-gray-50/50 dark:hover:bg-gray-800/30 transition-colors">
                    <td className="px-5 py-3 text-xs font-mono text-gray-500 dark:text-gray-400 whitespace-nowrap">{log.time}</td>
                    <td className="px-5 py-3 text-sm text-gray-700 dark:text-gray-300 whitespace-nowrap">{log.user}</td>
                    <td className="px-5 py-3 text-sm text-gray-500 dark:text-gray-400">{log.store}</td>
                    <td className="px-5 py-3 text-sm font-semibold text-gray-800 dark:text-gray-200">{log.amount}</td>
                    <td className="px-5 py-3"><ConfidenceBadge value={log.confidence} /></td>
                    <td className="px-5 py-3">
                      {log.status === 'success'
                        ? <CheckCircle size={16} className="text-emerald-500" />
                        : <XCircle size={16} className="text-red-400" />
                      }
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        {/* AI Config panel */}
        <div className="space-y-4">
          {/* OCR config */}
          <div className="bg-white dark:bg-gray-900 rounded-2xl p-5 shadow-sm border border-gray-100 dark:border-gray-800">
            <div className="flex items-center gap-2 mb-4">
              <Sliders size={16} className="text-teal-600" />
              <h3 className="text-sm font-bold text-gray-900 dark:text-white">Cấu hình OCR</h3>
            </div>
            <div className="space-y-4">
              <div>
                <div className="flex justify-between mb-1.5">
                  <label className="text-xs text-gray-600 dark:text-gray-400">Ngưỡng tin cậy tối thiểu</label>
                  <span className="text-xs font-bold text-teal-600">{ocrThreshold}%</span>
                </div>
                <input
                  type="range" min={50} max={99} value={ocrThreshold}
                  onChange={e => setOcrThreshold(+e.target.value)}
                  className="w-full h-1.5 bg-gray-200 dark:bg-gray-700 rounded-full appearance-none cursor-pointer accent-teal-600"
                />
                <div className="flex justify-between text-[10px] text-gray-400 mt-1">
                  <span>50%</span><span>99%</span>
                </div>
              </div>

              <div className="flex items-center justify-between">
                <div>
                  <p className="text-xs font-semibold text-gray-700 dark:text-gray-300">Tự động thử lại</p>
                  <p className="text-[10px] text-gray-400">Khi độ tin cậy thấp</p>
                </div>
                <button
                  onClick={() => setAutoRetry(v => !v)}
                  className={`relative w-10 h-5 rounded-full transition-colors ${autoRetry ? 'bg-teal-500' : 'bg-gray-300 dark:bg-gray-600'}`}
                >
                  <span className={`absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-transform ${autoRetry ? 'translate-x-5' : 'translate-x-0.5'}`} />
                </button>
              </div>

              <div>
                <label className="text-xs text-gray-600 dark:text-gray-400 block mb-1.5">Model NLP</label>
                <select
                  value={nlpModel}
                  onChange={e => setNlpModel(e.target.value)}
                  className="w-full text-sm bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl px-3 py-2 focus:outline-none focus:ring-2 focus:ring-teal-500/30 dark:text-gray-200"
                >
                  <option value="vi-finance-v1">vi-finance-v1 (cũ)</option>
                  <option value="vi-finance-v2">vi-finance-v2 (hiện tại)</option>
                  <option value="vi-finance-v3">vi-finance-v3 (beta)</option>
                </select>
              </div>
            </div>
          </div>

          {/* Smart assistant config */}
          <div className="bg-white dark:bg-gray-900 rounded-2xl p-5 shadow-sm border border-gray-100 dark:border-gray-800">
            <div className="flex items-center gap-2 mb-4">
              <Bot size={16} className="text-cyan-600" />
              <h3 className="text-sm font-bold text-gray-900 dark:text-white">Trợ lý thông minh</h3>
            </div>
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-xs font-semibold text-gray-700 dark:text-gray-300">Nhắc nhở chi tiêu</p>
                  <p className="text-[10px] text-gray-400">Gửi thông báo tự động</p>
                </div>
                <button
                  onClick={() => setSmartReminder(v => !v)}
                  className={`relative w-10 h-5 rounded-full transition-colors ${smartReminder ? 'bg-teal-500' : 'bg-gray-300 dark:bg-gray-600'}`}
                >
                  <span className={`absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-transform ${smartReminder ? 'translate-x-5' : 'translate-x-0.5'}`} />
                </button>
              </div>

              <div>
                <div className="flex justify-between mb-1.5">
                  <label className="text-xs text-gray-600 dark:text-gray-400">Ngưỡng cảnh báo ngân sách</label>
                  <span className="text-xs font-bold text-amber-500">{budgetAlert}%</span>
                </div>
                <input
                  type="range" min={50} max={100} value={budgetAlert}
                  onChange={e => setBudgetAlert(+e.target.value)}
                  className="w-full h-1.5 bg-gray-200 dark:bg-gray-700 rounded-full appearance-none cursor-pointer accent-amber-500"
                />
              </div>
            </div>
          </div>

          <button className="w-full py-2.5 bg-gradient-to-r from-teal-600 to-cyan-500 text-white text-sm font-bold rounded-xl hover:opacity-90 transition-opacity shadow-md">
            Lưu cấu hình
          </button>
        </div>
      </div>
    </div>
  )
}
