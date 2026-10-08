# Turn this PC into the build PC behind GitHub's "Build APK" button (a self-hosted GitHub Actions runner).
# Hand-written, 2026-10-08. Step by step guide: RUNNER.md. Run ONCE, in PowerShell opened "as administrator"
# (Windows only lets an administrator add the background service), from the copied project folder:
#   <folder>\tools-cache\pwsh\pwsh.exe -File <folder>\psx-android-tools\tools\setup-runner.ps1 -Discs \\NAS\share\psx-discs
# What it does, all inside <folder> except the Windows service it registers:
#  1. Portable git (MinGit) into tools-cache\mingit, if this PC has no git.
#  2. Signs the GitHub CLI in (once; a code to type at github.com/login/device).
#  3. Downloads GitHub's runner into <folder>\actions-runner (checked against GitHub's published SHA-256).
#  4. Registers it with dguillot-gh/psx-android-builds (private; label psx-build) and installs it as a Windows service that
#     runs as YOUR Windows account (it asks for your Windows password: that account's GitHub sign-in and
#     saved NAS password are what the builds use), so it starts by itself after a reboot.
#  5. Tells the runner where things are (actions-runner\.env): this folder, and the discs on the NAS.
# -NoService: skip the service; start the runner yourself with  actions-runner\bin\Runner.Listener.exe run
# Remove it later:  actions-runner\bin\Runner.Listener.exe remove --token <token from the repo's Settings > Actions > Runners>
param(
    [string]$Discs = "",          # NAS folder with one subfolder per game (see RUNNER.md); empty = discs in recomps\<game>\disc
    [string]$Name = $env:COMPUTERNAME,
    [switch]$NoService
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "paths.ps1")
$gh = Join-Path $ToolsCache "gh\bin\gh.exe"
$repo = "dguillot-gh/psx-android-builds"   # the PRIVATE repository with the Build APK button (never a public one)
$runnerDir = Join-Path $DriveRoot "actions-runner"
function Step([string]$m) { Write-Host ""; Write-Host "== $m" -ForegroundColor Cyan }
function Get-ReleaseAsset([string]$apiRepo, [string]$pattern) {
    $rel = Invoke-RestMethod "https://api.github.com/repos/$apiRepo/releases/latest" -Headers @{ "User-Agent" = "psx-android" }
    $asset = $rel.assets | Where-Object { $_.name -match $pattern } | Select-Object -First 1
    if (-not $asset) { throw "no asset matching $pattern in $apiRepo's latest release" }
    return @{ Release = $rel; Asset = $asset }
}
function Get-Verified([hashtable]$r, [string]$hash, [string]$out) {
    Invoke-WebRequest $r.Asset.browser_download_url -OutFile $out -UseBasicParsing
    if (-not $hash -or (Get-FileHash $out -Algorithm SHA256).Hash -ne $hash.ToUpper()) {
        Remove-Item $out -Force; throw "$($r.Asset.name): SHA-256 does not match GitHub's published one; not used"
    }
}

