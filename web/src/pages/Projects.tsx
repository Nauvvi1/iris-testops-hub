import React, { useEffect, useState } from 'react'
import { api } from '../api'
import { Link } from 'react-router-dom'

export default function Projects() {
  const [projects, setProjects] = useState<any[]>([])
  const [name, setName] = useState('')
  const [err, setErr] = useState<string | null>(null)

  async function load() {
    setErr(null)
    try {
      const res = await api.listProjects()
      setProjects(res.projects || [])
    } catch (e: any) {
      setErr(e?.error?.message || 'Failed to load projects')
    }
  }

  useEffect(() => {
    load()
  }, [])

  async function create() {
    if (!name.trim()) return
    setErr(null)
    try {
      await api.createProject(name.trim())
      setName('')
      await load()
    } catch (e: any) {
      setErr(e?.error?.message || 'Create failed')
    }
  }

  async function del(id: number) {
    if (!confirm('Delete project?')) return
    setErr(null)
    try {
      await api.deleteProject(id)
      await load()
    } catch (e: any) {
      setErr(e?.error?.message || 'Delete failed')
    }
  }

  async function rotate(id: number) {
    if (!confirm('Rotate ingest token? Existing CI integrations will need the new token.')) return
    setErr(null)
    try {
      await api.rotateProjectToken(id)
      await load()
    } catch (e: any) {
      setErr(e?.error?.message || 'Rotate failed')
    }
  }

  return (
    <div>
      <h3>Projects</h3>
      <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 12 }}>
        <input placeholder="New project name" value={name} onChange={(e) => setName(e.target.value)} style={{ padding: 8, width: 320 }} />
        <button onClick={create} style={{ padding: 8 }}>Create</button>
      </div>
      {err && <div style={{ color: 'crimson' }}>{err}</div>}
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead>
          <tr>
            <th style={{ textAlign: 'left', borderBottom: '1px solid #ddd', padding: 8 }}>Name</th>
            <th style={{ textAlign: 'left', borderBottom: '1px solid #ddd', padding: 8 }}>Ingest Token</th>
            <th style={{ textAlign: 'left', borderBottom: '1px solid #ddd', padding: 8 }}>Actions</th>
          </tr>
        </thead>
        <tbody>
          {projects.map((p) => (
            <tr key={p.id}>
              <td style={{ padding: 8 }}>
                <Link to={`/projects/${p.id}`}>{p.name}</Link>
              </td>
              <td style={{ padding: 8 }}>
                <code>{p.ingestToken}</code>
              </td>
              <td style={{ padding: 8 }}>
                <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                  <button onClick={() => rotate(p.id)} style={{ padding: 6 }}>Rotate token</button>
                  <button onClick={() => del(p.id)} style={{ padding: 6 }}>Delete</button>
                </div>
              </td>
            </tr>
          ))}
          {projects.length === 0 && (
            <tr>
              <td colSpan={3} style={{ padding: 12, color: '#666' }}>
                No projects yet. Create one and ingest data using <code>demo/ingest-example.sh</code>.
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  )
}
