# Written with assistance of AI for clarity and structure

param(
    [ValidateSet("install", "uninstall")]
    [string]$Action = "install",

    [string]$InstallDir = "C:\xampp",
    [string]$NetworkDriveLetter = "W"
)

$ErrorActionPreference = "Stop"

# === CONSTANTS & PATHS ===
$ClassroomDir = Join-Path $InstallDir "classroom"
$StartCmdPath = Join-Path $ClassroomDir "start.cmd"
$ResetCmdPath = Join-Path $ClassroomDir "reset-database.cmd"

$CommonDesktopDir = [Environment]::GetFolderPath("CommonDesktopDirectory")
$CommonStartMenuDir = [Environment]::GetFolderPath("CommonStartMenu")
$ProgramShortcutDir = Join-Path $CommonStartMenuDir "\Programs\XAMPP Classroom"

$ShortcutDesktop = Join-Path $CommonDesktopDir "Start Xampp Classroom.lnk"
$ShortcutStart = Join-Path $ProgramShortcutDir "Start Xampp Classroom.lnk"
$ShortcutReset = Join-Path $ProgramShortcutDir "Reset MySQL Database.lnk"

$XamppIconPath = "C:\xampp\xampp_start.exe"

# === FUNCTIONS ===

function New-Shortcut {
    <#
    .SYNOPSIS
        Creates a Windows shortcut (.lnk)
    #>
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
    if ($Description)      { $Shortcut.Description = $Description }
    if ($IconLocation)     { $Shortcut.IconLocation = $IconLocation }
    $Shortcut.Save()
}

function Remove-Shortcut {
    <#
    .SYNOPSIS
        Removes a shortcut file if it exists
    #>
    param ([string]$ShortcutPath)
    if (Test-Path $ShortcutPath) {
        Remove-Item $ShortcutPath -Force
        Write-Host "Removed: $ShortcutPath"
    }
}

function Remove-IfEmpty {
    <#
    .SYNOPSIS
        Removes a directory only if it is empty
    #>
    param ([string]$Directory)
    if ((Test-Path $Directory) -and !(Get-ChildItem $Directory -Recurse -Force | Where-Object { -not $_.PSIsContainer })) {
        Remove-Item $Directory -Force -Recurse
        Write-Host "Removed empty directory: $Directory"
    }
}

function Test-ReparsePoint {
    <#
    .SYNOPSIS
        Checks if a path is a symlink (reparse point)
    #>
    param([string]$Path)
    $file = Get-Item $Path -Force -ErrorAction SilentlyContinue
    return [bool]($file.Attributes -band [IO.FileAttributes]::ReparsePoint)
}

function Remove-Symlink {
    <#
    .SYNOPSIS
        Removes a symlink without deleting its target content
    #>
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        Write-Host "Path does not exist: $Path"
        return
    }

    $item = Get-Item $Path -Force
    if (Test-ReparsePoint $item.FullName) {
        try {
            $item.Delete()
            Write-Host "Removed symlink: $($item.FullName)"
        } catch {
            Write-Warning "Failed to remove symlink: $($item.FullName) - $_"
        }
    } else {
        Write-Warning "Not a symlink: $($item.FullName) - skipping to avoid deleting real data."
    }
}

function Set-SDDLToDirectory {
    <#
    .SYNOPSIS
        Sets directory permissions using raw SDDL string
    #>
    param([string]$sddl, [string]$directory)
    $acl = Get-Acl $directory
    $acl.SetSecurityDescriptorSddlForm($sddl)
    Set-Acl $directory $acl
}

function Add-PublicDirectoryAndSymlink {
    param([string]$LinkPath, [string]$TargetPath)

    $sddl = "O:BAG:DUD:PAI(A;OICI;0x1e01ff;;;AU)(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)(A;OICI;0x1200a9;;;BU)"
    New-Item $TargetPath -ItemType Directory -Force | Out-Null
    Set-SDDLToDirectory $sddl $TargetPath
    Add-Symlink -LinkPath $LinkPath -TargetPath $TargetPath -UsePowerShell $true
}

function Add-Symlink {
    param(
        [string]$LinkPath,
        [string]$TargetPath,
        [bool]$UsePowerShell = $true
    )

    if (Test-Path $LinkPath) {
        if (Test-ReparsePoint $LinkPath) {
            (Get-Item $LinkPath).Delete()
        } else {
            Remove-Item $LinkPath -Force -Recurse
        }
    }

    if ($UsePowerShell) {
        New-Item -ItemType SymbolicLink -Path $LinkPath -Target $TargetPath
    } else {
        cmd.exe /c mklink /D "$LinkPath" "$TargetPath" | Out-Null
    }
}

