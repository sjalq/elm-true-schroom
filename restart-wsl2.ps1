Write-Host "Shutting down WSL2..." -ForegroundColor Yellow
wsl --shutdown

Write-Host "Starting WSL2..." -ForegroundColor Green  
wsl -d Ubuntu

Write-Host "WSL2 restarted successfully!" -ForegroundColor Green 