<# ============================================================
Free Cleaning (Windows) — Real Maintenance + Malware Removal
<# ============================================================
  Free Cleaning (Windows) — Real Maintenance + Malware Removal
  Actions:
   • Clean temp + browser caches
   • Empty Recycle Bin
   • Flush DNS / reset Winsock (post-reboot effect)
   • System repair (DISM + SFC)
   • Microsoft Defender: update signatures, Full Scan, optional Offline Scan
  Output: Detailed log on Desktop
  Requirements: Windows 10/11, PowerShell 5+, Admin
============================================================ #>

# --- Elevate to Admin (relaunch if needed) ---
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  $ps = (Get-Command pwsh -ErrorAction SilentlyContinue)?.Source
  if (-not $ps) { $ps = (Get-Command powershell).Source }
  Start-Process $ps -Verb RunAs -ArgumentList "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
  exit
}

# --- Start log ---
$Log = Join-Path $env:USERPROFILE "Desktop\FreeCleaning-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
Start-Transcript -Path $Log -Append | Out-Null
Write-Host "==== Free Cleaning started $(Get-Date) ===="

# --- Create a restore point (safety) ---
try {
  Checkpoint-Computer -Description "FreeCleaning" -RestorePointType "MODIFY_SETTINGS" | Out-Null
  Write-Host "Restore point created."
} catch { Write-Host "Restore point skipped: $($_.Exception.Message)" }

# --- Close browsers (unlock caches) ---
$procs = "chrome","msedge","firefox","brave"
foreach ($p in $procs) { Get-Process $p -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }

# --- Clean temp folders ---
$paths = @("$env:TEMP", "$env:WINDIR\Temp", "$env:LOCALAPPDATA\Temp")
foreach ($p in $paths) {
  if (Test-Path $p) {
    Write-Host "Cleaning $p"
    Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
  }
}

# --- Empty Recycle Bin ---
try { Clear-RecycleBin -Force -ErrorAction Stop; Write-Host "Recycle Bin emptied." } catch { Write-Host "Recycle Bin skip: $($_.Exception.Message)" }

# --- Clean browser caches (Chrome/Edge/Firefox/Brave) ---
$cachePaths = @(
  "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\*",
  "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache\*",
  "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\*",
  "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache\*",
  "$env:APPDATA\Mozilla\Firefox\Profiles\*\cache2\*",
  "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cache\*",
  "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Code Cache\*"
)
foreach ($c in $cachePaths) { Remove-Item $c -Recurse -Force -ErrorAction SilentlyContinue }
Write-Host "Browser caches cleared."

# --- Networking snappiness ---
ipconfig /flushdns | Out-Null
try { netsh winsock reset | Out-Null; Write-Host "Winsock reset queued (takes effect after reboot)." } catch {}

# --- Component store & system repairs ---
try { Dism.exe /Online /Cleanup-Image /StartComponentCleanup | Out-Null } catch {}
try { Dism.exe /Online /Cleanup-Image /ScanHealth | Out-Null } catch {}
try { Dism.exe /Online /Cleanup-Image /RestoreHealth | Out-Null; Write-Host "DISM restore health complete." } catch { Write-Host "DISM error: $($_.Exception.Message)" }

try { sfc /scannow | Out-Null; Write-Host "SFC completed." } catch { Write-Host "SFC error: $($_.Exception.Message)" }

# --- Defender: update + full scan ---
try { Update-MpSignature | Out-Null; Write-Host "Defender signatures updated." } catch { Write-Host "Signature update error: $($_.Exception.Message)" }
try {
  Write-Host "Starting Microsoft Defender FULL scan..."
  Start-MpScan -ScanType FullScan
  Write-Host "Full scan initiated."
} catch { Write-Host "Full scan error: $($_.Exception.Message)" }

# --- Defender: Offline Scan (most effective for active threats) ---
Write-Host ""
Write-Host ">>> Recommended: Microsoft Defender OFFLINE scan (reboots to scan before Windows starts)."
$choice = Read-Host "Press ENTER to start Offline Scan & reboot now, or type 'skip' to skip"
if ($choice -ne "skip") {
  try {
    Write-Host "Scheduling Offline Scan. Your PC will reboot shortly..."
    Start-MpWDOScan
  } catch {
    Write-Host "Offline scan could not be started: $($_.Exception.Message)"
  }
} else {
  Write-Host "Offline scan skipped by user."
}

Write-Host "==== Free Cleaning finished (pre-reboot) $(Get-Date) ===="
Write-Host "Log saved to: $Log"
Stop-Transcript | Out-Null
