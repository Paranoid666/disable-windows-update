#Requires -RunAsAdministrator
$ErrorActionPreference = 'Continue'

Write-Host '=== Permanently disable Windows Update ==='

$BackupDir = Join-Path $env:ProgramData 'WindowsUpdate_Backup'
New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
$LogFile = Join-Path $BackupDir 'disable.log'
function Log([string]$m) {
    $line = ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m)
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}
if (Test-Path $LogFile) { Clear-Content $LogFile }
Log ("PID={0} IsAdmin={1}" -f $PID, ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
Log "Script start."

# 1) Backup current service startup types so we can restore later
$svcNames = @('wuauserv','UsoSvc','WaaSMedicSvc')
$backup = @{}
foreach ($s in $svcNames) {
    $ser = Get-Service -Name $s -ErrorAction SilentlyContinue
    if ($ser) { $backup[$s] = $ser.StartType.ToString() }
}
$backup | ConvertTo-Json | Set-Content -Path (Join-Path $BackupDir 'service_start.json') -Encoding UTF8
Write-Host ("Backed up service startup types: " + $backup.Count + " entries")

# 2) Back up the Group Policy registry tree if it already exists
$wuPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
if (Test-Path $wuPolicy) {
    reg export 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' "$BackupDir\WindowsUpdate_policy.reg" /y | Out-Null
}

# 3) Group Policy: turn off automatic updates
$auKey = $wuPolicy + '\AU'
New-Item -Path $auKey -Force | Out-Null
New-ItemProperty -Path $auKey -Name 'NoAutoUpdate' -Value 1 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $wuPolicy -Name 'DoNotConnectToWindowsUpdateInternetLocations' -Value 1 -PropertyType DWord -Force | Out-Null
Write-Host 'Group Policy registry updated.'

# 4) Stop and disable the update-related services
#    Use sc.exe + direct registry Start value (Set-Service can silently fail on these).
foreach ($s in $svcNames) {
    Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
    $r = & sc.exe config $s start= disabled 2>&1
    if ($LASTEXITCODE -ne 0) { Log ("sc config {0} FAILED (code {1}): {2}" -f $s, $LASTEXITCODE, ($r -join ' ')) } else { Log ("sc config {0} OK: {1}" -f $s, ($r -join ' ')) }
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$s" -Name Start -Value 4 -Type DWord -ErrorAction SilentlyContinue
    $got = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$s" -Name Start -ErrorAction SilentlyContinue).Start
    Log ("{0}: sc config done, Start now={1}" -f $s, $got)
}
Write-Host 'Update services stopped and disabled (wuauserv, UsoSvc, WaaSMedicSvc).'
Log 'Services disabled step complete.'

# 5) Disable the scheduled tasks that can re-trigger updates
$tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
    $_.TaskPath -like '\Microsoft\Windows\UpdateOrchestrator\*' -or
    $_.TaskPath -like '\Microsoft\Windows\WindowsUpdate\*' -or
    $_.TaskPath -like '\Microsoft\Windows\WaaSMedic\*' -or
    $_.TaskPath -like '\Microsoft\Windows\UUS\*'
}
$tasks | Disable-ScheduledTask | Out-Null
Write-Host ("Disabled scheduled tasks: " + @($tasks).Count)

Write-Host 'Done. Windows Update is now permanently disabled.'
Write-Host 'To restore later, run: Enable-WindowsUpdate.ps1 (as Administrator).'
