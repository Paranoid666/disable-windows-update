#Requires -RunAsAdministrator
$ErrorActionPreference = 'Continue'

Write-Host '=== Restore Windows Update to default ==='

$svcNames = @('wuauserv','UsoSvc','WaaSMedicSvc')
$defaults = @{ 'wuauserv'='Manual'; 'UsoSvc'='Automatic'; 'WaaSMedicSvc'='Manual' }
$startValue = @{ 'Automatic'=2; 'Manual'=3; 'Disabled'=4 }
$BackupDir = Join-Path $env:ProgramData 'WindowsUpdate_Backup'
$backup = @{}
$jf = Join-Path $BackupDir 'service_start.json'
if (Test-Path $jf) { $backup = Get-Content $jf -Raw | ConvertFrom-Json }

# 1) Restore service startup types (from backup, otherwise default) and start them
foreach ($s in $svcNames) {
    $st = $backup.$s
    if (-not $st -or $st -eq 'Disabled') { $st = $defaults[$s] }
    & sc.exe config $s start= $st | Out-Null
    $v = $startValue[$st]; if (-not $v) { $v = 3 }
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$s" -Name Start -Value $v -Type DWord -ErrorAction SilentlyContinue
    Start-Service -Name $s -ErrorAction SilentlyContinue
}
Write-Host 'Services restored to original startup types and started.'

# 2) Remove the Group Policy registry values/keys we set
$wuPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
if (Test-Path ($wuPolicy + '\AU')) {
    Remove-Item ($wuPolicy + '\AU') -Recurse -Force -ErrorAction SilentlyContinue
}
Remove-ItemProperty -Path $wuPolicy -Name 'DoNotConnectToWindowsUpdateInternetLocations' -ErrorAction SilentlyContinue
Write-Host 'Group Policy registry restored.'

# 3) Re-enable the scheduled tasks
Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
    $_.TaskPath -like '\Microsoft\Windows\UpdateOrchestrator\*' -or
    $_.TaskPath -like '\Microsoft\Windows\WindowsUpdate\*' -or
    $_.TaskPath -like '\Microsoft\Windows\WaaSMedic\*' -or
    $_.TaskPath -like '\Microsoft\Windows\UUS\*'
} | Enable-ScheduledTask | Out-Null
Write-Host 'Scheduled tasks re-enabled.'

Write-Host 'Done. Windows Update is restored to the system default state.'
