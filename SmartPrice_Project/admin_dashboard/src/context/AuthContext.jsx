import { createContext, useContext, useState, useCallback } from 'react'
import { authService } from '../api/authService'

// ── Context ───────────────────────────────────────────────────────────────────
const AuthContext = createContext(null)

/**
 * AuthProvider — bọc toàn bộ app.
 * Cung cấp: user, isAuthenticated, login(), logout(), isLoading, error
 */
export function AuthProvider({ children }) {
  const [user, setUser]         = useState(() => authService.getCurrentUser())
  const [isLoading, setLoading] = useState(false)
  const [error, setError]       = useState(null)

  const login = useCallback(async (email, password) => {
    setLoading(true)
    setError(null)
    try {
      const data = await authService.login(email, password)
      setUser({ userId: data.userId, name: data.name, email: data.email })
      return true
    } catch (err) {
      setError(err.message)
      return false
    } finally {
      setLoading(false)
    }
  }, [])

  const logout = useCallback(() => {
    authService.logout()
    setUser(null)
  }, [])

  return (
    <AuthContext.Provider value={{
      user,
      isAuthenticated: !!user,
      login,
      logout,
      isLoading,
      error,
    }}>
      {children}
    </AuthContext.Provider>
  )
}

/** Hook tiện lợi để dùng AuthContext. */
export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth phải được dùng bên trong AuthProvider')
  return ctx
}
