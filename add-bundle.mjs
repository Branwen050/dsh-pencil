// 把一个 DSH 插件注册进 Desktop web profile 的 dsh.profile.bundles。
//
// pnpm 只写 dependencies 和 lockfile，不会碰这个字段——少了这步插件不会被加载。
//
// 用法（在插件包目录里跑）：
//   node add-bundle.mjs            # 用当前目录 package.json 的 name
//   node add-bundle.mjs dsh-pencil # 显式指定包名
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const selfPkg = path.join(here, 'package.json');
const fallback = fs.existsSync(selfPkg) ? JSON.parse(fs.readFileSync(selfPkg, 'utf8')).name : undefined;
const name = process.argv[2] ?? fallback;

if (!name) {
  console.error('拿不到包名：请传参数，或在插件包目录里运行');
  process.exit(1);
}

const pkgPath = `${os.homedir()}\\AppData\\Roaming\\dsh-desktop\\harness\\profiles\\web\\package.json`;
if (!fs.existsSync(pkgPath)) {
  console.error(`找不到 profile：${pkgPath}`);
  process.exit(1);
}

const raw = fs.readFileSync(pkgPath, 'utf8');
const parsed = JSON.parse(raw);
const bundles = parsed.dsh?.profile?.bundles;

if (!Array.isArray(bundles)) {
  console.error('profile 里没有 dsh.profile.bundles 字段');
  process.exit(1);
}

if (bundles.includes(name)) {
  console.log(`bundle ${name} 已注册，无需重复`);
  process.exit(0);
}

if (!Object.hasOwn(parsed.dependencies ?? {}, name)) {
  console.warn(`提示：dependencies 里没有 ${name}——先 pnpm add 再跑本脚本，否则启动时解析不到包`);
}

const match = raw.match(/("bundles"\s*:\s*\[)([\s\S]*?)(\n\s*\])/);
if (!match) {
  console.error('bundles 数组格式无法识别');
  process.exit(1);
}

let body = match[2];
const tail = body.match(/\n(\s*)"([^"]*)",?\s*$/);
const indent = tail ? tail[1] : '        ';
body = `${body.replace(/,\s*$/, '').trimEnd()},\n${indent}"${name}"`;

const next = raw.replace(match[0], `${match[1]}${body}${match[3]}`);
const check = JSON.parse(next);
if (!check.dsh.profile.bundles.includes(name)) {
  console.error('写入后校验失败');
  process.exit(1);
}

fs.writeFileSync(pkgPath, next, 'utf8');
console.log(`已注册 ${name}，bundles 现有 ${check.dsh.profile.bundles.length} 项`);
