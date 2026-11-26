// Local dev server: serves the Flutter web build and reverse-proxies /v1/* to the
// AI gateway, so the page and the API share one origin (no CORS, no preflight).
import http from 'node:http'
import https from 'node:https'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { spawn, execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const here = path.dirname(fileURLToPath(import.meta.url))
const WEB_ROOT = process.env.WEB_ROOT || path.join(here, '..', 'build', 'web')
const PORT = Number(process.env.PORT || 8090)
const UPSTREAM = new URL(process.env.UPSTREAM || 'https://agent.oasis.mountainxplorer.ai/ai-gateway/openai/v1/')

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.wasm': 'application/wasm',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.map': 'application/json',
  '.bin': 'application/octet-stream',
  '.dat': 'application/octet-stream',
}

function serveStatic(req, res) {
  let rel = decodeURIComponent((req.url || '/').split('?')[0])
  if (rel === '/' || rel === '') rel = '/index.html'
  const file = path.join(WEB_ROOT, rel)
  if (!file.startsWith(WEB_ROOT)) {
    res.writeHead(403).end('forbidden')
    return
  }
  fs.stat(file, (err, st) => {
    if (err || !st.isFile()) {
      // SPA fallback
      const index = path.join(WEB_ROOT, 'index.html')
      fs.readFile(index, (e2, data) => {
        if (e2) return res.writeHead(404).end('not found')
        res.writeHead(200, { 'content-type': MIME['.html'], 'cache-control': 'no-cache' })
        res.end(data)
      })
      return
    }
    res.writeHead(200, {
      'content-type': MIME[path.extname(file).toLowerCase()] || 'application/octet-stream',
      'content-length': st.size,
      'cache-control': 'no-cache, no-store, must-revalidate',
    })
    fs.createReadStream(file).pipe(res)
  })
}

function proxyApi(req, res) {
  const suffix = (req.url || '').replace(/^\/v1\/?/, '')
  const target = new URL(suffix + (req.url.includes('?') ? req.url.slice(req.url.indexOf('?')) : ''), UPSTREAM)

  const headers = { ...req.headers, host: target.host }
  delete headers['accept-encoding'] // keep the upstream stream uncompressed for SSE

  const upstream = https.request(
    { hostname: target.hostname, port: 443, path: target.pathname + target.search, method: req.method, headers },
    (up) => {
      res.writeHead(up.statusCode || 502, up.headers)
      up.pipe(res)
    },
  )
  upstream.on('error', (e) => {
    if (!res.headersSent) res.writeHead(502, { 'content-type': 'application/json' })
    res.end(JSON.stringify({ error: { message: 'proxy error: ' + e.message } }))
  })
  req.pipe(upstream)
}

