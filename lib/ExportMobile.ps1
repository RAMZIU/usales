$action = New-ScheduledTaskAction `
    -Execute "C:\xampp\htdocs\mobile\export.bat"

$trigger = New-ScheduledTaskTrigger `
    -Daily `
    -At "08:00"

$trigger.Repetition.Interval = (New-TimeSpan -Hours 1)
$trigger.Repetition.Duration = (New-TimeSpan -Hours 5)

Register-ScheduledTask `
    -TaskName "ExportMobile" `
    -Action $action `
    -Trigger $trigger `
    -User "SYSTEM" `
    -RunLevel Highest `
    -Force