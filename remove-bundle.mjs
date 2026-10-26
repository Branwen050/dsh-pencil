// 从 profile 的 dsh.profile.bundles 里摘掉一个插件名。
// 用法：node remove-bundle.mjs [插件名，默认 dsh-pencil]
import fs from 'node:fs';
import os from 'node:os';

const name = process.argv[2] ?? 'dsh-pencil';
const pkgPath = `${os.homedir()}\\AppData\\Roaming\\dsh-desktop\\harness\\profiles\\web\\package.json`;
const raw = fs.readFileSync(pkgPath, 'utf8');
const parsed = JSON.parse(raw);
const bundles = parsed.dsh?.profile?.bundles ?? [];

if (!bundles.includes(name)) {
  console.log(`bundle ${name} not present, nothing to do`);
  process.exit(0);
}

const next = raw.replace(new RegExp(`(?m)^\\s*"${name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}",\\r?\\n`), '');
const check = JSON.parse(next);
if (check.dsh.profile.bundles.includes(name)) {
  console.error('removal failed: still present');
  process.exit(1);
}

fs.writeFileSync(pkgPath, next, 'utf8');
console.log(`bundle ${name} removed, total =`, check.dsh.profile.bundles.length);
