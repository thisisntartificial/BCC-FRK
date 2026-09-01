const assert = require('node:assert/strict');
const {
  FrameType,
  encodeFrame,
  decodeFrame,
  pushChunks,
  generatePin,
  controlHello,
  parseControlHello,
  isValidPin
} = require('./framing');

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

results.push(test('encode/decode round-trips a control hello', () => {
  const payload = controlHello({ pin: '482193', token: 'ab'.repeat(16) });
  const bytes = encodeFrame(FrameType.control, 0n, payload);
  const message = decodeFrame(bytes);
  assert.equal(message.type, FrameType.control);
  assert.equal(message.ptsMs, 0n);
  assert.deepEqual(parseControlHello(message.payload), {
    pin: '482193',
    token: 'ab'.repeat(16)
  });
}));

results.push(test('encode prefixes big-endian length of type+pts+payload', () => {
  const payload = Buffer.from('hi');
  const bytes = encodeFrame(FrameType.heartbeat, 1000n, payload);
  const length = bytes.readUInt32BE(0);
  assert.equal(length, 1 + 8 + 2);
  assert.equal(bytes.length, 4 + length);
  assert.equal(bytes[4], FrameType.heartbeat);
}));

results.push(test('decode rejects truncated frames', () => {
  assert.equal(decodeFrame(Buffer.from([0, 0, 0, 3, 1])), null);
}));

results.push(test('decode rejects unknown type', () => {
  const bytes = encodeFrame(FrameType.video, 1n, Buffer.from([1, 2, 3]));
  bytes[4] = 99;
  assert.equal(decodeFrame(bytes), null);
}));

results.push(test('FrameReader reassembles split TCP chunks', () => {
  const first = encodeFrame(FrameType.heartbeat, 1n, Buffer.from('a'));
  const second = encodeFrame(FrameType.heartbeat, 2n, Buffer.from('b'));
  const stream = Buffer.concat([first, second]);
  const reader = { buffer: Buffer.alloc(0) };
  const mid = Math.floor(stream.length / 2);
  const part1 = pushChunks(reader, stream.subarray(0, mid));
  const part2 = pushChunks(reader, stream.subarray(mid));
  const messages = [...part1, ...part2];
  assert.equal(messages.length, 2);
  assert.equal(messages[0].payload.toString(), 'a');
  assert.equal(messages[1].payload.toString(), 'b');
}));

results.push(test('FrameReader rejects oversized frames', () => {
  const reader = { buffer: Buffer.alloc(0) };
  const header = Buffer.alloc(4);
  header.writeUInt32BE(2_000_000, 0);
  assert.throws(() => pushChunks(reader, header), /invalidFrame/);
}));

results.push(test('generatePin is six digits', () => {
  const pin = generatePin();
  assert.equal(pin.length, 6);
  assert.equal(isValidPin(pin), true);
}));

results.push(test('isValidPin rejects short or non-numeric values', () => {
  assert.equal(isValidPin('12345'), false);
  assert.equal(isValidPin('12345a'), false);
  assert.equal(isValidPin(''), false);
}));

const passed = results.filter(Boolean).length;
const failed = results.length - passed;
console.log(`\nPassed: ${passed}`);
console.log(`Failed: ${failed}`);
process.exit(failed > 0 ? 1 : 0);
