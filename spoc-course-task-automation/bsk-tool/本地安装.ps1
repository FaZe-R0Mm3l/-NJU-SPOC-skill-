<#
================================================================
  本地安装 bsk 工具（离线版）
  整理：婉清
================================================================

  作用：把这个包里自带的 bsk.exe 装到本机，不用联网。

  用法（在 PowerShell 里跑）：
    powershell -ExecutionPolicy Bypass -File "本地安装.ps1"

  或者右键这个文件，选「使用 PowerShell 运行」。

  它做这几件事：
    1. 把 windows-x64 文件夹里的 bsk.exe 复制到用户目录下的 .local/bin
    2. 把这个目录加进 PATH（用户级，永久生效）
    3. 顺便写进 .bashrc，方便 Git Bash 环境
    4. 跑一次 bsk --version 验证

  装完还需要手动装浏览器扩展，脚本最后会提示你。
================================================================
#>

#Requires -Version 5.1

$ErrorActionPreference = "Stop"

# 本脚本所在目录（bsk-tool 目录）
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SourceExe = Join-Path $ScriptDir "windows-x64\bsk.exe"
$ExtDir    = Join-Path $ScriptDir "browser-extension"
$InstallDir = Join-Path $HOME ".local\bin"
$TargetExe  = Join-Path $InstallDir "bsk.exe"

function Say    { param([string]$m) Write-Host "==> $m" -ForegroundColor Cyan }
function Ok     { param([string]$m) Write-Host "  [OK] $m" -ForegroundColor Green }
function Warn   { param([string]$m) Write-Host "  [!]  $m" -ForegroundColor Yellow }
function Fail   { param([string]$m) Write-Host "  [X]  $m" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "==========================================" -ForegroundColor White
Write-Host "  bsk 工具 · 本地离线安装" -ForegroundColor White
Write-Host "==========================================" -ForegroundColor White
Write-Host ""

# ── 0. 检查包内文件是否齐全 ──────────────────────────────────────
Say "检查安装包内容"
if (-not (Test-Path -LiteralPath $SourceExe)) {
    Fail "没找到 windows-x64\bsk.exe。请确认这个脚本和 windows-x64 文件夹在一起。"
}
if (-not (Test-Path -LiteralPath (Join-Path $ExtDir "manifest.json"))) {
    Warn "没找到 browser-extension\manifest.json，稍后扩展安装可能受影响。"
}
Ok "安装包内容正常"

# ── 1. 停止正在运行的旧 daemon（如果装了旧版本）────────────────
Say "检查是否有正在运行的旧版本"
$oldExe = $null
try {
    $cmd = Get-Command bsk -ErrorAction SilentlyContinue
    if ($cmd) { $oldExe = $cmd.Source }
} catch {}

if ($oldExe) {
    Write-Host "  发现已安装的 bsk：$oldExe" -ForegroundColor Gray
    $oldHome = if ($env:BSK_HOME) { $env:BSK_HOME } else { Join-Path $HOME ".bsk" }
    $daemonJson = Join-Path $oldHome "daemon.json"
    if (Test-Path -LiteralPath $daemonJson) {
        Warn "检测到旧版守护进程在跑，先停掉它"
        try {
            & $oldExe daemon stop 2>$null | Out-Null
            Start-Sleep -Seconds 1
            Ok "旧版本已停止"
        } catch {
            Warn "停止失败，如果后面报错，手动删掉 $daemonJson 再重试"
        }
    }
} else {
    Ok "没有已安装的旧版本"
}

# ── 2. 复制 bsk.exe ─────────────────────────────────────────────
Say "安装 bsk.exe 到 $InstallDir"
if (-not (Test-Path -LiteralPath $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

# 先复制到临时文件，再原子替换，避免文件被占用导致装坏
$staged = "$TargetExe.install-" + [Guid]::NewGuid().ToString("N")
try {
    [System.IO.File]::Copy($SourceExe, $staged, $true)
    if ([System.IO.File]::Exists($TargetExe)) {
        [System.IO.File]::Replace($staged, $TargetExe, [NullString]::Value)
    } else {
        [System.IO.File]::Move($staged, $TargetExe)
    }
    Ok "bsk.exe 已就位"
} catch {
    if ([System.IO.File]::Exists($staged)) { [System.IO.File]::Delete($staged) }
    Fail "复制失败：$($_.Exception.Message)。可能是 bsk 正在运行，关掉它再试。"
}

# ── 3. 加进 PATH ────────────────────────────────────────────────
Say "配置 PATH"
$userPath = @([Environment]::GetEnvironmentVariable("PATH", "User") -split ";" | Where-Object { $_ })
if ($userPath -contains $InstallDir) {
    Ok "用户 PATH 里已经有了"
} else {
    $newPath = (@($InstallDir) + $userPath) -join ";"
    [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
    Ok "已加入用户 PATH（新开的终端生效）"
}

# 当前会话也加上
if (($env:PATH -split ";") -notcontains $InstallDir) {
    $env:PATH = "$InstallDir;$env:PATH"
}

# Git Bash 环境（~/.bashrc）
$bashrc = Join-Path $HOME ".bashrc"
$unixPath = $InstallDir -replace '\\', '/'
if ($unixPath -match '^([A-Z]):(.*)$') {
    $unixPath = "/" + $matches[1].ToLower() + $matches[2]
}
$exportLine = "export PATH=`"$unixPath`:`$PATH`"  # bsk CLI"
$already = $false
if (Test-Path -LiteralPath $bashrc) {
    $content = [System.IO.File]::ReadAllText($bashrc)
    if ($content.Contains($exportLine)) { $already = $true }
}
if ($already) {
    Ok "~/.bashrc 里已经有了"
} else {
    [System.IO.File]::AppendAllText($bashrc, "`n$exportLine`n", (New-Object System.Text.UTF8Encoding($false)))
    Ok "已写入 ~/.bashrc（Git Bash 用）"
}

# ── 4. 验证 ─────────────────────────────────────────────────────
Say "验证安装"
try {
    $ver = & $TargetExe --version 2>&1
    if ($LASTEXITCODE -ne 0) { Fail "bsk 跑不起来，退出码 $LASTEXITCODE" }
    Ok "bsk 版本：$ver"
} catch {
    Fail "验证失败：$($_.Exception.Message)"
}

# ── 5. 提示扩展安装 ─────────────────────────────────────────────
Write-Host ""
Write-Host "==========================================" -ForegroundColor White
Write-Host "  下一步：装浏览器扩展（必须手动）" -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor White
Write-Host ""
Write-Host "  浏览器出于安全，不允许脚本自动装扩展，这一步只能手点。" -ForegroundColor Gray
Write-Host ""
Write-Host "  扩展文件夹在这里：" -ForegroundColor White
Write-Host "    $ExtDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "  操作步骤：" -ForegroundColor White
Write-Host "    1. 打开 Chrome 或 Edge" -ForegroundColor Gray
Write-Host "    2. 地址栏输入 chrome://extensions  （Edge 是 edge://extensions）" -ForegroundColor Gray
Write-Host "    3. 打开右上角的『开发者模式』开关" -ForegroundColor Gray
Write-Host "    4. 点『加载已解压的扩展程序』" -ForegroundColor Gray
Write-Host "    5. 选中上面那个 browser-extension 文件夹" -ForegroundColor Gray
Write-Host ""
Write-Host "  装好扩展后，运行下面这条命令确认连接成功：" -ForegroundColor White
Write-Host "    bsk doctor" -ForegroundColor Cyan
Write-Host "  看到 'extension connected' 就说明成功了。" -ForegroundColor Gray
Write-Host ""

Say "完成"
