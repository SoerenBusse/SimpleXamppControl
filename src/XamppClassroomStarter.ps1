# Kleinere Funktionen wurden unter Hilfe von KI entwickelt
# Der Großteil ist allerdings selbst geschrieben

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("start", "reset-database")]
    [string] $Action,

    [Parameter(Mandatory = $true)]
    [ValidatePattern("^[A-Z]$")]
    [string] $NetworkDriveLetter
)


function PromptUserYesNo {
    param (
        [string]$Question
    )

   while ($true) {
        $response = Read-Host $Question
        switch ($response.ToLower()) {
            "yes" { return $true }
            "no" { return $false }
            default { Write-Host "Enter <yes> or <no>" }
        }
    }
}

function WaitForKeyPress {
    param (
        [string]$Message
    )
    Write-Host $Message
    [void][System.Console]::ReadKey($true)
}

function StartXamppControl() {
    # Kopiere Datenbank Template ohne Dateien zu ersetzen
    $logger.info("Copy database templates to user directory")
    $xamppTools.CopyDatabaseTemplate($userMysqlDataDirectory, $false)

    # Starte das Xampp-Control Panel
    $logger.info("Starte Xampp Control Panel")
    Start-Process "$xamppDirectory\xampp-control.exe"
}

function ResetDatabase() {
    $logger.Info("Starting database reset application...")

    # Prüfe, ob MYSQL aktuell läuft
    $process = Get-Process -Name $mysqldProcessName -ErrorAction SilentlyContinue
    if($process) {
        $logger.Error("MYSQL is currently running. Use the XAMPP control panel to stop mysql and try again")
        WaitForKeyPress -Message "Press any key to stop programm..."
        exit 1
    }

    $promptResult = PromptUserYesNo -Question "Do you really want to reset the database? All data will be lost! Type <yes> or <no> and press <ENTER>"

    if (-Not $promptResult) {
        $logger.Info("The database will remain unchanged")
        WaitForKeyPress -Message "Press any key to stop programm..."
        exit 0
    }

    # Datenbank resetten
    $logger.info("Start resetting database...")
    $xamppTools.CopyDatabaseTemplate($userMysqlDataDirectory, $true)
}

$ErrorActionPreference = "Stop"

. $PSScriptRoot\Classes\Logger.ps1
. $PSScriptRoot\Classes\NetworkShareTools.ps1
. $PSScriptRoot\Classes\XamppTools.ps1

# Logger initialisieren
$xamppDirectory = "C:\xampp"
$xamppPublicDirectory = "C:\xampp-public"
$mysqldProcessName = "mysqld"

[Logger] $logger = [Logger]::new()
[NetworkShareTools] $networkShareTools = [NetworkShareTools]::new($logger, $NetworkDriveLetter)
[XamppTools] $xamppTools = [XamppTools]::new($logger, $xamppDirectory, $xamppPublicDirectory)

try {
    # UNC-Path erstellen
    [string] $uncMountableDirectory = $networkShareTools.GetDocumentsDirectoryAsNetworkPath()
    [string] $uncWebDirectory = $uncMountableDirectory + "\Web"

    [string] $userHtdocsDirectory = $uncWebDirectory + "\htdocs"
    [string] $userMysqlDataDirectory = $uncWebDirectory + "\mysqldata"

        $logger.Info("Prepare runtime environment")

    # Wir nutzen immer den UNC-Path zum Anlegen der Ordnerstruktur
    $logger.Info("Create XAMPP directory structure in '$uncWebDirectory'")

    # Prüfen, ob der WebOrdner existiert, ansonsten erstellen
    if(-Not(Test-Path "$uncWebDirectory")) {
        New-Item -Path "$uncWebDirectory" -ItemType "directory" | Out-Null
    }

    # Prüfen, ob der htdocs Ordner existiert, ansonsten erstellen
    if(-Not(Test-Path "$userHtdocsDirectory")) {
        New-Item -Path "$userHtdocsDirectory" -ItemType "directory" | Out-Null
    }

    # Prüfen, ob der mysqldata Ordner existiert, ansonsten erstellen
    if(-Not(Test-Path "$userMysqlDataDirectory")) {
        New-Item -Path "$userMysqlDataDirectory" -ItemType "directory" | Out-Null
    }
    
    # Laufwerk mounten, wenn es noch nicht erstellt wurde
    if(-Not($networkShareTools.NetworkDriveExists())) {
        $networkShareTools.CreateNetworkDrive($uncWebDirectory)
    } else {
        $logger.Info("Using existing network drive $NetworkDriveLetter")
    }

    # Ist der UNC-Pfad des Netzwerkshares korrekt? Sonst mounten wir den neu
    $currentNetworkDriveRemotePath = $networkShareTools.GetPathOfNetworkDrive()
    if($currentNetworkDriveRemotePath -ne $uncWebDirectory) {
        $logger.Warning("Network Drive $NetworkDriveLetter currently points to $currentNetworkDriveRemotePath but must point to $uncWebDirectory")
        $logger.Warning("Reattaching network drive with correct path to fix this inconsistency")

        $networkShareTools.RemoveNetworkDriveIfExists()
        $networkShareTools.CreateNetworkDrive($uncWebDirectory)
    }

    # Label aktualisieren
    $logger.Info("Set correct network drive label")
    $networkShareTools.SetNetworkDriveLabel("Web")

    switch ($Action) {
        "start" {
            StartXamppControl
        }
        "reset-database" {
            ResetDatabase
        }
    }
} catch {
    # https://stackoverflow.com/questions/38419325/catching-full-exception-message
    $formatstring = "{0} : {1}`n{2}`n" +
                "    + CategoryInfo          : {3}`n" +
                "    + FullyQualifiedErrorId : {4}`n"

    $fields = $_.InvocationInfo.MyCommand.Name,
            $_.ErrorDetails.Message,
            $_.InvocationInfo.PositionMessage,
            $_.CategoryInfo.ToString(),
            $_.FullyQualifiedErrorId

    $logger.Error("An unexpected error occoured: $($formatstring -f $fields)")
    WaitForKeyPress -Message "Press any key to stop programm..."
    exit 1
}