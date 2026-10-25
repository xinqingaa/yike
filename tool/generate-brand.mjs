#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
function run(args) {
  const result = spawnSync('dart', args, { cwd: root, stdio: 'inherit' });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`dart ${args.join(' ')} failed`);
}
run(['run', 'tool/prepare_brand.dart']);
const project = path.join(root, 'ios/Runner.xcodeproj/project.pbxproj');
// flutter_launcher_icons 0.14.4 matches every ASSETCATALOG setting in Debug
// and Release. Preserve this unrelated Boolean setting across regeneration.
const symbolKey = 'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS';
const symbolSetting = new RegExp(`(${symbolKey} = )([^;]+)(;)`, 'g');
const values = [...fs.readFileSync(project, 'utf8').matchAll(symbolSetting)]
  .map(match => match[2]);
try {
  run(['run', 'flutter_launcher_icons']);
} finally {
  let index = 0;
  const corrected = fs.readFileSync(project, 'utf8').replace(
    symbolSetting,
    (_, prefix, value, suffix) => `${prefix}${values[index++] ?? value}${suffix}`,
  );
  fs.writeFileSync(project, corrected);
}
run(['run', 'flutter_native_splash:create']);
const iconDirectory = path.join(root, 'ios/Runner/Assets.xcassets/AppIcon.appiconset');
const iconManifest = JSON.parse(fs.readFileSync(path.join(iconDirectory, 'Contents.json'), 'utf8'));
const usedIconFiles = new Set(iconManifest.images.map(image => image.filename));
for (const filename of fs.readdirSync(iconDirectory)) {
  if (/^Icon-App.*\.png$/.test(filename) && !usedIconFiles.has(filename)) {
    fs.unlinkSync(path.join(iconDirectory, filename));
  }
}
run(['run', 'tool/check_brand.dart']);
