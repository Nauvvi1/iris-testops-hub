import React from 'react'
import { Routes, Route, Navigate, Link, useNavigate } from 'react-router-dom'
import { getToken, setToken } from './api'
import Login from './pages/Login'
import Projects from './pages/Projects'
import Project from './pages/Project'
import Run from './pages/Run'

function Layout({ children }: { children: React.ReactNode }) {
  const nav = useNavigate()
  const token = getToken()
  return (
    <div style={{ fontFamily: 'system-ui, -apple-system, Segoe UI, Roboto, Arial', maxWidth: 1100, margin: '0 auto', padding: 16 }}>
      <header style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12 }}>
        <Link to="/" style={{ textDecoration: 'none', color: '#111' }}>
          <h2 style={{ margin: 0 }}>IRIS TestOps Hub</h2>
        </Link>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          {token ? (
            <button
              onClick={() => {
                setToken(null)
                nav('/login')
              }}
            >
              Logout
            </button>
          ) : (
            <Link to="/login">Login</Link>
          )}
        </div>
      </header>
      <hr />
      {children}
    </div>
  )
}

function PrivateRoute({ children }: { children: React.ReactNode }) {
  const token = getToken()
  if (!token) return <Navigate to="/login" replace />
  return <>{children}</>
}

export default function App() {
  return (
    <Layout>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route
          path="/"
          element={
            <PrivateRoute>
              <Projects />
            </PrivateRoute>
          }
        />
        <Route
          path="/projects/:id"
          element={
            <PrivateRoute>
              <Project />
            </PrivateRoute>
          }
        />
        <Route
          path="/runs/:id"
          element={
            <PrivateRoute>
              <Run />
            </PrivateRoute>
          }
        />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </Layout>
  )
}
