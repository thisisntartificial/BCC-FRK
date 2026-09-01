/** Minimal 24-bit BMP so a computer can emit a moving "live" frame with no native deps. */
function writeUInt32LE(buffer, offset, value) {
  buffer.writeUInt32LE(value >>> 0, offset);
}

function writeInt32LE(buffer, offset, value) {
  buffer.writeInt32LE(value, offset);
}

function frame({ width = 320, height = 180, room = 'KITCHEN', tick = 0 } = {}) {
  const rowSize = Math.ceil((width * 3) / 4) * 4;
  const pixelBytes = rowSize * height;
  const file = Buffer.alloc(54 + pixelBytes);
  file.write('BM', 0);
  writeUInt32LE(file, 2, file.length);
  writeUInt32LE(file, 10, 54);
  writeUInt32LE(file, 14, 40);
  writeInt32LE(file, 18, width);
  writeInt32LE(file, 22, height);
  file.writeUInt16LE(1, 26);
  file.writeUInt16LE(24, 28);
  writeUInt32LE(file, 34, pixelBytes);

  const band = tick % height;
  for (let y = 0; y < height; y++) {
    const dest = 54 + y * rowSize;
    for (let x = 0; x < width; x++) {
      const i = dest + x * 3;
      const live = y === band || y === band + 1;
      file[i] = live ? 40 : 18;
      file[i + 1] = live ? 220 : 18;
      file[i + 2] = live ? 80 : (room.length * 12 + x) % 40;
    }
  }
  return file;
}

module.exports = { frame };
