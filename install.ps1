# 安装 dsh-pencil 到 DSH Desktop 的 web profile。
# 用法：powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1
$ErrorActionPreference = 'Stop'

$ProfileDir = Join-Path $env:APPDATA 'dsh-desktop\harness\profiles\web'
$Plugin     = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Test-Path (Join-Path $ProfileDir 'package.json'))) {
  throw "找不到 DSH Desktop 的 web profile：$ProfileDir（先启动一次 DSH Desktop）"
}

# 必须走 Desktop 的 pnpm shim：PATH 里的 node 是 Electron 自带的
$pnpm = Join-Path $env:APPDATA 'dsh-desktop\harness\.desktop-bin\pnpm.cmd'
if (-not (Test-Path $pnpm)) { throw "找不到 pnpm shim：$pnpm" }

# 找一个能跑脚本的 node
$node = (Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $node) {
  $candidate = Join-Path $env:ProgramFiles 'nodejs\node.exe'
  if (Test-Path $candidate) { $node = $candidate }
}
if (-not $node) {
  $shim = Join-Path $env:APPDATA 'dsh-desktop\harness\.desktop-bin\node.cmd'
  if (Test-Path $shim) { $node = $shim }
}
if (-not $node) { throw '找不到可用的 node' }

# 备份 manifest
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
Copy-Item (Join-Path $ProfileDir 'package.json')   (Join-Path $ProfileDir "package.json.bak-pencil-$stamp")   -Force
Copy-Item (Join-Path $ProfileDir 'pnpm-lock.yaml') (Join-Path $ProfileDir "pnpm-lock.yaml.bak-pencil-$stamp") -Force
Write-Host "[1/3] 已备份 package.json / pnpm-lock.yaml（$stamp）"

# 以 link 方式装依赖
Push-Location $ProfileDir
try {
  & $pnpm add "link:$Plugin" --prefer-offline
  if ($LASTEXITCODE -ne 0) { throw "pnpm add 失败（exit $LASTEXITCODE）" }
} finally { Pop-Location }
Write-Host '[2/3] 依赖已装（node_modules\dsh-pencil -> 源码目录）'

# 注册进 dsh.profile.bundles
& $node (Join-Path $Plugin 'add-bundle.mjs')
if ($LASTEXITCODE -ne 0) { throw "add-bundle 失败（exit $LASTEXITCODE）" }
Write-Host '[3/3] 已注册 bundle'

$j = Get-Content (Join-Path $ProfileDir 'package.json') -Raw | ConvertFrom-Json
Write-Host ''
Write-Host '---- 安装结果 ----'
Write-Host ("依赖      : " + $j.dependencies.'dsh-pencil')
Write-Host ("bundles   : " + ($j.dsh.profile.bundles -contains 'dsh-pencil') + "（共 " + $j.dsh.profile.bundles.Count + " 个）")
Write-Host ("目录链接  : " + (Test-Path (Join-Path $ProfileDir 'node_modules\dsh-pencil\lib\client.js')))
Write-Host ''
Write-Host '最后一步：彻底退出 DSH Desktop（托盘图标右键退出）后重新打开。'
exit 0
