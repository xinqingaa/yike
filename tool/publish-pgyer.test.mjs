import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { publishPgyer } from './publish-pgyer.mjs';

function fixture(t, manifestOverrides = {}) {
  const dir = mkdtempSync(path.join(os.tmpdir(), 'yike-pgyer-test-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const bytes = Buffer.from('test APK bytes');
  writeFileSync(path.join(dir, 'app.apk'), bytes);
  const manifest = {
    apk: 'app.apk', signingMode: 'release', abi: 'arm64-v8a', buildName: '1.0.0',
    bytes: bytes.length, sha256: createHash('sha256').update(bytes).digest('hex'), ...manifestOverrides,
  };
  const manifestPath = path.join(dir, 'manifest.json');
  writeFileSync(manifestPath, JSON.stringify(manifest));
  return { manifestPath, apiKey: 'test-api-secret', manifest };
}
const reply = (body, status = 200) => new Response(JSON.stringify(body), { status });
const token = () => reply({ code: 0, data: {
  key: 'apps/upload.apk', endpoint: 'https://upload.cos.ap-shanghai.myqcloud.com',
  params: { key: 'apps/upload.apk', signature: 'test-signature', 'x-cos-security-token': 'test-token' },
} });
function published(f) {
  return reply({ code: 0, data: {
    buildKey: 'published-key', buildIdentifier: 'com.protobridge.yike', buildType: 2,
    buildFileSize: f.manifest.bytes, buildVersion: '1.0.0', buildVersionNo: '2001',
    buildShortcutUrl: 'yike-test', buildQRCodeURL: 'https://www.pgyer.com/app/qrcode/yike-test',
  } });
}

test('uploads only the APK, then waits for publication and returns download information', async (t) => {
  const f = fixture(t); let calls = 0; let sleeps = 0;
  const result = await publishPgyer({ ...f, password: 'test-install-password', sleep: async () => { sleeps++; },
    fetchImpl: async (url, options) => {
      calls++;
      assert.equal(options.redirect, 'error');
      if (calls === 1) {
        assert.equal(options.body.get('_api_key'), f.apiKey);
        assert.equal(options.body.get('buildInstallType'), '2');
        assert.equal(options.body.get('buildPassword'), 'test-install-password');
        return token();
      }
      if (calls === 2) {
        assert.equal(options.body.get('file').size, f.manifest.bytes);
        assert.equal(options.body.get('_api_key'), null);
        return new Response(null, { status: 204 });
      }
      assert.equal(new URL(url).searchParams.get('buildKey'), 'apps/upload.apk');
      return calls === 3 ? reply({ code: 1247 }) : published(f);
    },
  });
  assert.equal(calls, 4); assert.equal(sleeps, 1);
  assert.equal(result.downloadUrl, 'https://www.pgyer.com/yike-test');
  assert.equal(result.passwordProtected, true);
  assert.ok(!JSON.stringify(result).includes('test-install-password'));
});

test('refuses preview, tampered APK and unsafe manifest paths before sending credentials', async (t) => {
  for (const overrides of [{ signingMode: 'preview' }, { sha256: 'wrong' }, { apk: '../app.apk' }]) {
    const f = fixture(t, overrides);
    await assert.rejects(publishPgyer({ ...f, fetchImpl: async () => assert.fail('No network request expected') }));
  }
});

test('rejects missing API key before making a request', async (t) => {
  await assert.rejects(publishPgyer({ ...fixture(t), apiKey: '', fetchImpl: async () => assert.fail() }), /Missing PGYER_API_KEY/);
});

test('reports API failure codes without echoing credential-bearing server responses', async (t) => {
  const f = fixture(t);
  await assert.rejects(publishPgyer({ ...f, fetchImpl: async () => reply({ code: 1002, message: f.apiKey }) }),
    (error) => error.message.includes('1002') && !error.message.includes(f.apiKey));
});

test('does not retry an upload whose response was lost', async (t) => {
  const f = fixture(t); let calls = 0;
  await assert.rejects(publishPgyer({ ...f, fetchImpl: async () => {
    if (++calls === 1) return token();
    throw new Error(`Transport error with ${f.apiKey}`);
  } }), (error) => /Check the release status/.test(error.message) && !error.message.includes(f.apiKey));
  assert.equal(calls, 2);
});

test('fails on publication rejection and bounds pending-state polling', async (t) => {
  for (const status of [1216, 1247]) {
    const f = fixture(t); let calls = 0;
    await assert.rejects(publishPgyer({ ...f, pollAttempts: 2, sleep: async () => {}, fetchImpl: async () => {
      calls++;
      if (calls === 1) return token();
      if (calls === 2) return new Response(null, { status: 204 });
      return reply({ code: status });
    } }), status === 1216 ? /API code 1216/ : /timed out/);
    assert.equal(calls, status === 1216 ? 3 : 4);
  }
});

test('rejects malformed status metadata rather than reporting a different build as successful', async (t) => {
  const f = fixture(t); let calls = 0;
  await assert.rejects(publishPgyer({ ...f, fetchImpl: async () => {
    if (++calls === 1) return token();
    if (calls === 2) return new Response(null, { status: 204 });
    return reply({ code: 0, data: { buildIdentifier: 'another.app', buildType: 2, buildKey: 'other-key' } });
  } }), /expected Android app/);
});

test('rejects HTTP errors, invalid JSON and insecure upload endpoints', async (t) => {
  for (const response of [
    new Response('failure', { status: 500 }),
    new Response('not-json'),
    reply({ code: 0, data: { key: 'app', endpoint: 'http://upload.example.com',
      params: { key: 'app', signature: 'sig', 'x-cos-security-token': 'token' } } }),
  ]) {
    let calls = 0;
    await assert.rejects(publishPgyer({ ...fixture(t), fetchImpl: async () => { calls++; return response; } }));
    assert.equal(calls, 1);
  }
});
