#!/usr/bin/env node
/**
 * Lookout on a computer: demo camera + browser viewer.
 * Watch this machine, or paste a phone's address block.
 *
 *   node apps/Lookout/computer/server.js
 *   LOOKOUT_PORT=8788 node apps/Lookout/computer/server.js
 */
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const { frame } = require('./lib/bmp');
const { parseRequest, authorized, httpResponse } = require('./lib/http');

const PORT = Number(process.env.LOOKOUT_PORT || 8788);
const TOKEN = process.env.LOOKOUT_TOKEN || 'demo';
const ROOM = process.env.LOOKOUT_ROOM || 'Computer';
const publicDir = path.join(__dirname, 'public');

function send(response, status, contentType, body) {
  const payload = Buffer.isBuffer(body) ? body : Buffer.from(String(body));
  response.writeHead(status, {
    'Content-Type': contentType,
    'Content-Length': payload.length,
    'Cache-Control': 'no-store'
  });
  response.end(payload);
}

function serveStatic(urlPath, response) {
  const name = urlPath === '/' ? 'index.html' : path.basename(urlPath);
  const file = path.join(publicDir, name);
  if (file.startsWith(publicDir) === false || fs.existsSync(file) === false) {
    send(response, 404, 'text/plain', 'not found');
    return;
  }
  const type = name.endsWith('.html') ? 'text/html; charset=utf-8' : 'application/octet-stream';
  send(response, 200, type, fs.readFileSync(file));
}

const server = http.createServer((request, response) => {
  const parsed = parseRequest(`${request.method} ${request.url} HTTP/1.1`);
  const headerToken = request.headers['x-lookout-token'];
  const raw = `X-Lookout-Token: ${headerToken || ''}\ntoken=${parsed.query}`;

  if (parsed.path === '/health') {
    send(response, 200, 'application/json', JSON.stringify({ room: ROOM, live: true, computer: true }));
    return;
  }

  if (parsed.path === '/snap') {
    if (!authorized(raw, TOKEN)) {
      send(response, 401, 'text/plain', 'token required');
      return;
    }
    const tick = Math.floor(Date.now() / 80);
    send(response, 200, 'image/bmp', frame({ room: ROOM, tick }));
    return;
  }

  serveStatic(parsed.path, response);
});

if (require.main === module) {
  server.listen(PORT, '0.0.0.0', () => {
    const block = [
      `LOOKOUT · ${ROOM.toUpperCase()}`,
      `http://127.0.0.1:${PORT}`,
      'computer · live'
    ].join('\n');
    console.log(block);
    console.log(`Token: ${TOKEN}`);
    console.log('Open that URL in a browser. Paste a phone address to watch a real node.');
  });
}

module.exports = { server, parseRequest, authorized, httpResponse };
