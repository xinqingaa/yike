#!/usr/bin/env node
import { spawn } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const manifest = JSON.parse(readFileSync(path.join(projectRoot, '.pb-scaffold.json'), 'utf8'));
const pbRoot = path.resolve(projectRoot, manifest.protoBridgeRoot);

function run(command, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { cwd: projectRoot, stdio: 'inherit', env: process.env });
    child.once('error', reject);
    child.once('exit', (code) => code === 0 ? resolve() : reject(new Error(`${command} ${args.join(' ')} exited ${code}`)));
  });
}

await run('flutter', ['pub', 'get']);
await run('dart', ['format', '--output=none', '--set-exit-if-changed', 'lib', 'test']);
await run('flutter', ['analyze']);
await run('flutter', ['test']);
await run(process.execPath, [path.join(pbRoot, 'scripts/verify-ds-target-sync.mjs'), '--target', projectRoot]);
