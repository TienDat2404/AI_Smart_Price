// ── Chart data ────────────────────────────────────────────────────────────────
export const chartData6M = [
  { month: 'Th7',  income: 38000, expense: 24000, transactions: 1820 },
  { month: 'Th8',  income: 42000, expense: 28000, transactions: 2100 },
  { month: 'Th9',  income: 39000, expense: 22000, transactions: 1950 },
  { month: 'Th10', income: 47000, expense: 31000, transactions: 2340 },
  { month: 'Th11', income: 44000, expense: 27000, transactions: 2180 },
  { month: 'Th12', income: 52000, expense: 35000, transactions: 2600 },
]

export const chartData12M = [
  { month: 'Th1',  income: 30000, expense: 18000, transactions: 1400 },
  { month: 'Th2',  income: 28000, expense: 16000, transactions: 1300 },
  { month: 'Th3',  income: 33000, expense: 20000, transactions: 1600 },
  { month: 'Th4',  income: 36000, expense: 22000, transactions: 1750 },
  { month: 'Th5',  income: 35000, expense: 21000, transactions: 1700 },
  { month: 'Th6',  income: 40000, expense: 25000, transactions: 1900 },
  { month: 'Th7',  income: 38000, expense: 24000, transactions: 1820 },
  { month: 'Th8',  income: 42000, expense: 28000, transactions: 2100 },
  { month: 'Th9',  income: 39000, expense: 22000, transactions: 1950 },
  { month: 'Th10', income: 47000, expense: 31000, transactions: 2340 },
  { month: 'Th11', income: 44000, expense: 27000, transactions: 2180 },
  { month: 'Th12', income: 52000, expense: 35000, transactions: 2600 },
]

// ── Users ─────────────────────────────────────────────────────────────────────
export const recentUsers = [
  { id: 1, name: 'Nguyễn Văn An',   email: 'an.nguyen@gmail.com',    joined: '12/12/2024', tier: 'Hạng vàng',  score: 850, active: true  },
  { id: 2, name: 'Trần Thị Bình',   email: 'binh.tran@outlook.com',  joined: '10/12/2024', tier: 'Hạng bạc',   score: 720, active: true  },
  { id: 3, name: 'Lê Minh Cường',   email: 'cuong.le@yahoo.com',     joined: '08/12/2024', tier: 'Hạng vàng',  score: 910, active: true  },
  { id: 4, name: 'Phạm Thu Dung',   email: 'dung.pham@gmail.com',    joined: '05/12/2024', tier: 'Hạng bạc',   score: 680, active: false },
  { id: 5, name: 'Hoàng Văn Em',    email: 'em.hoang@gmail.com',     joined: '01/12/2024', tier: 'Hạng đồng',  score: 540, active: true  },
  { id: 6, name: 'Vũ Thị Phương',   email: 'phuong.vu@company.vn',   joined: '28/11/2024', tier: 'Hạng vàng',  score: 880, active: true  },
]

// ── OCR Logs ──────────────────────────────────────────────────────────────────
export const ocrLogs = [
  { id: 1, time: '14:32:01', user: 'Nguyễn Văn An',  store: 'WinMart Q1',    amount: '245,000đ', status: 'success', confidence: 97 },
  { id: 2, time: '14:28:45', user: 'Trần Thị Bình',  store: 'Circle K',      amount: '89,000đ',  status: 'success', confidence: 94 },
  { id: 3, time: '14:15:22', user: 'Lê Minh Cường',  store: 'Không rõ',      amount: '—',        status: 'failed',  confidence: 31 },
  { id: 4, time: '13:58:10', user: 'Phạm Thu Dung',  store: 'Grab Food',     amount: '125,000đ', status: 'success', confidence: 99 },
  { id: 5, time: '13:44:33', user: 'Hoàng Văn Em',   store: 'Shopee',        amount: '450,000đ', status: 'success', confidence: 88 },
  { id: 6, time: '13:30:05', user: 'Vũ Thị Phương',  store: 'Không rõ',      amount: '—',        status: 'failed',  confidence: 22 },
]

// ── Recent transactions ───────────────────────────────────────────────────────
export const recentTransactions = [
  { id: 1, user: 'Nguyễn Văn An',  type: 'Chi tiêu',    category: 'Ăn uống',    amount: -245000, date: '12/12/2024', status: 'completed' },
  { id: 2, user: 'Trần Thị Bình',  type: 'Thu nhập',    category: 'Lương',       amount: 15000000, date: '10/12/2024', status: 'completed' },
  { id: 3, user: 'Lê Minh Cường',  type: 'Điều chỉnh',  category: 'Cân bằng ví', amount: 500000,  date: '08/12/2024', status: 'pending'   },
  { id: 4, user: 'Phạm Thu Dung',  type: 'Chi tiêu',    category: 'Mua sắm',    amount: -1200000, date: '05/12/2024', status: 'completed' },
  { id: 5, user: 'Hoàng Văn Em',   type: 'Chi tiêu',    category: 'Di chuyển',  amount: -85000,  date: '01/12/2024', status: 'completed' },
  { id: 6, user: 'Vũ Thị Phương',  type: 'Thu nhập',    category: 'Freelance',  amount: 5000000, date: '28/11/2024', status: 'completed' },
]

// ── System health ─────────────────────────────────────────────────────────────
export const systemHealth = [
  { label: 'Độ trễ cơ sở dữ liệu', value: 12, unit: 'ms', max: 100, color: 'bg-emerald-500', status: 'Tốt' },
  { label: 'Dung lượng lưu trữ',    value: 64, unit: '%',  max: 100, color: 'bg-amber-400',   status: 'Bình thường' },
  { label: 'API Uptime',            value: 99.9, unit: '%', max: 100, color: 'bg-teal-500',   status: 'Xuất sắc' },
]
