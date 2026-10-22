#!/usr/bin/env node
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const targetRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const manifest = JSON.parse(readFileSync(path.join(targetRoot, '.pb-scaffold.json'), 'utf8'));
const producer = path.resolve(targetRoot, manifest.protoBridgeRoot);
const config = path.resolve(producer, manifest.workspaceConfig);
if (process.argv.includes('--bind')) {
  const result = spawnSync(process.execPath, [path.join(producer, 'scripts/pb-target.mjs'), 'use', targetRoot, '--yes', '--config', config], { cwd: producer, stdio: 'inherit' });
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
} else {
  const workspace = JSON.parse(readFileSync(config, 'utf8'));
  const deliveryTarget = workspace.delivery?.targetRoot ? path.resolve(path.dirname(config), workspace.delivery.targetRoot) : null;
  const matches = deliveryTarget === targetRoot;
  process.stdout.write(JSON.stringify({ workspaceId: workspace.workspaceId, targetRoot, deliveryTarget, matches, producer, baseSurfaceDigest: manifest.baseSurfaceDigest }, null, 2) + '\n');
  if (!matches) {
    process.stderr.write('PBWork delivery target differs. Run node tool/target.mjs --bind, then restart Producer/MCP clients and regenerate the delivery prompt.\n');
    if (process.argv.includes('--check')) process.exitCode = 1;
  }
}
