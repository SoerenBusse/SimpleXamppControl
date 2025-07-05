# Erklärung des Skript:
# Da die Benutzer keine Änderungen an Xampp selber vornehmen können sollen, werden auf den C:\Xampp Ordner eingeschränke Rechte gesetzt.
# Allerdings benötigen Apache, MySQL, PHP und PHPMyAdmin einige Ordner mit Schreibrechten. Um dieses Problem zu lösen, werden die entsprechenden Ordner
# mit der Methode Add-PublicDirectoryAndSymlink in einen für Benutzer schreibaren Ordner gesymlinkt. Damit die Benutzer die Ordnerstruktur dieses Public Ordners allerdings nicht löschen können
# werden entsprechende Windows File Permissions als SDDL (wer tut sich denn ACLs anders an in Windows Powershell?!) auf die Ordner gesetzt. 

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $xamppInstallationDirectory,

    [Parameter(Mandatory = $true, Position = 1)]
    [ValidatePattern("^[A-Z]$")]
    [string] $userWebDriveLetter
)

# Bei Fehlern sofort beenden
$ErrorActionPreference = "Stop"

function Set-SDDLToDirectory([string] $sddl, [string] $directory) {
    $securityDescriptor = Get-Acl -Path "$directory"
    $securityDescriptor.SetSecurityDescriptorSddlForm($sddl)
    Set-Acl "$directory" -AclObject $securityDescriptor
}

function Test-ReparsePoint([string]$path) {
    $file = Get-Item $path -Force -ea SilentlyContinue
    return [bool]($file.Attributes -band [IO.FileAttributes]::ReparsePoint)
}

function Add-PublicDirectoryAndSymlink([string] $link, [string] $target){
    $logger.info("Add public directory symlink: $link --> $target")

    # Authentifizierte Benutzer dürfen nur im Unterordner schreiben, aber nicht den Ordner selber löschen
    $xamppPublicSubdirectorySDDL = "O:BAG:DUD:PAI(A;OICI;0x1e01ff;;;AU)(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)(A;OICI;0x1200a9;;;BU)"

    New-Item "$target" -ItemType Directory
    Set-SDDLToDirectory "$xamppPublicSubdirectorySDDL" "$target"

    Add-Symlink "$link" "$target" $true
}

function Add-Symlink([string] $link, [string] $target, [bool] $verify) {
    # Link löschen, sofern es bereits existiert
    $logger.info("Create symlink: $link --> $target")

    if(Test-Path "$link") {
        if(Test-ReparsePoint "$link") {
            (Get-Item "$link").Delete()
        } else {
            Remove-Item -LiteralPath "$link" -Force -Recurse
        }
    }

    # Neuen Link erstellen
    if($verify) {
        New-Item -ItemType SymbolicLink -Path "$link" -Target "$target"
    } else {
        cmd.exe /c mklink /D "$link" "$target"
    }
}

function Add-PublicDirectoryRoot([string] $xamppPublicDirectory) {
    ## Xampp Public Ordner erstellen und Permissions setzen ##
    # Authentifizierte Benutzer dürfen in diesem Ordner nicht schreiben
    $xamppPublicSDDL = "O:BAG:DUD:PAI(A;OICI;0x1200a9;;;AU)(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)(A;OICI;0x1200a9;;;BU)"

    # Ordner löschen, wenn er bereits existiert
    if (Test-Path "$xamppPublicDirectory") {
        $logger.Warning("Xampp Public Directory - $xamppPublicDirectory - already exists. Deleting...")
        Remove-Item -LiteralPath "$xamppPublicDirectory" -Force -Recurse
    }

    # Xampp Public Ordner erstellen
    New-Item "$xamppPublicDirectory" -ItemType Directory
    Set-SDDLToDirectory "$xamppPublicSDDL" "$xamppPublicDirectory"
}

# Logger importieren
. $PSScriptRoot\Classes\Logger.ps1

# Logger initialisieren
[Logger] $logger = [Logger]::new()

# Prüfe, ob der Installationsordner existiert
$logger.Info("Check if installation directory $xamppInstallationDirectory exists")

if (-Not(Test-Path $xamppInstallationDirectory)) {
    $logger.Error("Cannot find xampp installation directory $xamppInstallationDirectory")
    exit 1
}

# Zugriffsrechte auf Installationsordner einschränken
$logger.Info("Set restricted ACLs to $xamppInstallationDirectory")
Set-SDDLToDirectory "O:BAG:DUD:PAI(A;OICI;0x1200a9;;;AU)(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)(A;OICI;0x1200a9;;;BU)" "$xamppInstallationDirectory"

# Public Ordner erstellen und 
$logger.Info("Create public directory and symlink temporary directories")
$xamppPublicDirectory = "C:\xampp-public"

Add-PublicDirectoryRoot "$xamppPublicDirectory"
Add-PublicDirectoryAndSymlink "$xamppInstallationDirectory\apache\logs" "$xamppPublicDirectory\apache-logs"
Add-PublicDirectoryAndSymlink "$xamppInstallationDirectory\phpmyadmin\tmp" "$xamppPublicDirectory\phpmyadmin-tmp"
Add-PublicDirectoryAndSymlink "$xamppInstallationDirectory\tmp" "$xamppPublicDirectory\tmp"

## User Web Ordner erstellen ##
# Apache htdocs symlinken
$logger.Info("Create symlink for htdocs to user share")
Add-Symlink "$xamppInstallationDirectory\htdocs" ($userWebDriveLetter + ":\htdocs") $false

# MySQL-Daten "wegkopieren", wenn Daten nicht bereits ein Symlink ist
$logger.Info("Copy MYSQL data to data-template")
$mysqlDataDirectory = "$xamppInstallationDirectory\mysql\data"
$mysqlDataTemplateDirectory = "$xamppInstallationDirectory\mysql\data-template"

# Prüfe, ob der Template Ordner bereits existiert
if(-Not(Test-Path $mysqlDataTemplateDirectory)) {
    if(-Not(Test-ReparsePoint $mysqlDataDirectory)) {
        Move-Item -Path $mysqlDataDirectory -Destination "$xamppInstallationDirectory\mysql\data-template"
    } else {
        $logger.Warning("Skip copy, because destination is already a symlink")
    }
} else {
    $logger.Warning("Skip copy, because $mysqlDataTemplateDirectory already exists")
}

# MySQL-Daten Ordner symlinken
$logger.InFo("Create symlink for mysql data to user share")
Add-Symlink "$xamppInstallationDirectory\mysql\data" ($userWebDriveLetter + ":\mysqldata") $false

# Batchdatei zum starten erstellen, um die ExecutionPolicy zu umgehen
$SimpleXamppControlStarterFile = "$xamppInstallationDirectory\SimpleXamppControl\SimpleXamppControl.bat"
New-Item "$SimpleXamppControlStarterFile" -Force 
Set-Content "$SimpleXamppControlStarterFile" "powershell.exe -ExecutionPolicy ByPass -File $xamppInstallationDirectory\SimpleXamppControl\SimpleXamppControl.ps1 $userWebDriveLetter"
