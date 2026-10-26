#!/usr/bin/env node
import { spawn } from 'node:child_process';
import { createHash } from 'node:crypto';
import { copyFileSync, existsSync, mkdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseArgs } from 'node:util';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const { values } = parseArgs({ options: {
  preview: { type: 'boolean', default: false },
  'build-name': { type: 'string' },
  'build-number': { type: 'string' },
  help: { type: 'boolean', short: 'h' },
} });
if (values.help) {
  console.log('node tool/build-android.mjs [--preview] [--build-name 1.0.0] [--build-number 2]');
  console.log('Defaults to release signing. --preview explicitly uses the local debug key.');
  process.exit(0);
}
const version = readFileSync(path.join(root, 'pubspec.yaml'), 'utf8')
  .match(/^version:\s*([\w.-]+)\+(\d+)\s*$/m);
if (!version) throw new Error('pubspec.yaml must declare version: name+number.');
const buildName = values['build-name'] ?? version[1];
const buildNumber = values['build-number'] ?? version[2];
if (!/^\d+\.\d+\.\d+(?:[-.][\w.-]+)?$/.test(buildName) || !/^[1-9]\d*$/.test(buildNumber)) {
  throw new Error('Use a version such as 1.0.0 and a positive integer build number.');
}
const mode = values.preview ? 'preview' : 'release';
const environment = { ...process.env, YIKE_ANDROID_PREVIEW: String(values.preview) };
const propertiesFile = process.env.YIKE_ANDROID_KEY_PROPERTIES
  ?? [path.join(root, 'android/key.properties'), path.join(os.homedir(), '.config/yike/signing/key.properties')]
    .find(existsSync);
if (!values.preview) {
  const hasEnvironmentSigning = ['STORE_FILE', 'STORE_PASSWORD', 'KEY_ALIAS', 'KEY_PASSWORD']
    .every((key) => process.env[`YIKE_ANDROID_${key}`]?.trim());
  if (propertiesFile && !existsSync(propertiesFile)) throw new Error('Signing properties file does not exist.');
  if (!propertiesFile && !hasEnvironmentSigning) {
    throw new Error('Release signing is missing. Run node tool/create-android-signing.mjs, or use --preview.');
  }
  if (propertiesFile) environment.YIKE_ANDROID_KEY_PROPERTIES = path.resolve(propertiesFile);
}
const output = path.join(root, 'build/releases/android', mode);
const symbols = path.join(output, 'symbols');
mkdirSync(symbols, { recursive: true });
async function run(args) {
  await new Promise((resolve, reject) => {
    const child = spawn('flutter', args, { cwd: root, stdio: 'inherit', env: environment });
    child.once('error', reject);
    child.once('exit', (code) => code === 0 ? resolve() : reject(new Error(`flutter exited ${code}`)));
  });
}
await run(['pub', 'get', '--enforce-lockfile']);
await run([
  'build', 'apk', '--release', '--target-platform', 'android-arm64', '--split-per-abi',
  `--split-debug-info=${symbols}`, `--build-name=${buildName}`, `--build-number=${buildNumber}`,
]);
const apkName = `yike-${buildName}+${buildNumber}-arm64-${mode}.apk`;
const apk = path.join(output, apkName);
copyFileSync(path.join(root, 'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk'), apk);
const mapping = path.join(root, 'build/app/outputs/mapping/release/mapping.txt');
if (existsSync(mapping)) copyFileSync(mapping, path.join(symbols, 'mapping.txt'));
const manifest = {
  apk: apkName, buildName, flutterBuildNumber: buildNumber, signingMode: mode,
  abi: 'arm64-v8a', bytes: statSync(apk).size,
  sha256: createHash('sha256').update(readFileSync(apk)).digest('hex'),
};
writeFileSync(path.join(output, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`\n${mode} APK: ${apk}\nSize: ${(manifest.bytes / 1e6).toFixed(2)} MB\nSHA-256: ${manifest.sha256}`);
console.log(`Symbols and R8 mapping: ${symbols}`);
