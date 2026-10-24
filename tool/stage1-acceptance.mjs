#!/usr/bin/env node
// Temporary stage 1 runner. User acceptance does not delete files automatically.
import { spawn } from 'node:child_process';
import { copyFileSync, existsSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';
import { createInterface } from 'node:readline';
const root = fileURLToPath(new URL('../', import.meta.url));
const [mode, device] = process.argv.slice(2);
if (!['unit', 'native'].includes(mode) || (mode === 'native' && !device)) {
  console.log('临时验收入口：\n  node tool/stage1-acceptance.mjs unit\n  node tool/stage1-acceptance.mjs native <模拟器 device-id>\n人工声音与震动验收步骤：docs/plan/stage1-acceptance.md\n所有测试使用隔离存储，不读写生产 yike 数据。');
  process.exit(mode ? 1 : 0);
}
const args = mode === 'unit'
  ? ['test', 'test/stage1_acceptance_test.dart', 'test/stage1_laps_test.dart']
  : ['test', 'integration_test/stage1_acceptance_test.dart', '-d', device];
const child = spawn('flutter', args, { cwd: root, stdio: ['inherit', 'pipe', 'inherit'] });
createInterface({ input: child.stdout }).on('line', line => {
  console.log(line);
  const marker = 'YIKE_STAGE1_SCREENSHOT=';
  if (line.includes(marker)) {
    const source = line.slice(line.indexOf(marker) + marker.length).trim();
    // iOS Simulator paths are on the host. Copy while the sandbox still exists.
    if (existsSync(source)) {
      const directory = join(root, 'build/stage1');
      mkdirSync(directory, { recursive: true });
      const name = source.slice(source.lastIndexOf('/') + 1);
      copyFileSync(source, join(directory, name));
      console.log(`已保存截图：build/stage1/${name}`);
    }
  }
});
child.on('error', error => { console.error(error.message); process.exitCode = 1; });
child.on('exit', code => { process.exitCode = code ?? 1; });
