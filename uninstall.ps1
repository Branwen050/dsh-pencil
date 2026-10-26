# 从 DSH Desktop 的 web profile 卸载 dsh-pencil。
# 用法：powershell -NoProfile -ExecutionPolicy Bypass -File uninstall.ps1
$ErrorActionPreference = 'Stop'

$ProfileDir = Join-Path $env:APPDATA 'dsh-desktop\harness\profiles\web'
$Plugin     = Split-Path -Parent $MyInvocation.MyCommand.Path

$pnpm = Join-Path $env:APPDATA 'dsh-desktop\harness\.desktop-bin\pnpm.cmd'
if (-not (Test-Path $pnpm)) { throw "找不到 pnpm shim：$pnpm" }

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

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
Copy-Item (Join-Path $ProfileDir 'package.json') (Join-Path $ProfileDir "package.json.bak-unpencil-$stamp") -Force

Push-Location $ProfileDir
try { & $pnpm remove dsh-pencil } finally { Pop-Location }
Write-Host '[1/2] 依赖已移除'

& $node (Join-Path $Plugin 'remove-bundle.mjs') dsh-pencil
Write-Host '[2/2] bundle 条目已移除'

$j = Get-Content (Join-Path $ProfileDir 'package.json') -Raw | ConvertFrom-Json
Write-Host ''
Write-Host '---- 卸载结果 ----'
Write-Host ("依赖     : " + $j.dependencies.'dsh-pencil')
Write-Host ("bundles  : " + ($j.dsh.profile.bundles -contains 'dsh-pencil'))
Write-Host ("目录     : " + (Test-Path (Join-Path $ProfileDir 'node_modules\dsh-pencil')))
Write-Host ''
Write-Host '重启 DSH Desktop 后生效。'
exit 0
