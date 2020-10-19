# Erklärung des Skript:
# Da die Benutzer keine Änderungen an Xampp selber vornehmen können sollen, werden auf den C:\Xampp Ordner eingeschränke Rechte gesetzt.
# Allerdings benötigen Apache, MySQL, PHP und PHPMyAdmin einige Ordner mit Schreibrechten. Um dieses Problem zu lösen, werden die entsprechenden Ordner
# mit der Methode Add-PublicDirectoryAndSymlink in einen für Benutzer schreibaren Ordner gesymlinkt. Damit die Benutzer die Ordnerstruktur dieses Public Ordners allerdings nicht löschen können
# werden entsprechende Windows File Permissions als SDDL (wer tut sich denn ACLs anders an in Windows Powershell?!) auf die Ordner gesetzt. 

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
    Write-Host $target
    # Authentifizierte Benutzer dürfen nur im Unterordner schreiben, aber nicht den Ordner selber löschen
    $xamppPublicSubdirectorySDDL = "O:BAG:DUD:PAI(A;OICI;0x1e01ff;;;AU)(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)(A;OICI;0x1200a9;;;BU)"

    New-Item "$target" -ItemType Directory
    Set-SDDLToDirectory "$xamppPublicSubdirectorySDDL" "$target"

    Add-Symlink "$link" "$target" $true
}

function Add-Symlink([string] $link, [string] $target, [bool] $verify) {
    # Link löschen, sofern es bereits existiert
    Write-Host $link
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
        Write-Host "Xampp Public Directory - $xamppPublicDirectory - existiert bereits. Lösche..."
        Remove-Item -LiteralPath "$xamppPublicDirectory" -Force -Recurse
    }

    # Xampp Public Ordner erstellen
    New-Item "$xamppPublicDirectory" -ItemType Directory
    Set-SDDLToDirectory "$xamppPublicSDDL" "$xamppPublicDirectory"
}


# Argumente prüfen
if ($args.Count -lt 2) {
    Write-Host "Zu wenig Argumente. <Laufwerksbuchstabe des Benutzers> <Vorhanden Laufwerksbuchstaben für Startskript nutzen>"
    exit 1
}

if(-Not($args[0] -match "^[A-Z]$")) {
    Write-Host "Der Laufwerksbuchstabe" $args[0] "ist ungültig"
    exit 1
}

if(-Not($args[1] -match "true" -Or $args[1] -Match "false")) {
    Write-Host "Der Wert, ob ein das Startskript ein vorhandenes Laufwerk nutzt muss true/false sein. Ist:" $args[1]
    exit 1
}

$useExistingDriveLetter = If ($args[1] -Match "true") { $true } Else { $false }

## Variabeln definieren ##
# Installationsordner aus Argumente parsen
$installDirectory = "C:\xampp"
$userWebDriveLetter = $args[0]

# Zugriffsrechte auf C:\xampp einschränken
Set-SDDLToDirectory "O:BAG:DUD:PAI(A;OICI;0x1200a9;;;AU)(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)(A;OICI;0x1200a9;;;BU)" "$installDirectory"

# Public Ordner erstellen und 
$xamppPublicDirectory = "C:\xampp-public"

Add-PublicDirectoryRoot "$xamppPublicDirectory"
Add-PublicDirectoryAndSymlink "$installDirectory\apache\logs" "$xamppPublicDirectory\apache-logs"
Add-PublicDirectoryAndSymlink "$installDirectory\phpmyadmin\tmp" "$xamppPublicDirectory\phpmyadmin-tmp"
Add-PublicDirectoryAndSymlink "$installDirectory\tmp" "$xamppPublicDirectory\tmp"

## User Web Ordner erstellen ##
# Apache htdocs symlinken
Add-Symlink "$installDirectory\htdocs" ($userWebDriveLetter + ":\Web\htdocs") $false

# MySQL-Daten "wegkopieren", wenn Daten nicht bereits ein Symlink ist
$mysqlDataDirectory = "$installDirectory\mysql\data"
if(-Not(Test-ReparsePoint $mysqlDataDirectory)) {
    Move-Item -Path $mysqlDataDirectory -Destination "$installDirectory\mysql\data-template"
}

# MySQL-Daten Ordner symlinken
Add-Symlink "$installDirectory\mysql\data" ($userWebDriveLetter + ":\Web\mysqldata") $false

# Batchdatei zum starten erstellen, um die ExecutionPolicy zu umgehen
$SimpleXamppControlStarterFile = "$installDirectory\SimpleXamppControl\SimpleXamppControl.bat"
New-Item "$SimpleXamppControlStarterFile" -Force 
Set-Content "$SimpleXamppControlStarterFile" "powershell.exe -ExecutionPolicy ByPass -File $installDirectory\SimpleXamppControl\SimpleXamppControl.ps1 $userWebDriveLetter $useExistingDriveLetter"
