$source = $PSScriptRoot
$dest   = "C:\Games\World of Warcraft\_retail_\Interface\AddOns\HandyNotes_MythicPlus"

Write-Host "Deploying HandyNotes_MythicPlus..." -ForegroundColor Cyan
Write-Host "  From : $source"
Write-Host "  To   : $dest"
Write-Host ""

robocopy $source $dest /E /NJH /NJS `
    /XD ".git" ".github" ".vscode" ".release" `
    /XF "README.md" ".pkgmeta" "deploy.ps1"

if ($LASTEXITCODE -le 7) {
    Write-Host "Done." -ForegroundColor Green
} else {
    Write-Host "Robocopy error (code $LASTEXITCODE)." -ForegroundColor Red
    exit 1
}
