# deploy.ps1 — safe deploy to pinagemaps.com
# Usage: .\deploy.ps1 "what you changed"
# Example: .\deploy.ps1 "removed SOS button"

param([string]$description = "update")

$date = Get-Date -Format "yyyy-MM-dd-HHmm"
$tag = "deploy-$date"

Write-Host "==> Pushing to GitHub..." -ForegroundColor Cyan
git push origin push-ready:main
if ($LASTEXITCODE -ne 0) { Write-Host "Push failed." -ForegroundColor Red; exit 1 }

Write-Host "==> Deploying to Vercel..." -ForegroundColor Cyan
npx vercel --prod
if ($LASTEXITCODE -ne 0) { Write-Host "Vercel deploy failed." -ForegroundColor Red; exit 1 }

Write-Host "==> Tagging this working deployment..." -ForegroundColor Cyan
git tag -a $tag -m "Working deployment: $description ($date)"
git push origin $tag

Write-Host ""
Write-Host "DONE — pinagemaps.com is live." -ForegroundColor Green
Write-Host "Tagged as: $tag" -ForegroundColor Green
Write-Host ""
Write-Host "To restore this exact version later, run:" -ForegroundColor Yellow
Write-Host "  git checkout $tag -- ." -ForegroundColor Yellow
