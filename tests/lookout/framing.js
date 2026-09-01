const FrameType = {
  video: 1,
  control: 2,
  heartbeat: 3
};

const MAX_FRAME_BYTES = 1_048_576;

function encodeFrame(type, ptsMs, payload) {
  const bodyLength = 1 + 8 + payload.length;
  const bytes = Buffer.alloc(4 + bodyLength);
  bytes.writeUInt32BE(bodyLength, 0);
  bytes[4] = type;
  bytes.writeBigUInt64BE(BigInt(ptsMs), 5);
  Buffer.from(payload).copy(bytes, 13);
  return bytes;
}

function decodeFrame(bytes) {
  if (!bytes || bytes.length < 13) {
    return null;
  }
  const length = bytes.readUInt32BE(0);
  if (bytes.length !== length + 4) {
    return null;
  }
  const type = bytes[4];
  if (!Object.values(FrameType).includes(type)) {
    return null;
  }
  return {
    type,
    ptsMs: bytes.readBigUInt64BE(5),
    payload: Buffer.from(bytes.subarray(13))
  };
}

function pushChunks(reader, chunk) {
  reader.buffer = Buffer.concat([reader.buffer, Buffer.from(chunk)]);
  const messages = [];
  while (reader.buffer.length >= 4) {
    const length = reader.buffer.readUInt32BE(0);
    if (length <= 0 || length > MAX_FRAME_BYTES) {
      throw new Error('invalidFrame');
    }
    const total = length + 4;
    if (reader.buffer.length < total) {
      break;
    }
    const slice = reader.buffer.subarray(0, total);
    reader.buffer = reader.buffer.subarray(total);
    const message = decodeFrame(slice);
    if (!message) {
      throw new Error('invalidFrame');
    }
    messages.push(message);
  }
  return messages;
}

function generatePin() {
  const value = cryptoRandomInt(0, 1_000_000);
  return String(value).padStart(6, '0');
}

function isValidPin(pin) {
  return typeof pin === 'string' && /^[0-9]{6}$/.test(pin);
}

function controlHello({ pin, token }) {
  return Buffer.from(JSON.stringify({ pin, token }), 'utf8');
}

function parseControlHello(payload) {
  const body = JSON.parse(Buffer.from(payload).toString('utf8'));
  if (!isValidPin(body.pin) || typeof body.token !== 'string') {
    return null;
  }
  return { pin: body.pin, token: body.token };
}

function cryptoRandomInt(min, max) {
  const { randomInt } = require('node:crypto');
  return randomInt(min, max);
}

module.exports = {
  FrameType,
  encodeFrame,
  decodeFrame,
  pushChunks,
  generatePin,
  isValidPin,
  controlHello,
  parseControlHello
};
