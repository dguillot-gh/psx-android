if (-not (Test-Path tools\new-game.ps1)) { New-Item -ItemType File tools\new-game.ps1 | Out-Null }
for ($i = 1; $i -le 15; $i++) {
    pwsh -NoProfile -File tools\check.ps1 *> check.log
    if ($LASTEXITCODE -eq 0) { Write-Host "DONE after $i passes"; break }
    $tail = (Get-Content check.log -Tail 40) -join "`n"
    "Attempt $i. Follow task.md. The check failed with:`n$tail" | Set-Content msg.txt
    aider --model openai/qwen/qwen3.5-9b --openai-api-base http://localhost:1234/v1 `
        --openai-api-key lm-studio --no-show-model-warnings --map-tokens 0 --yes-always `
        --read PS1-RECOMP-ANDROID-HANDBOOK.md --read task.md --file tools\new-game.ps1 `
        --message-file msg.txt --auto-test --test-cmd "pwsh -NoProfile -File tools\check.ps1"
}
