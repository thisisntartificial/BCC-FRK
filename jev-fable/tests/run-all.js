#!/usr/bin/env node
'use strict';

/**
 * Runs every tests/**\/*.test.js file with the built-in node:test runner.
 * Exits 0 when there are no test files yet, so a fresh checkout is green.
 */

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

function findTests(dir, acc = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) findTests(full, acc);
    else if (entry.isFile() && entry.name.endsWith('.test.js')) acc.push(full);
  }
  return acc;
}

const files = findTests(__dirname).sort();
if (files.length === 0) {
  console.log('No test files found.');
  process.exit(0);
}

const result = spawnSync(process.execPath, ['--test', ...files], { stdio: 'inherit' });
process.exit(result.status === null ? 1 : result.status);
