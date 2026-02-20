import React, { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { api, setToken } from '../api'

export default function Login() {
  const nav = useNavigate()
  const [email, setEmail] = useState('admin@testops.local')
  const [password, setPassword] = useState('admin123')
  const [mode, setMode] = useState<'login' | 'register'>('login')
  const [err, setErr] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)

  async function submit() {
    setErr(null)
    setLoading(true)
    try {
      const res = mode === 'login' ? await api.login(email, password) : await api.register(email, password)
      setToken(res.token)
      nav('/')
    } catch (e: any) {
      setErr(e?.error?.message || 'Request failed')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div style={{ maxWidth: 520 }}>
      <h3>{mode === 'login' ? 'Login' : 'Register'}</h3>
      <p style={{ color: '#555' }}>
        API is proxied to IRIS at <code>/api</code>
      </p>
      <div style={{ display: 'grid', gap: 10 }}>
        <label>
          Email
          <input value={email} onChange={(e) => setEmail(e.target.value)} style={{ width: '100%', padding: 8 }} />
        </label>
        <label>
          Password
          <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} style={{ width: '100%', padding: 8 }} />
        </label>
        {err && <div style={{ color: 'crimson' }}>{err}</div>}
        <button disabled={loading} onClick={submit} style={{ padding: 10 }}>
          {loading ? '...' : mode === 'login' ? 'Login' : 'Create account'}
        </button>
        <button
          onClick={() => setMode(mode === 'login' ? 'register' : 'login')}
          style={{ padding: 10, background: 'transparent', border: '1px solid #ccc' }}
        >
          Switch to {mode === 'login' ? 'Register' : 'Login'}
        </button>
      </div>
    </div>
  )
}
