# Run one task card through aider + the local model until its check passes.
#   pwsh -File auto.ps1 -Task 02          (matches tasks\02-*.md)
# The card names the file to write ("Task: write tools\X.ps1") and its check
# ("DONE WHEN tools\Y.ps1 exits 0"). The model only sees CONTEXT.md and the card.
param(
    [Parameter(Mandatory = $true)][string]$Task,
    [int]$Tries = 15,
    [string]$Model = "openai/qwen/qwen3.5-9b",
    [string]$ApiBase = "http://localhost:1234/v1"
)
Set-Location $PSScriptRoot
$card = Get-ChildItem tasks -Filter "$Task*.md" | Select-Object -First 1
if (-not $card) { Write-Host "No card tasks\$Task*.md"; exit 1 }
$text = Get-Content $card.FullName -Raw
if ($text -notmatch 'write (tools\\[\w.-]+\.ps1)') { Write-Host "Card does not say 'Task: write tools\X.ps1'"; exit 1 }
$file = $Matches[1]
if ($text -notmatch 'DONE WHEN (tools\\[\w.-]+\.ps1) exits 0') { Write-Host "Card has no 'DONE WHEN tools\Y.ps1 exits 0'"; exit 1 }
$check = $Matches[1]
if (-not (Test-Path $file)) { New-Item -ItemType File $file | Out-Null }

$lastTail = ""; $same = 0
for ($i = 1; $i -le $Tries; $i++) {
    pwsh -NoProfile -File $check *> check.log
    if ($LASTEXITCODE -eq 0) { Write-Host "DONE: $($card.Name) passed after $i pass(es)"; exit 0 }
    $tail = (Get-Content check.log -Tail 40) -join "`n"
    # The same failure three times in a row means the model is stuck: stop and split the task.
    if ($tail -eq $lastTail) { $same++ } else { $same = 0; $lastTail = $tail }
    if ($same -ge 2) { Write-Host "STUCK: same failure 3 times. Read check.log, make the card smaller or clearer."; exit 2 }
    "Attempt $i. Follow $($card.Name). The check $check failed with:`n$tail" | Set-Content msg.txt
    aider --model $Model --openai-api-base $ApiBase `
        --openai-api-key lm-studio --no-show-model-warnings --map-tokens 0 --yes-always `
        --edit-format whole --read CONTEXT.md --read $card.FullName --file $file `
        --message-file msg.txt --auto-test --test-cmd "pwsh -NoProfile -File $check"
}
Write-Host "GAVE UP after $Tries tries. See check.log."
exit 1
