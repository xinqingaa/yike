#!/usr/bin/env node
import { readFileSync, readdirSync, existsSync, statSync, realpathSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = realpathSync(path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..'));
const generated = new Set(['.git', '.dart_tool', 'build', 'node_modules', 'Pods', '.symlinks', 'ephemeral', '.fvm']);
const operationalLinks = new Set([
  'https://github.com/xinqingaa/yike/actions/workflows/android-build.yml',
]);
function markdownFiles(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    if (generated.has(entry.name)) return [];
    const file = path.join(dir, entry.name);
    return entry.isDirectory() ? markdownFiles(file) : file.endsWith('.md') ? [file] : [];
  });
}
function withoutFences(text) {
  let fence;
  return text.split('\n').map((line) => {
    const marker = line.match(/^ {0,3}(`{3,}|~{3,})/);
    if (!fence && marker) { fence = marker[1]; return ''; }
    if (fence) {
      if (marker && marker[1][0] === fence[0] && marker[1].length >= fence.length) fence = undefined;
      return '';
    }
    return line;
  }).join('\n');
}
function anchors(file) {
  const used = new Map();
  return new Set([...withoutFences(readFileSync(file, 'utf8')).matchAll(/^#{1,6}\s+(.+?)\s*#*$/gm)].map(([, heading]) => {
    const base = heading.toLowerCase().replace(/[`*_]/g, '').replace(/[^\p{L}\p{N}\s-]/gu, '').replace(/\s/g, '-');
    const count = used.get(base) ?? 0;
    used.set(base, count + 1);
    return count ? `${base}-${count}` : base;
  }));
}
function outside(target) {
  const relative = path.relative(root, target);
  return relative === '..' || relative.startsWith(`..${path.sep}`) || path.isAbsolute(relative);
}
const files = markdownFiles(root);
const errors = [], external = new Set();
let links = 0;
function check(file, href) {
  links++;
  const fail = (reason) => errors.push(`${path.relative(root, file)}: ${reason}: ${href}`);
  if (/^[a-z][\w+.-]*:/i.test(href) || href.startsWith('//')) {
    // Project operation pages are exact exceptions; reference files stay pinned.
    if (operationalLinks.has(href) || /^https:\/\/github\.com\/[^/]+\/[^/]+\/blob\/[a-f0-9]{40}\/.+/i.test(href)) external.add(href);
    else fail('external link; use an approved operation page or fixed GitHub commit');
    return;
  }
  if (path.isAbsolute(href) || /^[a-z]:[\\/]/i.test(href)) { fail('absolute file link'); return; }
  const [raw, fragment] = href.split('#');
  let target, anchor;
  try {
    target = raw ? path.resolve(path.dirname(file), decodeURIComponent(raw.split('?')[0])) : file;
    anchor = fragment ? decodeURIComponent(fragment) : undefined;
  } catch { fail('invalid URL encoding'); return; }
  if (outside(target)) { fail('link leaves repository'); return; }
  if (!existsSync(target)) { fail('missing target'); return; }
  if (outside(realpathSync(target))) { fail('symlink leaves repository'); return; }
  if (anchor && statSync(target).isFile() && target.endsWith('.md') && !anchors(target).has(anchor)) fail('missing anchor');
}
for (const file of files) {
  if (outside(realpathSync(file))) {
    errors.push(`${path.relative(root, file)}: Markdown source leaves repository`);
    continue;
  }
  const text = withoutFences(readFileSync(file, 'utf8')).replace(/(`+)[\s\S]*?\1/g, '');
  const targets = new Set();
  for (const match of text.matchAll(/!?\[[^\]\n]*\]\((<[^>]+>|[^\s)]+)(?:\s+["'][^"']*["'])?\)/g)) targets.add(match[1].replace(/^<|>$/g, ''));
  for (const match of text.matchAll(/^ {0,3}\[[^\]\n]+\]:\s*(<[^>]+>|[^\s]+)/gm)) targets.add(match[1].replace(/^<|>$/g, ''));
  for (const match of text.matchAll(/\b(?:href|src)\s*=\s*["']([^"']+)["']/g)) targets.add(match[1]);
  for (const match of text.matchAll(/<((?:https?|file):[^>]+)>/g)) targets.add(match[1]);
  for (const href of targets) check(file, href);
}
if (errors.length) {
  process.stderr.write(`${errors.join('\n')}\n`);
  process.exitCode = 1;
} else {
  process.stdout.write(`Documentation passed: ${files.length} Markdown files, ${links} links, ${external.size} external links.\n`);
}
