import React, { useEffect, useMemo, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { api } from '../api'

export default function Run() {
  const { id } = useParams()
  const runId = Number(id)

  const [data, setData] = useState<any | null>(null)
  const [diff, setDiff] = useState<any | null>(null)
  const [err, setErr] = useState<string | null>(null)
  const [note, setNote] = useState<Record<number, string>>({})
  const [uploading, setUploading] = useState<string | null>(null)

  async function loadAll() {
    setErr(null)
    try {
      const [r, d] = await Promise.all([api.getRun(runId), api.diffRun(runId)])
      setData(r)
      setDiff(d)
    } catch (e: any) {
      setErr(e?.error?.message || 'Failed to load run')
    }
  }

  useEffect(() => {
    if (!Number.isFinite(runId)) return
    loadAll()
  }, [runId])

  const run = data?.run
  const tests: any[] = data?.tests || []
  const attachments: any[] = data?.attachments || []

  const projectId = useMemo(() => (run ? Number(run.projectId) : null), [run])

  async function saveAnnotation(testCaseId: number) {
    const annotation = note[testCaseId] || ''
    if (!annotation) return
    try {
      await api.annotateTestCase(testCaseId, annotation)
      await loadAll()
    } catch (e: any) {
      alert(e?.error?.message || 'Failed to annotate')
    }
  }

  async function onUpload(file: File) {
    setUploading(file.name)
    try {
      const b64 = await readFileAsBase64(file)
      await api.uploadRunAttachment(runId, file.name, file.type || 'application/octet-stream', b64)
      await loadAll()
    } catch (e: any) {
      alert(e?.error?.message || 'Upload failed')
    } finally {
      setUploading(null)
    }
  }

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
        <h3 style={{ margin: 0 }}>Run #{runId}</h3>
        {projectId ? <Link to={`/projects/${projectId}`}>← project</Link> : <Link to="/">← home</Link>}
      </div>

      {err && <div style={{ color: 'crimson', marginTop: 8 }}>{err}</div>}

      {run && (
        <div style={{ marginTop: 12, display: 'flex', gap: 16, flexWrap: 'wrap' }}>
          <Card title="Status">{run.status}</Card>
          <Card title="Branch">{run.branch || '-'}</Card>
          <Card title="Commit"><code>{(run.commitSha || '').slice(0, 10) || '-'}</code></Card>
          <Card title="Passed">{run.passed ?? 0}</Card>
          <Card title="Failed">{run.failed ?? 0}</Card>
          <Card title="Total">{run.total ?? 0}</Card>
        </div>
      )}

      {diff && (
        <div style={{ marginTop: 16, padding: 12, border: '1px solid #ddd', borderRadius: 10 }}>
          <strong>Diff vs previous</strong>
          <div style={{ color: '#666', marginTop: 6 }}>
            Previous run: {diff.previousRunId ? <Link to={`/runs/${diff.previousRunId}`}>#{diff.previousRunId}</Link> : '—'}
          </div>
          <div style={{ display: 'flex', gap: 20, flexWrap: 'wrap', marginTop: 10 }}>
            <div>
              <div style={{ fontWeight: 600 }}>New failed tests</div>
              <ul>{(diff.newFailures || []).map((x: any, i: number) => <li key={i}>{x.name}</li>)}</ul>
            </div>
            <div>
              <div style={{ fontWeight: 600 }}>Fixed failed tests</div>
              <ul>{(diff.fixedFailures || []).map((x: any, i: number) => <li key={i}>{x.name}</li>)}</ul>
            </div>
            <div>
              <div style={{ fontWeight: 600 }}>New error fingerprints</div>
              <ul>{(diff.newErrorFingerprints || []).map((x: any, i: number) => <li key={i}><code>{x.fingerprint}</code></li>)}</ul>
            </div>
          </div>
        </div>
      )}

      <h4 style={{ marginTop: 18 }}>Attach log / artifact</h4>
      <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
        <input
          type="file"
          onChange={(e) => {
            const f = e.target.files?.[0]
            if (f) onUpload(f)
          }}
        />
        {uploading && <span style={{ color: '#666' }}>Uploading {uploading}...</span>}
      </div>

      <h4 style={{ marginTop: 18 }}>Attachments</h4>
      <table style={tableStyle}>
        <thead>
          <tr>
            <th style={thLeft}>File</th>
            <th style={thLeft}>Type</th>
            <th style={thRight}>Size</th>
            <th style={thLeft}>Download</th>
          </tr>
        </thead>
        <tbody>
          {attachments.map((a) => (
            <tr key={a.id}>
              <td style={td}>{a.fileName}</td>
              <td style={td}>{a.mime}</td>
              <td style={tdRight}>{formatBytes(a.sizeBytes || 0)}</td>
              <td style={td}><a href={`/api/attachments/${a.id}/download`} target="_blank" rel="noreferrer">download</a></td>
            </tr>
          ))}
          {attachments.length === 0 && (
            <tr><td colSpan={4} style={{ ...td, color: '#666' }}>No attachments yet.</td></tr>
          )}
        </tbody>
      </table>

      <h4 style={{ marginTop: 18 }}>Tests</h4>
      <table style={tableStyle}>
        <thead>
          <tr>
            <th style={thLeft}>Name</th>
            <th style={thLeft}>Status</th>
            <th style={thRight}>Duration</th>
            <th style={thLeft}>Error</th>
            <th style={thLeft}>Annotation</th>
          </tr>
        </thead>
        <tbody>
          {tests.map((t) => (
            <tr key={t.id}>
              <td style={td}>{t.name}</td>
              <td style={td}>{t.status}</td>
              <td style={tdRight}>{t.durationMs ?? 0}ms</td>
              <td style={td}>{t.fingerprint ? <code title={t.message}>{t.fingerprint}</code> : '—'}</td>
              <td style={td}>
                <div style={{ display: 'flex', gap: 8 }}>
                  <input
                    value={note[t.id] ?? t.annotation ?? ''}
                    onChange={(e) => setNote((p) => ({ ...p, [t.id]: e.target.value }))}
                    placeholder="known-issue / flaky / xfail..."
                    style={{ width: 220 }}
                  />
                  <button onClick={() => saveAnnotation(t.id)} style={btn}>Save</button>
                </div>
              </td>
            </tr>
          ))}
          {tests.length === 0 && (
            <tr><td colSpan={5} style={{ ...td, color: '#666' }}>No tests in this run.</td></tr>
          )}
        </tbody>
      </table>

      <div style={{ marginTop: 18 }}>
        <button onClick={loadAll} style={btn}>Refresh</button>
      </div>
    </div>
  )
}

function readFileAsBase64(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onerror = () => reject(new Error('read failed'))
    reader.onload = () => {
      const res = String(reader.result || '')
      // data:*/*;base64,
      const idx = res.indexOf('base64,')
      resolve(idx >= 0 ? res.slice(idx + 7) : res)
    }
    reader.readAsDataURL(file)
  })
}

function formatBytes(bytes: number) {
  if (!bytes) return '0 B'
  const k = 1024
  const sizes = ['B', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return `${(bytes / Math.pow(k, i)).toFixed(1)} ${sizes[i]}`
}

function Card({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div style={{ border: '1px solid #ddd', borderRadius: 10, padding: 12, minWidth: 160 }}>
      <div style={{ color: '#666', fontSize: 12 }}>{title}</div>
      <div style={{ fontSize: 18, marginTop: 4 }}>{children}</div>
    </div>
  )
}

const tableStyle: React.CSSProperties = { width: '100%', borderCollapse: 'collapse' }
const thLeft: React.CSSProperties = { textAlign: 'left', borderBottom: '1px solid #ddd', padding: 8 }
const thRight: React.CSSProperties = { textAlign: 'right', borderBottom: '1px solid #ddd', padding: 8 }
const td: React.CSSProperties = { padding: 8, borderBottom: '1px solid #f1f1f1', verticalAlign: 'top' }
const tdRight: React.CSSProperties = { ...td, textAlign: 'right' }
const btn: React.CSSProperties = { padding: '6px 10px', border: '1px solid #ccc', borderRadius: 8, background: 'white', cursor: 'pointer' }
