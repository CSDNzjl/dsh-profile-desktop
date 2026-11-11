#Requires -Version 5.1
<#
.SYNOPSIS
    在新电脑上恢复 DSH profile 的插件配置。

.DESCRIPTION
    把本仓库的 5 个配置文件复制到 DSH profile 目录，然后用 DSH 自带的
    pnpm 安装 package.json 里声明的全部插件。

    注意：本脚本不会恢复任何凭据、SSH 机器清单或会话数据 —— 那些不在仓库里，
    需要你手动重新配置。

.PARAMETER Profile
    DSH profile 名称，默认 desktop。

.PARAMETER DshHome
    DSH 数据根目录。默认取环境变量 DSH_HOME，否则 %USERPROFILE%\.dsh。

.EXAMPLE
    .\restore.ps1

.EXAMPLE
    .\restore.ps1 -Profile web
#>
param(
    [string]$Profile = "desktop",
    [string]$DshHome = $(if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $env:USERPROFILE ".dsh" })
)

$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
$target = Join-Path $DshHome "profiles\$Profile"

$configFiles = @(
    "package.json",
    "cordis.patch.yml",
    "cordis.yml",
    "pnpm-lock.yaml",
    "pnpm-workspace.yaml"
)

Write-Host ""
Write-Host "DSH profile 配置恢复" -ForegroundColor Cyan
Write-Host "----------------------------------------"
Write-Host "DSH_HOME : $DshHome"
Write-Host "Profile  : $Profile"
Write-Host "目标目录 : $target"
Write-Host ""

if (-not (Test-Path $DshHome)) {
    Write-Host "错误：找不到 DSH 数据目录 $DshHome" -ForegroundColor Red
    Write-Host "请先运行一次 DeepSeek Harness，或用 -DshHome 指定正确路径。" -ForegroundColor Yellow
    exit 1
}

# ── 1. 备份现有配置 ────────────────────────────────────────────────
if (Test-Path $target) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backup = "$target.backup-$stamp"
    Write-Host "[1/3] 备份现有配置 -> $backup" -ForegroundColor Yellow
    Copy-Item $target $backup -Recurse -Force
} else {
    Write-Host "[1/3] 目标目录不存在，新建" -ForegroundColor Yellow
    New-Item -ItemType Directory -Force $target | Out-Null
}

# ── 2. 复制配置文件 ────────────────────────────────────────────────
Write-Host "[2/3] 复制配置文件" -ForegroundColor Yellow
$copied = 0
foreach ($f in $configFiles) {
    $s = Join-Path $here $f
    if (Test-Path $s) {
        Copy-Item $s (Join-Path $target $f) -Force
        Write-Host "      + $f"
        $copied++
    } else {
        Write-Host "      ! 缺少 $f（跳过）" -ForegroundColor DarkYellow
    }
}
if ($copied -eq 0) {
    Write-Host "错误：一个配置文件都没找到，确认你在仓库根目录运行本脚本。" -ForegroundColor Red
    exit 1
}

# ── 3. 安装依赖 ────────────────────────────────────────────────────
Write-Host "[3/3] 安装插件依赖" -ForegroundColor Yellow

$nodeExe = $null
$pnpmMjs = $null

# 优先用 DSH 自带的 node + pnpm（版本与宿主一致，最稳）
$runtimesRoot = Join-Path $DshHome "dsh-runtimes"
if (Test-Path $runtimesRoot) {
    foreach ($rt in (Get-ChildItem $runtimesRoot -Directory -ErrorAction SilentlyContinue)) {
        $n = Join-Path $rt.FullName "dependencies\node\bin\node.exe"
        $p = Join-Path $rt.FullName "dependencies\pnpm\bin\pnpm.mjs"
        if ((Test-Path $n) -and (Test-Path $p)) {
            $nodeExe = $n
            $pnpmMjs = $p
            break
        }
    }
}

try {
    if ($nodeExe -and $pnpmMjs) {
        Write-Host "      使用 DSH 自带运行时：$rt"
        & $nodeExe $pnpmMjs install --dir $target
    }
    elseif (Get-Command pnpm -ErrorAction SilentlyContinue) {
        Write-Host "      未找到 DSH 运行时，使用系统 pnpm"
        & pnpm install --dir $target
    }
    elseif (Get-Command npm -ErrorAction SilentlyContinue) {
        Write-Host "      未找到 pnpm，尝试 npx pnpm"
        & npx --yes pnpm install --dir $target
    }
    else {
        Write-Host ""
        Write-Host "错误：找不到 pnpm 也找不到 npm。" -ForegroundColor Red
        Write-Host "请安装 Node.js 后重试：https://nodejs.org/" -ForegroundColor Yellow
        exit 1
    }
}
catch {
    Write-Host ""
    Write-Host "依赖安装失败：$($_.Exception.Message)" -ForegroundColor Red
    Write-Host "配置文件已就位，可手动在 $target 下运行 pnpm install" -ForegroundColor Yellow
    exit 1
}

# ── 完成 ───────────────────────────────────────────────────────────
Write-Host ""
Write-Host "----------------------------------------"
Write-Host "完成！" -ForegroundColor Green
Write-Host ""
Write-Host "接下来需要手动做的（这些不在仓库里）：" -ForegroundColor Cyan
Write-Host "  1. 重启 DeepSeek Harness"
Write-Host "  2. 重新登录 AI 服务（OpenCode Go / DeepSeek 账号等）"
Write-Host "  3. 重新配置 dsh-remote 的 SSH 机器（设置 -> 远程工作区）"
Write-Host "  4. 重新扫码配置 dsh-pocket（局域网/公网密码会重新生成）"
Write-Host ""
