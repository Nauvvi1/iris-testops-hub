/*
  Minimal all-in-one server for iris-testops-hub.
  Goals:
  - Always returns 200 for core app routes (no 401/403/404 surprises for demo)
  - Provides a REST-ish API under /api/* that mimics the UI needs
  - Serves built Vite static files from /app/dist with SPA fallback
  - Logs EVERYTHING with request id, timing, body parse errors, etc.

  No external dependencies by design (works even if npm registry / apt are flaky).
*/

const http = require('http');
const fs = require('fs');
const path = require('path');
const { randomUUID } = require('crypto');
const { URL } = require('url');

const PORT = Number(process.env.PORT || 80);
const DIST_DIR = process.env.DIST_DIR || path.join(__dirname, '..', 'dist');
const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, '..', 'data');
const ATTACH_DIR = path.join(DATA_DIR, 'attachments');

fs.mkdirSync(ATTACH_DIR, { recursive: true });

// --- In-memory DB (good enough for demo) ---
const db = {
  users: [
    { id: 1, email: 'admin@testops.local', role: 'admin', name: 'Admin', password: 'admin123' },
  ],
  tokens: new Map(), // token -> userId
  projects: [
    { id: 1, name: 'Demo Project', createdAt: new Date().toISOString() },
  ],
  runs: [],
  testcases: [],
  events: [],
  attachments: [],
};

function nowIso() {
  return new Date().toISOString().replace('T', ' ').replace('Z', '');
}

function log(reqId, level, msg, extra) {
  const base = `[web-api][${level}][${nowIso()}][${reqId}] ${msg}`;
  if (extra !== undefined) {
    try {
      console.log(base, typeof extra === 'string' ? extra : JSON.stringify(extra));
    } catch {
      console.log(base, extra);
    }
  } else {
    console.log(base);
  }
}

function sendJson(res, statusCode, payload, reqId) {
  const body = JSON.stringify(payload ?? {});
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-cache, no-store',
    'Pragma': 'no-cache',
    'X-Request-Id': reqId,
  });
  res.end(body);
}

function sendText(res, statusCode, text, reqId) {
  res.writeHead(statusCode, {
    'Content-Type': 'text/plain; charset=utf-8',
    'Cache-Control': 'no-cache, no-store',
    'Pragma': 'no-cache',
    'X-Request-Id': reqId,
  });
  res.end(text);
}

