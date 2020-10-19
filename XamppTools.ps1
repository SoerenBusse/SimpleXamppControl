class XamppTools {
    [string] $xamppRootDirectory
    [string] $xamppPublicDirectory
    [bool] $useExistingDriveLetter
    
    [DatabaseTools] $databaseTools
    [NetworkShareTools] $networkShareTools

    hidden $apacheProcess = $null
    hidden $mysqlProcess = $null

    XamppTools([string] $xamppRootDirectory, [string] $xamppPublicDirectory, [bool] $useExistingDriveLetter, [DatabaseTools] $databaseTools, [NetworkShareTools] $networkShareTools) {
        $this.xamppRootDirectory = $xamppRootDirectory
        $this.xamppPublicDirectory = $xamppPublicDirectory
        $this.databaseTools = $databaseTools
        $this.networkShareTools = $networkShareTools
        $this.useExistingDriveLetter = $useExistingDriveLetter
    }

    [void] StartXampp() {
        # Netzwerklaufwerk verbinden
        Write-Host "Netzwerklaufwerk wird verbunden"
       
        # Das übergeordnete Verzeichnis, das gemountet wird, sodass die Dateien unter Drive:\Web\{htdocs,mysqldata} zur Verfügung stehen
        [string] $mountableDirectory = $null

        # Soll ein bestehendes Netzwerklaufwerk verwendet werden? Ansonsten den Dokumenteordner des Benutzers wählen
        [string] $webDirectory = $null
        if($this.useExistingDriveLetter) {
            # Prüfen ob das Laufwerk überhaupt gemountet wurde
            $networkDrivePath = $this.networkShareTools.GetDriveLetter() + ":"

            if(-Not(Test-Path $networkDrivePath)) {
                throw "Das Netzwerklaufwerk " + $networkDrivePath + " existiert nicht auf diesem Computer. Es soll aber kein neues Laufwerk angelegt werden. Bitte die OPSI Einstellungen prüfen. Xampp kann nicht gestartet werden"
            }
            [string] $webDirectory = $networkDrivePath + ":\Web"
        } else {
            [string] $mountableDirectory = $this.networkShareTools.GetDocumentsDirectoryAsNetworkPath()
            [string] $webDirectory = $mountableDirectory + "\Web"
        }
        
        try {
            Write-Host "Ordnerstruktur für Xampp im Ordner \"$webDirectory\" anlegen"

            # Prüfen, ob der WebOrdner existiert, ansonsten erstellen
            if(-Not(Test-Path "$webDirectory")) {
                New-Item -Path "$webDirectory" -ItemType "directory"
            }
        
            # Prüfen, ob der htdocs Ordner existiert, ansonsten erstellen
            if(-Not(Test-Path "$webDirectory\htdocs")) {
                New-Item -Path "$webDirectory\htdocs" -ItemType "directory"
            }
        
            # Prüfen, ob der mysqldata Ordner existiert, ansonsten erstellen
            if(-Not(Test-Path "$webDirectory\mysqldata")) {
                New-Item -Path "$webDirectory\mysqldata" -ItemType "directory"
            }
        
            # Netzwerklaufwerk neu erstellen
            if(!$this.useExistingDriveLetter) {
                Write-Host "$mountableDirectory wird als Netzwerklaufwerk" $this.networkShareTools.GetDriveLetter() "gemountet"
                $this.networkShareTools.RemoveNetworkDriveIfExists()
                $this.networkShareTools.CreateNetworkDrive("$mountableDirectory")
            } else {
                Write-Host "Es wird das bestehende Netzwerklaufwerk" $this.useExistingDriveLetter "verwendet. Überspringe Netzwerklaufwerk verbinden..."
            }

            # Datenbankdateien werden kopiert, falls der Ordner im Benutzerordner leer ist
            Write-Host "Mysql Daten werden kopiert"
            $this.databaseTools.CopyTemplateDatabase($false)
        
            Write-Host "Xampp starten"
            $this.apacheProcess = Start-Process ($this.xamppRootDirectory + "\apache_start.bat") -PassThru
            $this.mysqlProcess = Start-Process ($this.xamppRootDirectory +"\mysql_start.bat") -PassThru
        } catch {
            throw "Fehler beim starten von Xampp: " + $_.Exception.Message
        }
    }

    [void] StopXampp() {
        # Xampp Stop-Skripte ausführen
        & ($this.xamppRootDirectory + "\apache_stop.bat")
        & ($this.xamppRootDirectory + "\mysql_stop.bat")

        # Versuchen die Fenster zu schließen
        if($this.apacheProcess) {
            Stop-Process $this.apacheProcess -Force
        }

        if($this.mysqlProcess) {
            Stop-Process $this.mysqlProcess -Force   
        }
    }

    [void] RemoveNetworkDriveIfRequired() {
        # Das Laufwerk nur entfernen, wenn kein bestehendes Laufwerk verwendet wird
        if(!$this.useExistingDriveLetter) {
            $this.networkShareTools.RemoveNetworkDriveIfExists()
        }
    }

    [void] CleanPublicDirecotry() {
        Remove-Item ($this.xamppPublicDirectory + "\apache-logs\*")
        Remove-Item ($this.xamppPublicDirectory + "\phpmyadmin-tmp\*")
        Remove-Item ($this.xamppPublicDirectory + "\tmp\*")
    }
}