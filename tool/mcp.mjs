#!/usr/bin/env node
import { spawn } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const manifest = JSON.parse(readFileSync(path.join(projectRoot, '.pb-scaffold.json'), 'utf8'));
const pbRoot = path.resolve(projectRoot, manifest.protoBridgeRoot);
const workspaceConfig = path.resolve(pbRoot, manifest.workspaceConfig);
const child = spawn(process.execPath, [
  path.join(pbRoot, 'scripts/pb-mcp.mjs'),
  '--config', workspaceConfig,
  '--target', projectRoot,
], { cwd: projectRoot, stdio: 'inherit', env: process.env });
child.once('error', (error) => { throw error; });
child.once('exit', (code, signal) => { if (signal) process.kill(process.pid, signal); else process.exitCode = code ?? 1; });