// Browsers cannot fetch arbitrary sites (CORS), so the model's fetch_url tool
// goes through this endpoint instead. Returns plain text, already stripped.
function fetchPage(req, res) {
  const u = new URL(req.url || '/', 'http://127.0.0.1')
  const target = u.searchParams.get('url') || ''
  if (!/^https?:\/\//i.test(target)) {
    res.writeHead(400, { 'content-type': 'application/json' })
    return res.end(JSON.stringify({ error: 'url must be http(s)' }))
  }
  const HTML_LIMIT = 8000
  const JSON_LIMIT = 512000
  const client = target.startsWith('https') ? https : http
  const request = client.get(
    target,
    // Let Node choose the address family (autoSelectFamily does happy-eyeballs).
    // Pinning family:4 broke hosts whose IPv4 path is blackholed while IPv6
    // works: www.v2ex.com/api hung for the full 20s that way, then answered in
    // ~270ms once the pin was removed.
    { headers: { 'user-agent': 'Mozilla/5.0 (compatible; feiyu/1.0)', accept: 'text/html,text/plain,*/*' }, timeout: 20000 },
    (up) => {
      if (up.statusCode && up.statusCode >= 300 && up.statusCode < 400 && up.headers.location) {
        up.resume()
        res.writeHead(302, { location: up.headers.location })
        return res.end()
      }
      // JSON feeds (HN / V2EX / GitHub) must pass through byte-for-byte: the
      // tag-strip pipeline turns them into invalid JSON. HTML/text keeps the
      // old strip + 8k path.
      const isJson = String(up.headers['content-type'] || '').toLowerCase().includes('json')
      const limit = isJson ? JSON_LIMIT : HTML_LIMIT
      const chunks = []
      let size = 0
      up.on('data', (c) => {
        if (size < limit) {
          chunks.push(c)
          size += c.length
        }
      })
      up.on('end', () => {
        const raw = Buffer.concat(chunks).toString('utf8')
        if (isJson) {
          res.writeHead(200, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' })
          res.end(raw.slice(0, JSON_LIMIT))
          return
        }
        const text = raw
          .replace(/<script[\s\S]*?<\/script>/gi, ' ')
          .replace(/<style[\s\S]*?<\/style>/gi, ' ')
          .replace(/<head[\s\S]*?<\/head>/gi, ' ')
          .replace(/<[^>]+>/g, ' ')
          .replace(/&nbsp;/g, ' ')
          .replace(/&lt;/g, '<')
          .replace(/&gt;/g, '>')
          .replace(/&amp;/g, '&')
          .replace(/\s+/g, ' ')
          .trim()
          .slice(0, HTML_LIMIT)
        res.writeHead(200, { 'content-type': 'text/plain; charset=utf-8', 'cache-control': 'no-store' })
        res.end(text)
      })
    },
  )
  request.on('timeout', () => request.destroy(new Error('timeout')))
  request.on('error', (e) => {
    if (!res.headersSent) res.writeHead(502, { 'content-type': 'text/plain; charset=utf-8' })
    res.end('fetch error: ' + e.message)
  })
}

// ComfyUI lives on another port (e.g. 8188), so browsers block direct calls.
// This forwards /comfy/* to it, keeping the page same-origin.
const COMFY = process.env.FEIYU_COMFY || 'http://127.0.0.1:8188'

function proxyComfy(req, res) {
  const suffix = (req.url || '').replace(/^\/comfy/, '') || '/'
  let target
  try {
    target = new URL(suffix, COMFY)
  } catch (e) {
    res.writeHead(400).end('bad comfy url')
    return
  }
  const lib = target.protocol === 'https:' ? https : http
  const headers = { ...req.headers, host: target.host }
  delete headers['accept-encoding']
  // ComfyUI rejects cross-origin POSTs (403) when an Origin header is present,
  // so the proxy must look like a plain local client.
  delete headers['origin']
  delete headers['referer']
  delete headers['sec-fetch-site']
  delete headers['sec-fetch-mode']

  const upstream = lib.request(
    { hostname: target.hostname, port: target.port || 80, path: target.pathname + target.search, method: req.method, headers },
    (up) => {
      res.writeHead(up.statusCode || 502, up.headers)
      up.pipe(res)
    },
  )
  upstream.on('error', (e) => {
    if (!res.headersSent) res.writeHead(502, { 'content-type': 'text/plain; charset=utf-8' })
    res.end('comfy proxy error: ' + e.message)
  })
  req.pipe(upstream)
}

// ---------------------------------------------------------------------------
// ComfyUI lifecycle. The page (and the phone) can start/stop the engine on the
// desktop instead of walking over to run a .bat by hand. This only works when
// this server runs on the same machine as ComfyUI; override the defaults with
// COMFY_DIR / COMFY_START / COMFY_STOP when the install lives elsewhere.
const COMFY_PORT = Number(new URL(COMFY).port || 8188)
const COMFY_DIR = process.env.COMFY_DIR || path.join(os.homedir(), 'WorkSpace', 'sexy')
const COMFY_START = process.env.COMFY_START || path.join(COMFY_DIR, 'run_comfy_hidden.cmd')
const COMFY_STOP_FLAG = path.join(COMFY_DIR, 'stop.flag')

function comfyPing(timeout = 1500) {
  return new Promise((resolve) => {
    const req = http.get(
      { host: '127.0.0.1', port: COMFY_PORT, path: '/system_stats', timeout },
      (res) => {
        res.resume()
        resolve(res.statusCode === 200)
      },
    )
    req.on('timeout', () => {
      req.destroy()
      resolve(false)
    })
    req.on('error', () => resolve(false))
  })
}

function comfyListenerPids() {
  try {
    const out = execFileSync('netstat', ['-ano'], { encoding: 'utf8', windowsHide: true })
    const pids = new Set()
    for (const line of out.split(/\r?\n/)) {
      if (!new RegExp(`:${COMFY_PORT}(?!\\d)`).test(line)) continue
      if (!/LISTENING/i.test(line)) continue
      const parts = line.trim().split(/\s+/)
      const pid = parts[parts.length - 1]
      if (/^\d+$/.test(pid)) pids.add(pid)
    }
    return [...pids]
  } catch {
    return []
  }
}

async function comfyCtl(req, res, action) {
  const send = (code, body) => {
    res.writeHead(code, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' })
    res.end(JSON.stringify(body))
  }
  const running = await comfyPing()
  if (action === 'health') {
    return send(200, {
      running,
      port: COMFY_PORT,
      dir: COMFY_DIR,
      startable: fs.existsSync(COMFY_START),
    })
  }
  if (action === 'start') {
    if (running) return send(200, { running: true, started: false })
    if (!fs.existsSync(COMFY_START)) {
      return send(501, { running: false, started: false, error: `找不到启动脚本：${COMFY_START}` })
    }
    try {
      fs.rmSync(COMFY_STOP_FLAG, { force: true })
    } catch {}
    // Detached so the supervisor outlives this request and keeps ComfyUI alive.
    const child = spawn('cmd.exe', ['/c', COMFY_START], {
      cwd: COMFY_DIR,
      detached: true,
      stdio: 'ignore',
      windowsHide: true,
    })
    child.unref()
    return send(202, { running: false, started: true })
  }
  if (action === 'stop') {
    try {
      fs.writeFileSync(COMFY_STOP_FLAG, 'stop')
    } catch {}
    const pids = comfyListenerPids()
    for (const pid of pids) {
      try {
        execFileSync('taskkill', ['/PID', pid, '/T', '/F'], { stdio: 'ignore', windowsHide: true })
      } catch {}
    }
    // Same handshake as 停止大肥鱼.cmd: the flag tells the supervisor not to
    // relaunch, and it is cleared once the child has had time to exit.
    setTimeout(() => {
      try {
        fs.rmSync(COMFY_STOP_FLAG, { force: true })
      } catch {}
    }, 5000)
    return send(200, { running: false, stopped: pids.length > 0 })
  }
  return send(404, { error: 'unknown comfy action' })
}

function handleComfyCtl(req, res) {
  const action = (req.url || '').replace(/^\/comfyctl\/?/, '').split('?')[0]
  if (req.method === 'GET' && action === 'health') return comfyCtl(req, res, action)
  if (req.method === 'POST' && (action === 'start' || action === 'stop')) {
    return comfyCtl(req, res, action)
  }
  res.writeHead(404, { 'content-type': 'text/plain; charset=utf-8' }).end('unknown comfyctl action')
}

const server = http.createServer((req, res) => {
  if ((req.url || '').startsWith('/v1/') || req.url === '/v1') return proxyApi(req, res)
  if ((req.url || '').startsWith('/comfyctl')) return handleComfyCtl(req, res)
  if ((req.url || '').startsWith('/comfy')) return proxyComfy(req, res)
  if ((req.url || '').startsWith('/fetch')) return fetchPage(req, res)
  if (req.url === '/healthz') return res.writeHead(200).end('ok')
  return serveStatic(req, res)
})

server.listen(PORT, '127.0.0.1', () => {
  console.log(`feiyu web on http://127.0.0.1:${PORT}  (static: ${WEB_ROOT})`)
  console.log(`/v1/* -> ${UPSTREAM}`)
})
