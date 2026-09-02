/** Night-watch demo frame. 24-bit BMP, no native deps. */

function writeUInt32LE(buffer, offset, value) {
  buffer.writeUInt32LE(value >>> 0, offset);
}

function writeInt32LE(buffer, offset, value) {
  buffer.writeInt32LE(value, offset);
}

function mix(a, b, t) {
  return Math.round(a + (b - a) * t);
}

function put(file, width, rowSize, height, x, yTop, b, g, r) {
  if (x < 0 || yTop < 0 || x >= width || yTop >= height) {
    return;
  }
  const y = height - 1 - yTop;
  const dest = 54 + y * rowSize + x * 3;
  file[dest] = b;
  file[dest + 1] = g;
  file[dest + 2] = r;
}

function frame({ width = 640, height = 360, tick = 0 } = {}) {
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

  const doorX = Math.floor(width * 0.62);
  const winX = Math.floor(width * 0.16);
  const scan = tick % height;
  const pulse = 0.55 + 0.45 * Math.sin(tick / 8);

  for (let y = 0; y < height; y++) {
    const yn = y / height;
    for (let x = 0; x < width; x++) {
      const xn = x / width;
      const vignette = 1 - 0.5 * ((xn - 0.5) ** 2 + (yn - 0.45) ** 2) * 3.4;
      let r = mix(16, 36, yn);
      let g = mix(13, 26, yn);
      let b = mix(9, 18, yn);

      if (x > winX && x < winX + 86 && y > 78 && y < 188) {
        const col = Math.floor((x - winX) / 43);
        const row = Math.floor((y - 78) / 55);
        const localX = (x - winX) % 43;
        const localY = (y - 78) % 55;
        if (localX > 2 && localX < 40 && localY > 2 && localY < 52 && col < 2 && row < 2) {
          r = mix(48, 216, pulse * 0.4 + 0.25);
          g = mix(32, 148, pulse * 0.28);
          b = mix(14, 52, 0.22);
        }
      }

      if (x > doorX && x < doorX + 58 && y > 118 && y < 292) {
        r = mix(10, 22, yn);
        g = mix(9, 17, yn);
        b = mix(7, 13, yn);
        if (x > doorX + 48 && x < doorX + 52 && y > 196 && y < 208) {
          r = 176;
          g = 138;
          b = 68;
        }
      }

      if (y < 42 || y > height - 36) {
        r = mix(r, 6, 0.55);
        g = mix(g, 6, 0.55);
        b = mix(b, 5, 0.55);
      }

      const grain = ((x * 47 + y * 19 + tick * 13) % 17) - 8;
      r = Math.max(0, Math.min(255, Math.round(r * vignette + grain)));
      g = Math.max(0, Math.min(255, Math.round(g * vignette + grain * 0.55)));
      b = Math.max(0, Math.min(255, Math.round(b * vignette + grain * 0.35)));

      if (y === scan || y === (scan + 1) % height) {
        r = Math.min(255, r + 42);
        g = Math.min(255, g + 30);
        b = Math.min(255, b + 10);
      }

      put(file, width, rowSize, height, x, y, b, g, r);
    }
  }

  // HUD text (room, state, clock) is drawn by the viewer, not baked into pixels.
  return file;
}

module.exports = { frame };
