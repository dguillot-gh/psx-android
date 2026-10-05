# Do one task card with the local model in LM Studio. No aider needed.
#   pwsh -File run.ps1 -Task 02
# Each attempt sends: the rules, CONTEXT.md, the card, the current file and the last check
# output. The model answers with the whole file in one code block; this script saves it,
# runs the card's check, and repeats until OK. Every reply is kept in logs\.
param(
    [Parameter(Mandatory = $true)][string]$Task,
    [int]$Tries = 12,
    [string]$Model = "qwen/qwen3.5-9b",
    [string]$ApiBase = "http://localhost:1234/v1",
    [int]$MaxTokens = 6000
)
Set-Location $PSScriptRoot
$card = Get-ChildItem tasks -Filter "$Task*.md" | Select-Object -First 1
if (-not $card) { Write-Host "No card tasks\$Task*.md"; exit 1 }
$cardText = Get-Content $card.FullName -Raw
if ($cardText -notmatch 'write (tools\\[\w.-]+\.ps1)') { Write-Host "Card does not say 'Task: write tools\X.ps1'"; exit 1 }
$file = $Matches[1]
if ($cardText -notmatch 'DONE WHEN (tools\\[\w.-]+\.ps1) exits 0') { Write-Host "Card has no 'DONE WHEN tools\Y.ps1 exits 0'"; exit 1 }
$check = $Matches[1]
$context = Get-Content CONTEXT.md -Raw
New-Item -ItemType Directory -Force logs | Out-Null

# The model's rules live in AGENT.md (everything below its "---" line).
$system = ((Get-Content AGENT.md -Raw) -split "(?m)^---\s*$", 2)[1].Trim()

function Run-Check {
    $out = pwsh -NoProfile -File $check 2>&1 | ForEach-Object { "$_" }
    @{ Ok = ($LASTEXITCODE -eq 0); Text = (($out | Select-Object -Last 40) -join "`n") }
}

$result = Run-Check
if ($result.Ok) { Write-Host "DONE: $($card.Name) already passes"; exit 0 }
$lastFail = ""; $same = 0
for ($i = 1; $i -le $Tries; $i++) {
    $current = if (Test-Path $file) { Get-Content $file -Raw } else { "" }
    if (-not $current) { $current = "(empty, not written yet)" }
    $user = "=== CONTEXT.md ===`n$context`n`n=== TASK CARD $($card.Name) ===`n$cardText`n`n" +
            "=== CURRENT $file ===`n$current`n`n=== LAST CHECK OUTPUT ($check) ===`n$($result.Text)`n`n" +
            "Write the complete $file now."
    $body = @{
        model = $Model; temperature = 0.2; max_tokens = $MaxTokens
        messages = @(@{ role = "system"; content = $system }, @{ role = "user"; content = $user })
    } | ConvertTo-Json -Depth 6
    Write-Host "Attempt $i : asking the model..."
    try {
        $resp = Invoke-RestMethod -Method Post -Uri "$ApiBase/chat/completions" -Body $body -ContentType "application/json; charset=utf-8" -TimeoutSec 900
    } catch {
        Write-Host "Cannot reach LM Studio at $ApiBase. Is its server running with $Model loaded? $_"; exit 1
    }
    $reply = $resp.choices[0].message.content
    Set-Content (Join-Path logs ("{0}-attempt{1:D2}.txt" -f $card.BaseName, $i)) $reply
    $reply = $reply -replace '(?s)<think>.*?</think>', ''
    if ($reply -match '(?m)^\s*UNKNOWN:(.*)$') { Write-Host "MODEL NEEDS INFO: UNKNOWN:$($Matches[1])"; exit 2 }
    if ($reply -notmatch '(?s)```[a-zA-Z0-9]*\r?\n(.*?)```') {
        Write-Host "No code block in the reply (see logs). Trying again."
        $result = @{ Ok = $false; Text = "Your last reply had no code block. Reply with the whole file in one ``````powershell block." }
        continue
    }
    Set-Content -Path $file -Value $Matches[1] -Encoding utf8NoBOM -NoNewline
    $result = Run-Check
    if ($result.Ok) {
        Write-Host "DONE: $($card.Name) passed on attempt $i"
        if ((Get-Command git -ErrorAction SilentlyContinue) -and (git rev-parse --is-inside-work-tree 2>$null)) {
            git add $file; git commit -q -m "$($card.BaseName): passes $check (attempt $i)"
        }
        exit 0
    }
    Write-Host ($result.Text -split "`n" | Where-Object { $_ -match 'FAIL' } | Select-Object -First 5 | Out-String)
    # The same failure three times in a row means the model is stuck.
    if ($result.Text -eq $lastFail) { $same++ } else { $same = 0; $lastFail = $result.Text }
    if ($same -ge 2) { Write-Host "STUCK: same failure 3 times. Make the card smaller or clearer, or ask Claude."; exit 2 }
}
Write-Host "GAVE UP after $Tries attempts. Replies are in logs\."
exit 1
