import React, { useEffect, useMemo, useState } from 'react'
import { useParams, Link } from 'react-router-dom'
import { api } from '../api'

export default function Project() {
  const { id } = useParams()
  const projectId = Number(id)

  const [dashboard, setDashboard] = useState<any | null>(null)
  const [errors, setErrors] = useState<any[]>([])
  const [flaky, setFlaky] = useState<any[]>([])
  const [runs, setRuns] = useState<any[]>([])
  const [err, setErr] = useState<string | null>(null)
  const [similar, setSimilar] = useState<any[] | null>(null)
  const [similarFor, setSimilarFor] = useState<string | null>(null)

  async function loadAll() {
    setErr(null)
    try {
      const [d, e, f, r] = await Promise.all([
        api.dashboard(projectId),
        api.topErrors(projectId),
        api.flaky(projectId),
        api.listRuns(projectId)
      ])
      setDashboard(d)
      setErrors(e.errors || [])
      setFlaky(f.flaky || [])
      setRuns(r.runs || [])
    } catch (e: any) {
      setErr(e?.error?.message || 'Failed to load project')
    }
  }

  useEffect(() => {
    if (!Number.isFinite(projectId)) return
    loadAll()
  }, [projectId])

  async function showSimilar(fp: string) {
    try {
      const res = await api.similarInProject(projectId, fp)
      setSimilar(res.similar || [])
      setSimilarFor(fp)
    } catch {
      setSimilar([])
      setSimilarFor(fp)
    }
  }

  const passRate = useMemo(() => {
    if (!dashboard) return null
    const v = dashboard.passRate
    return typeof v === 'number' ? v : Number(v)
  }, [dashboard])

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
        <h3 style={{ margin: 0 }}>Project #{projectId}</h3>
        <Link to="/">← back</Link>
      </div>

      {err && <div style={{ color: 'crimson', marginTop: 8 }}>{err}</div>}

      {dashboard && (
        <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap', marginTop: 14 }}>
          <Card title="Pass rate">{passRate?.toFixed?.(1) ?? passRate}%</Card>
          <Card title="Passed">{dashboard.passCount}</Card>
          <Card title="Failed">{dashboard.failCount}</Card>
          <Card title="Total">{dashboard.totalCount}</Card>
        </div>
      )}

      <h4 style={{ marginTop: 22 }}>Recent runs</h4>
      <table style={tableStyle}>
        <thead>
          <tr>
            <th style={thLeft}>Run</th>
            <th style={thLeft}>Branch</th>
            <th style={thLeft}>Commit</th>
            <th style={thRight}>Passed</th>
            <th style={thRight}>Failed</th>
            <th style={thRight}>Total</th>
            <th style={thLeft}>Status</th>
            <th style={thLeft}>Created</th>
          </tr>
        </thead>
        <tbody>
          {runs.map((r) => (
            <tr key={r.runId}>
              <td style={td}><Link to={`/runs/${r.runId}`}>#{r.runId}</Link></td>
              <td style={td}>{r.branch || '-'}</td>
              <td style={td}><code>{(r.commitSha || '').slice(0, 10) || '-'}</code></td>
              <td style={tdRight}>{r.passed ?? 0}</td>
              <td style={tdRight}>{r.failed ?? 0}</td>
              <td style={tdRight}>{r.total ?? 0}</td>
              <td style={td}>{r.status}</td>
              <td style={td}>{String(r.createdAt || '').slice(0, 19).replace('T', ' ')}</td>
            </tr>
          ))}
          {runs.length === 0 && (
            <tr>
              <td colSpan={8} style={{ ...td, color: '#666' }}>No runs yet. Use the demo ingest script to push a run.</td>
            </tr>
          )}
        </tbody>
      </table>

      <h4 style={{ marginTop: 22 }}>Top errors (fingerprints)</h4>
      <table style={tableStyle}>
        <thead>
          <tr>
            <th style={thLeft}>Fingerprint</th>
            <th style={thRight}>Occurrences</th>
            <th style={thLeft}>Sample</th>
            <th style={thLeft}>Similar</th>
          </tr>
        </thead>
        <tbody>
          {errors.map((e) => (
            <tr key={e.fingerprint}>
              <td style={td}><code>{e.fingerprint}</code></td>
              <td style={tdRight}>{e.occurrences}</td>
              <td style={{ ...td, color: '#444' }}>{e.sampleMessage}</td>
              <td style={td}>
                <button onClick={() => showSimilar(e.fingerprint)} style={btn}>View</button>
              </td>
            </tr>
          ))}
          {errors.length === 0 && (
            <tr><td colSpan={4} style={{ ...td, color: '#666' }}>No errors yet.</td></tr>
          )}
        </tbody>
      </table>

      {similar && (
        <div style={{ marginTop: 12, padding: 12, border: '1px solid #ddd', borderRadius: 10 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12 }}>
            <strong>Similar to <code>{similarFor}</code></strong>
            <button onClick={() => { setSimilar(null); setSimilarFor(null) }} style={btn}>Close</button>
          </div>
          {similar.length === 0 ? (
            <div style={{ color: '#666', marginTop: 8 }}>No similar errors found.</div>
          ) : (
            <ul style={{ marginTop: 8 }}>
              {similar.map((s) => (
                <li key={s.fingerprint}>
                  <code>{s.fingerprint}</code> — score: {s.score} — {s.message}
                </li>
              ))}
            </ul>
          )}
        </div>
      )}

      <h4 style={{ marginTop: 22 }}>Flaky tests</h4>
      <table style={tableStyle}>
        <thead>
          <tr>
            <th style={thLeft}>Test</th>
            <th style={thRight}>Fail rate</th>
            <th style={thRight}>Flaky score</th>
            <th style={thRight}>Total</th>
          </tr>
        </thead>
        <tbody>
          {flaky.map((t) => (
            <tr key={t.name}>
              <td style={td}>{t.name}</td>
              <td style={tdRight}>{Number(t.failRate).toFixed(1)}%</td>
              <td style={tdRight}>{t.flakyScore ?? 0}</td>
              <td style={tdRight}>{t.total}</td>
            </tr>
          ))}
          {flaky.length === 0 && (
            <tr><td colSpan={4} style={{ ...td, color: '#666' }}>Not enough history yet.</td></tr>
          )}
        </tbody>
      </table>

      <div style={{ marginTop: 18 }}>
        <button onClick={loadAll} style={btn}>Refresh</button>
      </div>
    </div>
  )
}

function Card({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div style={{ border: '1px solid #ddd', borderRadius: 10, padding: 12, minWidth: 160 }}>
      <div style={{ color: '#666', fontSize: 12 }}>{title}</div>
      <div style={{ fontSize: 22, marginTop: 4 }}>{children}</div>
    </div>
  )
}

const tableStyle: React.CSSProperties = { width: '100%', borderCollapse: 'collapse' }
const thLeft: React.CSSProperties = { textAlign: 'left', borderBottom: '1px solid #ddd', padding: 8 }
const thRight: React.CSSProperties = { textAlign: 'right', borderBottom: '1px solid #ddd', padding: 8 }
const td: React.CSSProperties = { padding: 8, borderBottom: '1px solid #f1f1f1', verticalAlign: 'top' }
const tdRight: React.CSSProperties = { ...td, textAlign: 'right' }
const btn: React.CSSProperties = { padding: '6px 10px', border: '1px solid #ccc', borderRadius: 8, background: 'white', cursor: 'pointer' }