function Add-PublicDirectoryRoot {
    param([string]$Path)

    $sddl = "O:BAG:DUD:PAI(A;OICI;0x1200a9;;;AU)(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)(A;OICI;0x1200a9;;;BU)"

    if (Test-Path $Path) {
        Write-Host "Xampp public directory already exists: $Path. Deleting..."
        Remove-Item $Path -Recurse -Force
    }

    New-Item $Path -ItemType Directory -Force | Out-Null
    Set-SDDLToDirectory $sddl $Path
}

# === INSTALL ===
if ($Action -eq "install") {
    Write-Host "Installing to $ClassroomDir..." -ForegroundColor Cyan

    $SourceDir = Join-Path $PSScriptRoot "src"
    $XamppPublicDir = "C:\xampp-public"
    $MysqlDataDir = "$InstallDir\mysql\data"
    $MysqlTemplateDir = "$InstallDir\mysql\data-template"

    New-Item $ClassroomDir -ItemType Directory -Force | Out-Null
    Copy-Item "$SourceDir\*" -Destination $ClassroomDir -Recurse -Force

    Set-Content $StartCmdPath -Value "@echo off`nPowerShell -ExecutionPolicy Bypass -File `"$ClassroomDir\XamppClassRoomStarter.ps1`" -Action start -NetworkDriveLetter $NetworkDriveLetter" -Encoding ASCII
    Set-Content $ResetCmdPath -Value "@echo off`nPowerShell -ExecutionPolicy Bypass -File `"$ClassroomDir\XamppClassRoomStarter.ps1`" -Action reset-database -NetworkDriveLetter $NetworkDriveLetter" -Encoding ASCII

    New-Item $ProgramShortcutDir -ItemType Directory -Force | Out-Null
    New-Shortcut $StartCmdPath $ShortcutDesktop -Description "Start Xampp Classroom" -IconLocation $XamppIconPath
    New-Shortcut $StartCmdPath $ShortcutStart -Description "Start Xampp Classroom" -IconLocation $XamppIconPath
    New-Shortcut $ResetCmdPath $ShortcutReset -Description "Reset the database"

    if (-not (Test-Path $InstallDir)) {
        Write-Error "XAMPP installation directory not found: $InstallDir"
        exit 1
    }

    Set-SDDLToDirectory "O:BAG:DUD:PAI(A;OICI;0x1200a9;;;AU)(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)(A;OICI;0x1200a9;;;BU)" $InstallDir

    Add-PublicDirectoryRoot $XamppPublicDir
    Add-PublicDirectoryAndSymlink "$InstallDir\apache\logs" "$XamppPublicDir\apache-logs"
    Add-PublicDirectoryAndSymlink "$InstallDir\phpmyadmin\tmp" "$XamppPublicDir\phpmyadmin-tmp"
    Add-PublicDirectoryAndSymlink "$InstallDir\tmp" "$XamppPublicDir\tmp"

    Add-Symlink "$InstallDir\htdocs" "$($NetworkDriveLetter):\htdocs" $false

    if (-not (Test-Path $MysqlTemplateDir)) {
        if (-not (Test-ReparsePoint $MysqlDataDir)) {
            Move-Item $MysqlDataDir $MysqlTemplateDir
        }
    }

    Add-Symlink "$MysqlDataDir" "$($NetworkDriveLetter):\mysqldata" $false

    Write-Host "Installation complete." -ForegroundColor Green
}

# === UNINSTALL ===
elseif ($Action -eq "uninstall") {
    Write-Host "Uninstalling..." -ForegroundColor Cyan

    foreach ($path in @(
        "$InstallDir\htdocs",
        "$InstallDir\tmp",
        "$InstallDir\mysql\data",
        "$InstallDir\apache\logs"
        "$InstallDir\phpmyadmin\tmp"
    )) {
        Remove-Symlink $path

        # The uninstaller expects to have the directories we have replaced with an symlink
        # We have to create them if they don't exist before the uninstaller can run properbly
        if (-Not(Test-Path $path)) {
            New-Item -ItemType Directory -Path $path
        }
    }

    foreach ($shortcut in @($ShortcutDesktop, $ShortcutStart, $ShortcutReset)) {
        Remove-Shortcut $shortcut
    }

    foreach ($file in @($StartCmdPath, $ResetCmdPath)) {
        if (Test-Path $file) {
            Remove-Item $file -Force
            Write-Host "Removed: $file"
        }
    }

    if (Test-Path $ClassroomDir) {
        try {
            Remove-Item $ClassroomDir -Recurse -Force
            Write-Host "Removed classroom directory: $ClassroomDir"
        } catch {
            Write-Warning "Could not remove $ClassroomDir. It may be in use by another process."
        }
    }

    Remove-IfEmpty $ProgramShortcutDir

    Write-Host "Uninstallation complete." -ForegroundColor Green
}