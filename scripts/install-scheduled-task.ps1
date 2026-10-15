# Run once (normal user OK if policy allows): registers daily 08:00 task
$ErrorActionPreference = 'Stop'
$taskName = 'RS-Update-Feeds'
$script = 'E:\Users\Administrator\Projects\RS\scripts\update-feeds.ps1'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$script`""
$trigger = New-ScheduledTaskTrigger -Daily -At 08:00
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description 'Daily pull LAN RSS into kddy918/RS and push'
Get-ScheduledTask -TaskName $taskName | Format-List TaskName,State
Write-Host 'Scheduled task registered.'
