function parseRequest(text) {
  const firstLine = (text.split('\r\n')[0] || '').trim();
  const parts = firstLine.split(' ');
  const rawPath = parts[1] || '/';
  const q = rawPath.indexOf('?');
  const path = q === -1 ? rawPath : rawPath.slice(0, q);
  const query = q === -1 ? '' : rawPath.slice(q + 1);
  return { method: parts[0] || 'GET', path, query, rawPath };
}

function authorized(requestText, token) {
  if (!token) {
    return true;
  }
  return requestText.includes(`X-Lookout-Token: ${token}`)
    || requestText.includes(`token=${token}`);
}

function httpResponse(status, contentType, body, extraHeaders = {}) {
  const reason = status === 200 ? 'OK' : status === 401 ? 'Unauthorized' : 'Not Found';
  const payload = Buffer.isBuffer(body) ? body : Buffer.from(String(body));
  let header = `HTTP/1.1 ${status} ${reason}\r\n`;
  header += `Content-Type: ${contentType}\r\n`;
  header += `Content-Length: ${payload.length}\r\n`;
  for (const [key, value] of Object.entries(extraHeaders)) {
    header += `${key}: ${value}\r\n`;
  }
  header += 'Connection: close\r\n\r\n';
  return Buffer.concat([Buffer.from(header), payload]);
}

module.exports = { parseRequest, authorized, httpResponse };
