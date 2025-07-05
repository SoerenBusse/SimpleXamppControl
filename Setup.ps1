# Transparenz: Geschrieben mit AI
param(
    [ValidateSet("install", "uninstall")]
    [string]$Action = "install",
    
    [string]$InstallDir = "C:\xampp",
    [string]$NetworkDriveLetter = "W"
)

$ErrorActionPreference = "Stop"

# === Common paths ===
$ClassroomDir = Join-Path $InstallDir "classroom"
$StartCmdPath = Join-Path $ClassroomDir "start.cmd"
$ResetCmdPath = Join-Path $ClassroomDir "reset-database.cmd"

$CommonDesktopDir = [Environment]::GetFolderPath("CommonDesktopDirectory")
$CommonStartMenuDir = [Environment]::GetFolderPath("CommonStartMenu")
$ProgramDir = Join-Path $CommonStartMenuDir "\Programs\XAMPP Classroom"

$ShortcutDesktop = Join-Path $CommonDesktopDir "Start Xampp Classroom.lnk"
$ShortcutStart = Join-Path $ProgramDir "Start Xampp Classroom.lnk"
$ShortcutReset = Join-Path $ProgramDir "Reset MySQL Database.lnk"

$XamppIcon = "C:\xampp\xampp_start.exe"

# === Helper: Create shortcut ===
function New-Shortcut {
    param (
        [string]$Target,
        [string]$ShortcutPath,
        [string]$WorkingDirectory = "",
        [string]$Description = "",
        [string]$IconLocation = ""
    )
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $Target
    if ($WorkingDirectory) { $Shortcut.WorkingDirectory = $WorkingDirectory }
    if ($Description) { $Shortcut.Description = $Description }
    if ($IconLocation) { $Shortcut.IconLocation = $IconLocation }
    $Shortcut.Save()
}

# === Helper: Remove shortcut ===
function Remove-Shortcut {
    param ([string]$ShortcutPath)
    if (Test-Path $ShortcutPath) {
        Remove-Item $ShortcutPath -Force
        Write-Host "Removed: $ShortcutPath"
    }
}

# === Helper: Remove dir if empty ===
function Remove-IfEmpty {
    param ([string]$Directory)
    if ((Test-Path $Directory) -and !(Get-ChildItem -Path $Directory -Recurse -Force | Where-Object { -not $_.PSIsContainer })) {
        Remove-Item $Directory -Force -Recurse
        Write-Host "Removed empty directory: $Directory"
    }
}

# === INSTALL ===
if ($Action -eq "install") {
    Write-Host "Installing to $ClassroomDir..." -ForegroundColor Cyan

    $ScriptSource = Join-Path $PSScriptRoot "src"

    New-Item -Path $ClassroomDir -ItemType Directory -Force | Out-Null
    Copy-Item -Path "$ScriptSource\*" -Destination $ClassroomDir -Recurse -Force

    # Write start.cmd
    $StartCmdContent = @"
@echo off
PowerShell -ExecutionPolicy Bypass -File "$ClassroomDir\XamppClassRoomStarter.ps1" -Action start -UserWebDriveLetter $NetworkDriveLetter
"@
    Set-Content -Path $StartCmdPath -Value $StartCmdContent -Encoding ASCII

    # Write reset-database.cmd
    $ResetCmdContent = @"
@echo off
PowerShell -ExecutionPolicy Bypass -File "$ClassroomDir\XamppClassRoomStarter.ps1" -Action reset-database -UserWebDriveLetter $NetworkDriveLetter
"@
    Set-Content -Path $ResetCmdPath -Value $ResetCmdContent -Encoding ASCII

    New-Item -Path $ProgramDir -ItemType Directory -Force | Out-Null

    # Shortcuts
    New-Shortcut -Target $StartCmdPath -ShortcutPath $ShortcutDesktop -Description "Start Xampp Classroom" -IconLocation $XamppIcon
    New-Shortcut -Target $StartCmdPath -ShortcutPath $ShortcutStart -Description "Start Xampp Classroom" -IconLocation $XamppIcon
    New-Shortcut -Target $ResetCmdPath -ShortcutPath $ShortcutReset -Description "Reset the database"

    Write-Host "Installation complete." -ForegroundColor Green
}

# === UNINSTALL ===
elseif ($Action -eq "uninstall") {
    Write-Host "Uninstalling from $ClassroomDir..." -ForegroundColor Cyan

    # Remove shortcuts
    Remove-Shortcut $ShortcutDesktop
    Remove-Shortcut $ShortcutStart
    Remove-Shortcut $ShortcutReset

    # Remove .cmd files
    foreach ($file in @($StartCmdPath, $ResetCmdPath)) {
        if (Test-Path $file) {
            Remove-Item $file -Force
            Write-Host "Removed: $file"
        }
    }

    # Remove main directory
    if (Test-Path $ClassroomDir) {
        Remove-Item $ClassroomDir -Recurse -Force
        Write-Host "Removed classroom directory: $ClassroomDir"
    }

    # Cleanup Start Menu
    Remove-IfEmpty $ProgramDir

    Write-Host "Uninstallation complete." -ForegroundColor Green
}