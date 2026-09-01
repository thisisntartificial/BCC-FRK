const assert = require('node:assert/strict');
const { parseRequest, authorized, httpResponse } = require('../../apps/Lookout/computer/lib/http');
const { frame } = require('../../apps/Lookout/computer/lib/bmp');

function test(name, fn) {
  try {
    fn();
    console.log(`  ✓ ${name}`);
    return true;
  } catch (err) {
    console.log(`  ✗ ${name}`);
    console.log(`    Error: ${err.message}`);
    return false;
  }
}

const results = [];

results.push(test('parseRequest splits path and query', () => {
  const parsed = parseRequest('GET /snap?token=demo HTTP/1.1');
  assert.equal(parsed.path, '/snap');
  assert.equal(parsed.query, 'token=demo');
}));

results.push(test('authorized accepts header or query token', () => {
  assert.equal(authorized('X-Lookout-Token: secret\n', 'secret'), true);
  assert.equal(authorized('GET /snap?token=secret', 'secret'), true);
  assert.equal(authorized('GET /snap', 'secret'), false);
}));

results.push(test('httpResponse prefixes status and content length', () => {
  const bytes = httpResponse(200, 'text/plain', 'ok');
  const text = bytes.toString('utf8');
  assert.match(text, /HTTP\/1.1 200 OK/);
  assert.match(text, /Content-Length: 2/);
}));

results.push(test('bmp frame is a BM file with changing scanline', () => {
  const a = frame({ tick: 0 });
  const b = frame({ tick: 10 });
  assert.equal(a.toString('ascii', 0, 2), 'BM');
  assert.equal(a.length, b.length);
  assert.equal(a.equals(b), false);
}));

const passed = results.filter(Boolean).length;
const failed = results.length - passed;
console.log(`\nPassed: ${passed}`);
console.log(`Failed: ${failed}`);
process.exit(failed > 0 ? 1 : 0);
