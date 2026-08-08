$ErrorActionPreference = "Stop"
Set-Location "C:\Users\Dell\Desktop\ANDRIUD\TodoApp"

Write-Host "Building Desktop App..." -ForegroundColor Cyan
npx electron-builder --win --config.win.icon="resources/icons/icon.png" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nBuild SUCCESS!" -ForegroundColor Green
    
    # Kill running instances
    Get-Process -Name "Todo App" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    
    # Install
    $installer = Get-ChildItem "dist\*.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($installer) {
        Write-Host "Installing: $($installer.Name)" -ForegroundColor Yellow
        Start-Process $installer.FullName -ArgumentList "/S" -Wait
        Write-Host "Installed!" -ForegroundColor Green
        
        # Launch
        Start-Process "C:\Users\Dell\AppData\Local\Programs\Todo App\Todo App.exe"
        Write-Host "Launched!" -ForegroundColor Cyan
    }
} else {
    Write-Host "Build FAILED!" -ForegroundColor Red
}