function safeReadBody(req, limitBytes = 2 * 1024 * 1024) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];

    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > limitBytes) {
        reject(new Error(`body_too_large>${limitBytes}`));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

async function readJson(req, reqId) {
  const raw = await safeReadBody(req);
  const text = raw.toString('utf8');
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch (e) {
    log(reqId, 'ERROR', 'JSON parse failed', { error: String(e), textPreview: text.slice(0, 400) });
    return { __parseError: true, __raw: text };
  }
}

function getAuth(req) {
  const h = req.headers['authorization'] || '';
  const m = /^Bearer\s+(.+)$/i.exec(h);
  return m ? m[1].trim() : '';
}

function authUser(req, reqId) {
  // Demo rule: NO hard auth. If token exists and valid -> user; else -> admin fallback.
  const token = getAuth(req);
  const userId = token && db.tokens.get(token);
  const user = userId ? db.users.find((u) => u.id === userId) : db.users[0];
  log(reqId, 'DEBUG', 'authUser resolved', { tokenPresent: Boolean(token), tokenValid: Boolean(userId), user: { id: user.id, email: user.email, role: user.role } });
  return user;
}

// --- API Handlers ---
async function handleApi(req, res, url, reqId) {
  const method = req.method || 'GET';
  const pathname = url.pathname;

  // Health
  if (method === 'GET' && pathname === '/api/health') {
    return sendJson(res, 200, { ok: true, status: 'healthy', ts: Date.now() }, reqId);
  }

  // Auth (demo)
  if (method === 'POST' && pathname === '/api/auth/login') {
    const body = await readJson(req, reqId);
    if (body && body.__parseError) {
      return sendJson(res, 200, { ok: true, token: 'dev-token', user: { id: 1, email: 'admin@testops.local', role: 'admin' }, warning: 'invalid_json_body_ignored' }, reqId);
    }
    const email = (body?.email || '').trim() || 'admin@testops.local';
    const password = String(body?.password || '');
    const found = db.users.find((u) => u.email.toLowerCase() === email.toLowerCase());
    const passOk = !found ? false : (password ? found.password === password : true);

    // For demo: if user not found -> create; if password mismatch -> still allow (but log).
    let user = found;
    if (!user) {
      user = { id: db.users.length + 1, email, role: 'user', name: email.split('@')[0], password: password || 'dev' };
      db.users.push(user);
      log(reqId, 'INFO', 'created new user (demo)', { id: user.id, email: user.email });
    } else if (!passOk) {
      log(reqId, 'WARN', 'password mismatch (demo) - allowing anyway', { email });
    }

    const token = `tok_${randomUUID()}`;
    db.tokens.set(token, user.id);
    return sendJson(res, 200, { ok: true, token, user: { id: user.id, email: user.email, role: user.role, name: user.name } }, reqId);
  }

  if (method === 'POST' && pathname === '/api/auth/logout') {
    const token = getAuth(req);
    if (token) db.tokens.delete(token);
    return sendJson(res, 200, { ok: true }, reqId);
  }

  // Projects
  if (pathname === '/api/projects') {
    const user = authUser(req, reqId);
    if (method === 'GET') {
      return sendJson(res, 200, { ok: true, user: { id: user.id, email: user.email }, items: db.projects }, reqId);
    }
    if (method === 'POST') {
      const body = await readJson(req, reqId);
      const name = (body?.name || '').trim() || `Project #${db.projects.length + 1}`;
      const p = { id: db.projects.length ? Math.max(...db.projects.map((x) => x.id)) + 1 : 1, name, createdAt: new Date().toISOString() };
      db.projects.push(p);
      log(reqId, 'INFO', 'project created', p);
      return sendJson(res, 200, { ok: true, item: p }, reqId);
    }
  }

  // Attachments (simple base64)
  if (method === 'POST' && pathname === '/api/attachments') {
    const body = await readJson(req, reqId);
    const b64 = body?.base64 || '';
    const filename = (body?.filename || '').replace(/[^a-zA-Z0-9._-]/g, '_') || `file_${Date.now()}.bin`;
    if (!b64) {
      log(reqId, 'WARN', 'attachment upload without base64', body);
      return sendJson(res, 200, { ok: true, warning: 'empty_base64', url: null }, reqId);
    }
    const buf = Buffer.from(String(b64), 'base64');
    const id = db.attachments.length ? Math.max(...db.attachments.map((x) => x.id)) + 1 : 1;
    const storedName = `${id}_${filename}`;
    const full = path.join(ATTACH_DIR, storedName);
    fs.writeFileSync(full, buf);
    const item = { id, filename, size: buf.length, path: full, createdAt: new Date().toISOString() };
    db.attachments.push(item);
    log(reqId, 'INFO', 'attachment stored', { id, filename, size: buf.length });
    return sendJson(res, 200, { ok: true, item, url: `/api/attachments/${id}` }, reqId);
  }

  if (method === 'GET' && pathname.startsWith('/api/attachments/')) {
    const id = Number(pathname.split('/').pop());
    const item = db.attachments.find((x) => x.id === id);
    if (!item || !fs.existsSync(item.path)) {
      // Important: for demo we avoid 404 surprises -> return 200 with message
      return sendJson(res, 200, { ok: false, error: 'not_found', id }, reqId);
    }
    const ext = path.extname(item.filename).toLowerCase();
    const mime = ext === '.png' ? 'image/png' : ext === '.jpg' || ext === '.jpeg' ? 'image/jpeg' : ext === '.gif' ? 'image/gif' : 'application/octet-stream';
    res.writeHead(200, {
      'Content-Type': mime,
      'Cache-Control': 'no-cache, no-store',
      'Pragma': 'no-cache',
      'X-Request-Id': reqId,
    });
    fs.createReadStream(item.path).pipe(res);
    return;
  }

  // Fallback: API route unknown -> 200 with info (no 404)
  log(reqId, 'WARN', 'unknown API route (demo fallback to 200)', { method, pathname });
  return sendJson(res, 200, { ok: false, error: 'unknown_route', method, path: pathname }, reqId);
}

// --- Static / SPA ---
function tryStatic(res, pathname, reqId) {
  // Prevent path traversal
  const safePath = pathname.replace(/\0/g, '').replace(/\.\.(\/|\\)/g, '');
  const filePath = path.join(DIST_DIR, safePath);

  const exists = fs.existsSync(filePath) && fs.statSync(filePath).isFile();
  if (!exists) return false;

  const ext = path.extname(filePath).toLowerCase();
  const mime =
    ext === '.html' ? 'text/html; charset=utf-8'
      : ext === '.js' ? 'application/javascript; charset=utf-8'
      : ext === '.css' ? 'text/css; charset=utf-8'
      : ext === '.svg' ? 'image/svg+xml'
      : ext === '.png' ? 'image/png'
      : ext === '.ico' ? 'image/x-icon'
      : 'application/octet-stream';

  res.writeHead(200, {
    'Content-Type': mime,
    'Cache-Control': ext === '.html' ? 'no-cache' : 'public, max-age=31536000, immutable',
    'X-Request-Id': reqId,
  });
  fs.createReadStream(filePath).pipe(res);
  return true;
}

function serveIndex(res, reqId) {
  const indexPath = path.join(DIST_DIR, 'index.html');
  if (!fs.existsSync(indexPath)) {
    return sendText(res, 200, 'Frontend is not built yet (missing dist/index.html).', reqId);
  }
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-cache', 'X-Request-Id': reqId });
  fs.createReadStream(indexPath).pipe(res);
}

const server = http.createServer(async (req, res) => {
  const reqId = randomUUID();
  const start = Date.now();
  const method = req.method || 'GET';
  const rawUrl = req.url || '/';
  const host = req.headers.host || 'localhost';
  const url = new URL(rawUrl, `http://${host}`);
  const pathname = url.pathname;

  log(reqId, 'INFO', `${method} ${pathname}`, {
    query: Object.fromEntries(url.searchParams.entries()),
    ua: (req.headers['user-agent'] || '').slice(0, 120),
    referer: (req.headers['referer'] || '').slice(0, 200),
  });

  try {
    if (pathname.startsWith('/api/')) {
      await handleApi(req, res, url, reqId);
    } else {
      // static assets
      if (pathname !== '/' && tryStatic(res, pathname, reqId)) {
        // served
      } else {
        // SPA fallback
        serveIndex(res, reqId);
      }
    }
  } catch (e) {
    log(reqId, 'ERROR', 'unhandled error', { error: String(e), stack: String(e?.stack || '').split('\n').slice(0, 8).join('\n') });
    // demo rule: avoid 5xx/4xx -> return 200 with error payload
    if (!res.headersSent) {
      sendJson(res, 200, { ok: false, error: 'internal_error', message: String(e) }, reqId);
    } else {
      try { res.end(); } catch {}
    }
  } finally {
    const ms = Date.now() - start;
    log(reqId, 'INFO', `done in ${ms}ms`);
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[web-api][INFO][${nowIso()}] listening on :${PORT}`);
  console.log(`[web-api][INFO][${nowIso()}] dist dir: ${DIST_DIR}`);
  console.log(`[web-api][INFO][${nowIso()}] data dir: ${DATA_DIR}`);
});
