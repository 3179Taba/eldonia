# Eldonia Community Portal Development Startup Script
Write-Host "🚀 Starting Eldonia Community Portal Development Environment..." -ForegroundColor Green

# バックエンド起動
Write-Host "📡 Starting Backend Server..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd backend; npm run dev" -WindowStyle Normal

# 少し待機
Start-Sleep -Seconds 3

# フロントエンド起動
Write-Host "🌐 Starting Frontend Server..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd frontend; npm run dev" -WindowStyle Normal

Write-Host "✅ Development servers started!" -ForegroundColor Green
Write-Host "📊 Backend: http://localhost:3001" -ForegroundColor Cyan
Write-Host "🌐 Frontend: http://localhost:3000" -ForegroundColor Cyan
Write-Host "🔗 Health Check: http://localhost:3001/health" -ForegroundColor Cyan
Write-Host "📚 API Docs: http://localhost:3001/api" -ForegroundColor Cyan

Write-Host "`nPress any key to exit this script..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
