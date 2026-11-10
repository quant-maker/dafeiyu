// Local dev server: serves the Flutter web build and reverse-proxies /v1/* to the
// AI gateway, so the page and the API share one origin (no CORS, no preflight).
import http from 'node:http'
import https from 'node:https'
import fs from 'node:fs'
import path from 'node:path'
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

const server = http.createServer((req, res) => {
  if ((req.url || '').startsWith('/v1/') || req.url === '/v1') return proxyApi(req, res)
  if (req.url === '/healthz') return res.writeHead(200).end('ok')
  return serveStatic(req, res)
})

server.listen(PORT, '127.0.0.1', () => {
  console.log(`feiyu web on http://127.0.0.1:${PORT}  (static: ${WEB_ROOT})`)
  console.log(`/v1/* -> ${UPSTREAM}`)
})
