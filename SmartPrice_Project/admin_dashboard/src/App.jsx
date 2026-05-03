import { useState } from 'react'
import { AuthProvider, useAuth } from './context/AuthContext'
import Sidebar from './components/Sidebar'
import TopBar from './components/TopBar'
import LoginPage from './pages/LoginPage'
import OverviewPage from './pages/OverviewPage'
import UsersPage from './pages/UsersPage'
import TransactionsPage from './pages/TransactionsPage'
import AiSettingsPage from './pages/AiSettingsPage'
import NotificationsPage from './pages/NotificationsPage'

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
    <AuthProvider>
      <AdminApp />
    </AuthProvider>
  )
}