# Checks first: the tools the builds need must already be in this folder (copied from the drive).
foreach ($p in $gh, (Join-Path $ToolsCache "pwsh\pwsh.exe"), (Join-Path $DriveRoot "framework\psxrecomp\runtime\runtime.cmake")) {
    if (-not (Test-Path $p)) { throw "missing $p : copy the whole project folder first (RUNNER.md, step 2)" }
}
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $NoService -and -not $admin) { throw "open PowerShell with 'Run as administrator' (needed to add the service), or use -NoService" }
# The runner service never sees mapped drive letters: the discs must be a \\server\share path.
if ($Discs -match '^[A-Za-z]:' -and (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($Discs.Substring(0,2))'" -ErrorAction SilentlyContinue).DriveType -ne 3) {
    throw "$Discs is on a mapped or removable drive the build service can't see. Use the \\server\share path (in a normal PowerShell: (Get-PSDrive $($Discs[0])).DisplayRoot)."
}
if ($Discs -and -not (Test-Path -LiteralPath $Discs)) { throw "can't reach $Discs : check the path, and save the NAS password first (RUNNER.md, step 2)" }

# --- 1. git ----------------------------------------------------------------------------------------------
Step "1. git"
$minGit = Join-Path $ToolsCache "mingit"
if (Get-Command git -ErrorAction SilentlyContinue) { Write-Host "OK: this PC has git" }
elseif (Test-Path (Join-Path $minGit "cmd\git.exe")) { Write-Host "OK: portable git in $minGit" }
else {
    Write-Host "Downloading portable git (MinGit, about 40 MB) into $minGit ..."
    $r = Get-ReleaseAsset "git-for-windows/git" '^MinGit-[\d.]+-64-bit\.zip$'
    $hash = if ($r.Release.body -match ([regex]::Escape($r.Asset.name) + '\s*\|\s*([0-9a-f]{64})')) { $Matches[1] } else { "" }
    $zip = Join-Path $ToolsCache "mingit.zip"
    Get-Verified $r $hash $zip
    Expand-Archive $zip $minGit -Force
    Remove-Item $zip -Force
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { $env:PATH = (Join-Path $minGit "cmd") + ";$env:PATH" }

# --- 2. GitHub sign-in -----------------------------------------------------------------------------------
Step "2. GitHub sign-in (account dguillot-gh)"
& $gh auth status *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "A code is shown next: open github.com/login/device and type it in."
    # "workflow": Add game (add-game.ps1) puts new games in the Build APK list, a workflow file.
    & $gh auth login --hostname github.com --git-protocol https --web --scopes workflow
    & $gh auth status *> $null
    if ($LASTEXITCODE -ne 0) { throw "not signed in to GitHub" }
}
Write-Host "OK: signed in"

# --- 3. The runner --------------------------------------------------------------------------------------
Step "3. GitHub's runner"
if (Test-Path (Join-Path $runnerDir ".runner")) { throw "a runner is already set up in $runnerDir (remove it first, see the top of this script)" }
if (-not (Test-Path (Join-Path $runnerDir "bin\Runner.Listener.exe"))) {
    $r = Get-ReleaseAsset "actions/runner" '^actions-runner-win-x64-[\d.]+\.zip$'
    $hash = if ($r.Release.body -match '<!-- BEGIN SHA win-x64 -->([0-9a-f]{64})<!-- END SHA win-x64 -->') { $Matches[1] } else { "" }
    Write-Host "Downloading $($r.Asset.name) (about 200 MB)..."
    New-Item -ItemType Directory -Force $runnerDir | Out-Null
    $zip = Join-Path $ToolsCache "actions-runner.zip"
    Get-Verified $r $hash $zip
    Expand-Archive $zip $runnerDir -Force
    Remove-Item $zip -Force
}
Write-Host "OK: $runnerDir"

# --- 4. Register + service ------------------------------------------------------------------------------
Step "4. Registering with $repo"
$token = (& $gh api -X POST "repos/$repo/actions/runners/registration-token" --jq .token).Trim()
if (-not $token) { throw "could not get a registration code from GitHub" }
$cfg = @("configure", "--unattended", "--url", "https://github.com/$repo", "--token", $token, "--name", $Name,
         "--labels", "psx-build", "--work", "_work", "--replace")
if (-not $NoService) {
    $account = "$env:USERDOMAIN\$env:USERNAME"
    Write-Host "The service will run as $account (so it uses this account's GitHub sign-in and NAS password)."
    $pw = Read-Host "Windows password of $account" -AsSecureString
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pw))
    $cfg += @("--runasservice", "--windowslogonaccount", $account, "--windowslogonpassword", $plain)
}
& (Join-Path $runnerDir "bin\Runner.Listener.exe") @cfg
$code = $LASTEXITCODE
$plain = $null
if ($code -ne 0) { throw "the runner's setup failed (exit $code; see above)" }

# --- 5. Where things are ------------------------------------------------------------------------------
# The runner reads .env at start: these become environment variables for every build.
Step "5. Settings for the builds"
$envLines = @("PSX_ROOT=$DriveRoot")
if ($Discs) { $envLines += "PSX_DISCS=$Discs" }
Set-Content (Join-Path $runnerDir ".env") $envLines -Encoding ascii
$envLines | ForEach-Object { Write-Host "  $_" }
if (-not $NoService) {
    $svc = Get-Service "actions.runner.*" | Select-Object -First 1
    if ($svc) { Restart-Service $svc.Name; Write-Host "Service $($svc.Name): $((Get-Service $svc.Name).Status)" }
}
Write-Host ""
Write-Host "Done. On GitHub: $repo > Settings > Actions > Runners should list '$Name' as Idle." -ForegroundColor Green
Write-Host "Try it: $repo > Actions > Build APK > Run workflow > gex_recomp."
