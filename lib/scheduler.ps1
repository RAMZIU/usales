# scheduler.ps1
$scriptPath = "C:\xampp\htdocs\mobile"
$phpPath = "C:\xampp\php\php.exe"

# Boucle infinie
while ($true) {
    $now = Get-Date
    
    # Export Day toutes les 30 minutes
    if (($now.Minute -eq 0 -or $now.Minute -eq 30) -and $now.Second -eq 0) {
        Write-Host "$now - Lancement export_day.php"
        Start-Process -NoNewWindow -FilePath $phpPath -ArgumentList "$scriptPath\export_day.php"
        Start-Sleep -Seconds 5
    }
    
    # Export PHP à 7h00
    if ($now.Hour -eq 7 -and $now.Minute -eq 0 -and $now.Second -eq 0) {
        Write-Host "$now - Lancement export_php.php"
        Start-Process -NoNewWindow -FilePath $phpPath -ArgumentList "$scriptPath\export_php.php"
        Start-Sleep -Seconds 5
    }
    
    Start-Sleep -Seconds 1
} 