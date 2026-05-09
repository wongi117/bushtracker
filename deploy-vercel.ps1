# BushTrack Vercel Deployment Script (Windows PowerShell)
# Usage: .\deploy-vercel.ps1

Write-Host "🚀 BushTrack Vercel Deployment" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Check if Flutter is installed
try {
    $flutterVersion = flutter --version 2>&1 | Select-Object -First 1
    Write-Host "✅ Flutter found: $flutterVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Flutter not found! Please install Flutter first." -ForegroundColor Red
    Write-Host "   Download from: https://flutter.dev/docs/get-started/install" -ForegroundColor Yellow
    exit 1
}

# Check if Node.js/npm is installed (needed for Vercel CLI)
try {
    $nodeVersion = node --version 2>&1
    Write-Host "✅ Node.js found: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Node.js not found. Vercel CLI requires Node.js." -ForegroundColor Yellow
    Write-Host "   Download from: https://nodejs.org/" -ForegroundColor Yellow
    exit 1
}

# Check if Vercel CLI is installed
try {
    $vercelVersion = vercel --version 2>&1
    Write-Host "✅ Vercel CLI found: $vercelVersion" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Vercel CLI not found. Installing..." -ForegroundColor Yellow
    npm install -g vercel
    
    # Verify installation
    try {
        $vercelVersion = vercel --version 2>&1
        Write-Host "✅ Vercel CLI installed: $vercelVersion" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to install Vercel CLI" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "🏗️  Building Flutter web app..." -ForegroundColor Yellow

# Build Flutter web app
flutter build web --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Flutter build failed!" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Flutter build successful" -ForegroundColor Green
Write-Host ""

# Check if user is logged in to Vercel
Write-Host "🔑 Checking Vercel authentication..." -ForegroundColor Yellow
try {
    $user = vercel whoami 2>&1
    Write-Host "✅ Logged in as: $user" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Not logged in to Vercel. Please login:" -ForegroundColor Yellow
    Write-Host "   Run: vercel login" -ForegroundColor Cyan
    Write-Host ""
    vercel login
}

Write-Host ""
Write-Host "🚀 Deploying to Vercel..." -ForegroundColor Yellow

# Check if project is already linked
if (Test-Path ".vercel") {
    Write-Host "✅ Project already linked to Vercel" -ForegroundColor Green
    Write-Host "   Deploying to production..." -ForegroundColor Yellow
    vercel --prod
} else {
    Write-Host "🔗 First-time deployment. Linking project..." -ForegroundColor Yellow
    Write-Host "   Follow the prompts to configure your project:" -ForegroundColor Cyan
    vercel
}

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "================================" -ForegroundColor Green
    Write-Host "✅ Deployment successful!" -ForegroundColor Green
    Write-Host "🌐 Your BushTrack app is now live!" -ForegroundColor Green
    Write-Host "================================" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "❌ Deployment failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "📚 Next steps:" -ForegroundColor Cyan
Write-Host "   - Visit your deployed URL to see the app" -ForegroundColor White
Write-Host "   - Changes will auto-deploy on git push" -ForegroundColor White
Write-Host "   - Run 'vercel --prod' to deploy to production" -ForegroundColor White
