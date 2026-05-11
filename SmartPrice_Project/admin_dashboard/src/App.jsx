import { useState, Component } from 'react'
import { AuthProvider, useAuth } from './context/AuthContext'
import Sidebar from './components/Sidebar'
import TopBar from './components/TopBar'
import LoginPage from './pages/LoginPage'
import OverviewPage from './pages/OverviewPage'
import UsersPage from './pages/UsersPage'
import TransactionsPage from './pages/TransactionsPage'
import AiSettingsPage from './pages/AiSettingsPage'
import NotificationsPage from './pages/NotificationsPage'

// ── Error Boundary ────────────────────────────────────────────────────────────
class ErrorBoundary extends Component {
  constructor(props) { super(props); this.state = { error: null } }
  static getDerivedStateFromError(error) { return { error } }
  render() {
    if (this.state.error) {
      return (
        <div className="flex items-center justify-center h-screen bg-gray-50">
          <div className="text-center p-8 bg-white rounded-2xl shadow-sm border border-gray-100 max-w-md">
            <div className="text-4xl mb-4">⚠️</div>
            <h2 className="text-lg font-bold text-gray-800 mb-2">Có lỗi xảy ra</h2>
            <p className="text-sm text-gray-500 mb-4 font-mono bg-gray-50 p-3 rounded-lg text-left">
              {this.state.error?.message ?? String(this.state.error)}
            </p>
            <button
              onClick={() => this.setState({ error: null })}
              className="px-4 py-2 bg-teal-600 text-white text-sm font-semibold rounded-xl hover:bg-teal-700"
            >
              Thử lại
            </button>
          </div>
        </div>
      )
    }
    return this.props.children
  }
}

const PAGES = {
  overview:      OverviewPage,
  users:         UsersPage,
  transactions:  TransactionsPage,
  ai:            AiSettingsPage,
  notifications: NotificationsPage,
}

// ── Inner app (requires auth) ─────────────────────────────────────────────────
function AdminApp() {
  const { isAuthenticated } = useAuth()
  const [activePage, setActivePage] = useState('overview')
  const [darkMode, setDarkMode]     = useState(false)

  if (!isAuthenticated) {
    return (
      <div className={darkMode ? 'dark' : ''}>
        <LoginPage />
      </div>
    )
  }

  const PageComponent = PAGES[activePage] || OverviewPage

  return (
    <div className={darkMode ? 'dark' : ''}>
      <div className="flex h-screen bg-[#F8F9FA] dark:bg-gray-950 overflow-hidden">
        <Sidebar active={activePage} onNavigate={setActivePage} />
        <div className="flex-1 flex flex-col overflow-hidden">
          <TopBar
            darkMode={darkMode}
            onToggleDark={() => setDarkMode(d => !d)}
            activePage={activePage}
          />
          <main className="flex-1 overflow-y-auto p-6 scrollbar-thin">
            <PageComponent />
          </main>
        </div>
      </div>
    </div>
  )
}

// ── Root ──────────────────────────────────────────────────────────────────────
export default function App() {
  return (
    <ErrorBoundary>
      <AuthProvider>
        <AdminApp />
      </AuthProvider>
    </ErrorBoundary>
  )
}
