<# Premium: deep clean + SFC/DISM + Full Defender scan + startup inventory #>
$ErrorActionPreference = "SilentlyContinue"

# Logs
$LogDir = Join-Path $env:ProgramData "SystemBoost\logs"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$stamp = (Get-Date).ToString("yyyy-MM-dd_HH-mm-ss")
$log   = Join-Path $LogDir "premium_$stamp.log"
function Log($m){ ("[{0}] {1}" -f (Get-Date), $m) | Tee-Object -FilePath $log -Append }

# Elevate if needed
$admin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $admin) {
  Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
  exit
}

Log "Premium start"

# Clean caches (safe paths)
$paths = @("$env:TEMP","C:\Windows\Temp","C:\Windows\Prefetch")
foreach ($p in $paths){ if(Test-Path $p){
  Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}}
Log "Temp/cache cleared"

# Repairs
DISM /Online /Cleanup-Image /RestoreHealth      | Tee-Object -FilePath $log -Append
sfc /scannow                                   | Tee-Object -FilePath $log -Append

# Full malware scan (Defender)
Update-MpSignature                             | Tee-Object -FilePath $log -Append
Start-MpScan -ScanType FullScan                | Tee-Object -FilePath $log -Append

# Startup inventory (lets you prune heavy apps)
Get-CimInstance Win32_StartupCommand |
  Select-Object Name,Command,Location |
  Out-File (Join-Path $LogDir "startup_items_$stamp.txt")

Log "Premium complete"
Write-Host "✅ Premium deep clean complete. Logs: $LogDir"

