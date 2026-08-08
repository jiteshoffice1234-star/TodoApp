Set-Location 'C:\Users\Dell\Desktop\ANDRIUD\TodoApp'
$env:PATH = "D:\DevTools\Git\cmd;$env:PATH"

Write-Host "=== BUILD ==="
npm run build 2>&1 | Select-String -Pattern "building target|error|FAILED"

Write-Host "`n=== INSTALL ==="
$setup = Get-ChildItem 'dist' -Filter 'Todo App Setup *.exe' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($setup) {
    Start-Process $setup.FullName -ArgumentList '/S' -Wait
    Write-Host "Installed!"
}

Write-Host "`n=== LAUNCH ==="
Start-Process "C:\Users\Dell\AppData\Local\Programs\Todo App\Todo App.exe"
