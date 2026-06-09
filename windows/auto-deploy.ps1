# NFG Word Games — idempotent auto-deploy (safe to run every 5 minutes)
$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DefaultRepo = Join-Path $env:USERPROFILE "Documents\nfg-word-games"
$RepoRoot = if (Test-Path (Join-Path $ScriptDir "..\server.py")) {
    (Resolve-Path (Join-Path $ScriptDir "..")).Path
} elseif (Test-Path (Join-Path $DefaultRepo "server.py")) {
    (Resolve-Path $DefaultRepo).Path
} else {
    $DefaultRepo
}

$LogFile = Join-Path $ScriptDir "deploy.log"
$HashFile = Join-Path $ScriptDir ".requirements-hash"
$DeployInfoFile = Join-Path $RepoRoot "data\deploy-info.json"
$Port = 19877

function Write-DeployLog {
    param([string]$Message)
    $line = "{0} {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    if ((Test-Path $LogFile) -and ((Get-Item $LogFile).Length -gt 512000)) {
        $rotated = "$LogFile.old"
        if (Test-Path $rotated) { Remove-Item $rotated -Force }
        Move-Item $LogFile $rotated -Force
    }
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Get-GitShortHash {
    param([string]$Root)
    try {
        Push-Location $Root
        $hash = git rev-parse --short HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and $hash) { return $hash.Trim() }
    } catch {
    } finally {
        Pop-Location
    }
    return $null
}

function Stop-PortListener {
    param([int]$ListenPort)
    $killed = @()
    try {
        $connections = Get-NetTCPConnection -LocalPort $ListenPort -State Listen -ErrorAction SilentlyContinue
        foreach ($conn in $connections) {
            $procId = $conn.OwningProcess
            if ($procId -and $procId -notin $killed) {
                Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
                $killed += $procId
                Write-DeployLog "Stopped process $procId listening on port $ListenPort"
            }
        }
    } catch {
        $pattern = ":$ListenPort\s"
        netstat -ano | Select-String $pattern | ForEach-Object {
            $parts = ($_.Line -split "\s+") | Where-Object { $_ -ne "" }
            $procId = [int]$parts[-1]
            if ($procId -gt 0 -and $procId -notin $killed) {
                Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
                $killed += $procId
                Write-DeployLog "Stopped process $procId on port $ListenPort (netstat fallback)"
            }
        }
    }
    return ($killed.Count -gt 0)
}

function Write-DeployInfo {
    param(
        [bool]$PullOk,
        [bool]$RestartOk,
        [string]$GitHash
    )
    $dataDir = Join-Path $RepoRoot "data"
    if (-not (Test-Path $dataDir)) {
        New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
    }
    $info = @{
        timestamp      = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        gitRev         = $GitHash
        last_pull_ok   = $PullOk
        last_restart_ok = $RestartOk
    }
    $info | ConvertTo-Json -Compress | Set-Content -Path $DeployInfoFile -Encoding UTF8
}

Write-DeployLog "=== auto-deploy start (repo=$RepoRoot) ==="

$pullOk = $false
$restartOk = $false
$gitHash = $null

if (-not (Test-Path (Join-Path $RepoRoot ".git"))) {
    Write-DeployLog "SKIP pull: not a git repo at $RepoRoot"
} else {
    try {
        Push-Location $RepoRoot
        git fetch origin main 2>&1 | ForEach-Object { Write-DeployLog "fetch: $_" }
        if ($LASTEXITCODE -ne 0) {
            Write-DeployLog "WARN: git fetch failed (exit $LASTEXITCODE)"
        }
        git pull origin main 2>&1 | ForEach-Object { Write-DeployLog "pull: $_" }
        if ($LASTEXITCODE -eq 0) {
            $pullOk = $true
        } else {
            Write-DeployLog "WARN: git pull failed (exit $LASTEXITCODE)"
        }
        $gitHash = Get-GitShortHash -Root $RepoRoot
    } catch {
        Write-DeployLog "ERROR during git pull: $_"
    } finally {
        Pop-Location
    }
}

if (-not (Test-Path (Join-Path $RepoRoot "server.py"))) {
    Write-DeployLog "ERROR: server.py missing — aborting before restart"
    Write-DeployInfo -PullOk $pullOk -RestartOk $false -GitHash $gitHash
    exit 1
}

$venvPython = Join-Path $RepoRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $venvPython)) {
    Write-DeployLog "Creating Python virtual environment..."
    try {
        Push-Location $RepoRoot
        py -3 -m venv .venv 2>&1 | ForEach-Object { Write-DeployLog "venv: $_" }
        if ($LASTEXITCODE -ne 0) {
            Write-DeployLog "ERROR: failed to create venv"
            Write-DeployInfo -PullOk $pullOk -RestartOk $false -GitHash $gitHash
            exit 1
        }
    } finally {
        Pop-Location
    }
}

$reqFile = Join-Path $RepoRoot "requirements.txt"
if (Test-Path $reqFile) {
    $reqHash = (Get-FileHash $reqFile -Algorithm SHA256).Hash
    $prevHash = if (Test-Path $HashFile) { Get-Content $HashFile -Raw } else { "" }
    $pipQuiet = ($reqHash -eq $prevHash.Trim())
    try {
        Push-Location $RepoRoot
        if ($pipQuiet) {
            & $venvPython -m pip install -r requirements.txt -q 2>&1 | ForEach-Object { Write-DeployLog "pip: $_" }
        } else {
            Write-DeployLog "requirements.txt changed — running pip install"
            & $venvPython -m pip install -r requirements.txt 2>&1 | ForEach-Object { Write-DeployLog "pip: $_" }
            Set-Content -Path $HashFile -Value $reqHash -Encoding UTF8 -NoNewline
        }
    } catch {
        Write-DeployLog "WARN: pip install error: $_"
    } finally {
        Pop-Location
    }
}

$reconcileScript = Join-Path $RepoRoot "scripts\reconcile_scores.py"
if (Test-Path $reconcileScript) {
    try {
        Push-Location $RepoRoot
        & $venvPython $reconcileScript 2>&1 | ForEach-Object { Write-DeployLog "reconcile: $_" }
        if ($LASTEXITCODE -ne 0) {
            Write-DeployLog "WARN: reconcile_scores.py exited $LASTEXITCODE (non-fatal)"
        }
    } catch {
        Write-DeployLog "WARN: reconcile_scores.py error (non-fatal): $_"
    } finally {
        Pop-Location
    }
}

try {
    Stop-PortListener -ListenPort $Port | Out-Null
    Start-Sleep -Seconds 1

    $proc = Start-Process -FilePath $venvPython `
        -ArgumentList @("-m", "uvicorn", "server:app", "--host", "0.0.0.0", "--port", "$Port") `
        -WorkingDirectory $RepoRoot `
        -WindowStyle Hidden `
        -PassThru

    Start-Sleep -Seconds 2
    if ($proc -and -not $proc.HasExited) {
        $restartOk = $true
        Write-DeployLog "Started uvicorn pid=$($proc.Id) on port $Port"
    } else {
        Write-DeployLog "ERROR: uvicorn exited immediately"
    }
} catch {
    Write-DeployLog "ERROR restarting server: $_"
}

if (-not $gitHash) {
    $gitHash = Get-GitShortHash -Root $RepoRoot
}

Write-DeployInfo -PullOk $pullOk -RestartOk $restartOk -GitHash $gitHash
Write-DeployLog "=== auto-deploy done (pull=$pullOk restart=$restartOk rev=$gitHash) ==="
