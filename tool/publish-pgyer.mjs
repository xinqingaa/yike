#!/usr/bin/env node
import { createHash } from 'node:crypto';
import { appendFileSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { parseArgs } from 'node:util';

const apiRoot = 'https://www.pgyer.com/apiv2/app/';
const pause = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// Dependency injection allows all publication states to be tested without uploading.
export async function publishPgyer({
  manifestPath, apiKey, password, description = '',
  fetchImpl = fetch, sleep = pause, pollAttempts = 60, pollInterval = 5000, pollTimeoutMs = 300000,
}) {
  if (!apiKey?.trim()) throw new Error('Missing PGYER_API_KEY. Configure it in GitHub Actions Secrets.');
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  if (manifest.signingMode !== 'release' || manifest.abi !== 'arm64-v8a') {
    throw new Error('Only a release-signed arm64 build can be published.');
  }
  if (typeof manifest.apk !== 'string' || path.basename(manifest.apk) !== manifest.apk || !manifest.apk.endsWith('.apk')) {
    throw new Error('Invalid APK path in the build manifest.');
  }
  const apk = readFileSync(path.join(path.dirname(manifestPath), manifest.apk));
  if (apk.length !== manifest.bytes || createHash('sha256').update(apk).digest('hex') !== manifest.sha256) {
    throw new Error('APK size or SHA-256 does not match the build manifest.');
  }
  async function request(stage, url, options, timeout = 30000) {
    let response;
    try {
      response = await fetchImpl(url, { ...options, redirect: 'error', signal: AbortSignal.timeout(timeout) });
    } catch {
      // Fetch errors may contain the API Key from buildInfo's query string.
      throw new Error(`${stage}: network request failed or timed out. Check the release status before retrying.`);
    }
    if (!response.ok) throw new Error(`${stage}: HTTP ${response.status}.`);
    return response;
  }
  async function json(response, stage) {
    try {
      const body = await response.json();
      if (!Number.isInteger(body?.code)) throw new Error();
      return body;
    } catch {
      throw new Error(`${stage}: invalid API response.`);
    }
  }
  const params = new URLSearchParams({
    _api_key: apiKey.trim(), buildType: 'android',
    buildInstallType: password ? '2' : '1', buildUpdateDescription: description,
  });
  if (password) params.set('buildPassword', password);
  const tokenResult = await json(await request('Upload token', `${apiRoot}getCOSToken`, {
    method: 'POST', body: params,
  }), 'Upload token');
  if (tokenResult.code !== 0) throw new Error(`Upload token: API code ${tokenResult.code}.`);
  const token = tokenResult.data;
  if (!token?.key || !token.endpoint || !token.params?.key || !token.params?.signature || !token.params?.['x-cos-security-token']) {
    throw new Error('Upload token: missing upload credentials.');
  }
  let uploadUrl;
  try {
    uploadUrl = new URL(token.endpoint);
    if (uploadUrl.protocol !== 'https:' || uploadUrl.username || uploadUrl.password) throw new Error();
  } catch {
    throw new Error('Upload token: invalid HTTPS upload endpoint.');
  }
  const form = new FormData();
  for (const key of ['key', 'signature', 'x-cos-security-token']) form.set(key, token.params[key]);
  form.set('x-cos-meta-file-name', manifest.apk);
  form.set('file', new Blob([apk], { type: 'application/vnd.android.package-archive' }), manifest.apk);
  // Do not retry mutations automatically: a lost response can mean an upload succeeded.
  const uploaded = await request('APK upload', uploadUrl, { method: 'POST', body: form }, 120000);
  if (uploaded.status !== 204) throw new Error(`APK upload: expected HTTP 204, received ${uploaded.status}.`);

  const infoUrl = new URL(`${apiRoot}buildInfo`);
  infoUrl.search = new URLSearchParams({ _api_key: apiKey.trim(), buildKey: token.key });
  const pollDeadline = Date.now() + pollTimeoutMs;
  for (let attempt = 0; attempt < pollAttempts; attempt++) {
    if (Date.now() >= pollDeadline) break;
    const result = await json(await request('Publication status', infoUrl, { method: 'GET' },
      Math.max(1, Math.min(30000, pollDeadline - Date.now()))), 'Publication status');
    if (result.code === 0) {
      const info = result.data;
      if (info?.buildIdentifier !== 'com.protobridge.yike' || Number(info.buildType) !== 2 || !info.buildKey) {
        throw new Error('Publication status: response does not identify the expected Android app.');
      }
      if (Number(info.buildFileSize) !== manifest.bytes || info.buildVersion !== manifest.buildName ||
          !/^[1-9]\d*$/.test(String(info.buildVersionNo))) {
        throw new Error('Publication status: published APK metadata does not match this build.');
      }
      if (!/^[\w-]+$/.test(info.buildShortcutUrl ?? '')) throw new Error('Publication status: missing download link.');
      let qrCodeUrl;
      try {
        qrCodeUrl = new URL(info.buildQRCodeURL);
        if (qrCodeUrl.protocol !== 'https:' || qrCodeUrl.username || qrCodeUrl.password) throw new Error();
      } catch {
        throw new Error('Publication status: missing HTTPS QR code URL.');
      }
      return {
        buildKey: info.buildKey, version: info.buildVersion,
        versionCode: String(info.buildVersionNo), bytes: manifest.bytes, sha256: manifest.sha256,
        downloadUrl: `https://www.pgyer.com/${info.buildShortcutUrl}`,
        qrCodeUrl: qrCodeUrl.href, passwordProtected: Boolean(password),
      };
    }
    if (result.code !== 1247) throw new Error(`Publication failed: API code ${result.code}.`);
    if (attempt + 1 < pollAttempts) await sleep(Math.max(0, Math.min(pollInterval, pollDeadline - Date.now())));
  }
  throw new Error('Publication status timed out. Check Pgyer before retrying; the APK may still be publishing.');
}

async function main() {
  const { values } = parseArgs({ options: {
    manifest: { type: 'string' },
    help: { type: 'boolean', short: 'h' },
  } });
  if (values.help) {
    console.log('node tool/publish-pgyer.mjs [--manifest <release/manifest.json>]');
    console.log('Requires PGYER_API_KEY; optional PGYER_INSTALL_PASSWORD enables password-protected installation.');
    return;
  }
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const manifestPath = path.resolve(values.manifest ?? path.join(root, 'build/releases/android/release/manifest.json'));
  const result = await publishPgyer({
    manifestPath, apiKey: process.env.PGYER_API_KEY, password: process.env.PGYER_INSTALL_PASSWORD,
    description: process.env.PGYER_UPDATE_DESCRIPTION ?? '',
  });
  writeFileSync(path.join(path.dirname(manifestPath), 'pgyer-release.json'), `${JSON.stringify(result, null, 2)}\n`);
  console.log(`Pgyer publication confirmed.\nDownload: ${result.downloadUrl}\nQR code: ${result.qrCodeUrl}`);
  if (process.env.GITHUB_STEP_SUMMARY) {
    appendFileSync(process.env.GITHUB_STEP_SUMMARY, [
      '\n## 蒲公英发布成功', '',
      `[下载 APK](${result.downloadUrl})`, '',
      `![安装二维码](${result.qrCodeUrl})`, '',
      `包体：${(result.bytes / 1e6).toFixed(2)} MB`,
      `安装方式：${result.passwordProtected ? '密码安装，使用已配置的安装密码' : '公开链接安装'}`, '',
    ].join('\n'));
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main().catch((error) => {
    // Keep errors concise; never dump request options, token responses or credentials.
    console.error(error.message);
    process.exitCode = 1;
  });
}
