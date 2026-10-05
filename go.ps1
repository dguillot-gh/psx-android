# Do every unfinished task card in order, hands-off.
#   pwsh -File go.ps1            run checks; for each failing card, run run.ps1 (LM Studio); continue until all pass
#   pwsh -File go.ps1 -Status    only show which cards pass
param([switch]$Status)
Set-Location $PSScriptRoot
$cards = Get-ChildItem tasks -Filter "*.md" | Sort-Object Name
foreach ($card in $cards) {
    $text = Get-Content $card.FullName -Raw
    if ($text -notmatch 'DONE WHEN (tools\\[\w.-]+\.ps1) exits 0') { Write-Host "SKIP $($card.Name): no DONE WHEN line"; continue }
    $check = $Matches[1]
    pwsh -NoProfile -File $check *> check.log
    if ($LASTEXITCODE -eq 0) { Write-Host "PASS $($card.Name)"; continue }
    Write-Host "TODO $($card.Name)"
    if ($Status) { continue }
    $num = $card.Name.Substring(0, 2)
    pwsh -NoProfile -File run.ps1 -Task $num
    if ($LASTEXITCODE -ne 0) { Write-Host "Stopped at $($card.Name). See check.log, then rerun go.ps1."; exit 1 }
}
if (-not $Status) { Write-Host "ALL TASKS PASS. Next: START-HERE.md step 7 (port a game)." }
exit 0
