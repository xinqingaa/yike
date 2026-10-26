#!/usr/bin/env node
import { spawn } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { existsSync, mkdirSync, chmodSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { parseArgs } from 'node:util';

const { values } = parseArgs({ options: {
  directory: { type: 'string' },
  help: { type: 'boolean', short: 'h' },
} });
if (values.help) {
  console.log('node tool/create-android-signing.mjs [--directory <private-directory>]');
  process.exit(0);
}
const directory = path.resolve(values.directory ?? path.join(os.homedir(), '.config/yike/signing'));
const storeFile = path.join(directory, 'yike-release.jks');
const propertiesFile = path.join(directory, 'key.properties');
if (existsSync(storeFile) || existsSync(propertiesFile)) {
  throw new Error('Signing files already exist. Back them up and reuse them; do not rotate the key.');
}
process.umask(0o077);
mkdirSync(directory, { recursive: true, mode: 0o700 });
const password = randomBytes(32).toString('base64url');
const keytool = process.env.JAVA_HOME
  ? path.join(process.env.JAVA_HOME, 'bin', process.platform === 'win32' ? 'keytool.exe' : 'keytool')
  : 'keytool';
await new Promise((resolve, reject) => {
  const child = spawn(keytool, [
    '-genkeypair', '-noprompt', '-keystore', storeFile,
    '-storetype', 'PKCS12', '-storepass:env', 'YIKE_NEW_STORE_PASSWORD',
    '-keypass:env', 'YIKE_NEW_STORE_PASSWORD', '-alias', 'yike',
    '-keyalg', 'RSA', '-keysize', '2048', '-validity', '10000',
    '-dname', 'CN=Yike Android Release',
  ], { stdio: 'inherit', env: { ...process.env, YIKE_NEW_STORE_PASSWORD: password } });
  child.once('error', reject);
  child.once('exit', (code) => code === 0 ? resolve() : reject(new Error(`keytool exited ${code}`)));
});
chmodSync(storeFile, 0o600);
const escapedStoreFile = storeFile.replaceAll('\\', '\\\\').replaceAll(':', '\\:');
writeFileSync(propertiesFile, [
  `storeFile=${escapedStoreFile}`, `storePassword=${password}`,
  'keyAlias=yike', `keyPassword=${password}`, '',
].join('\n'), { flag: 'wx', mode: 0o600 });
console.log(`Keystore: ${storeFile}\nPrivate configuration: ${propertiesFile}`);
console.log('Back up both files securely. Passwords were not printed.');
