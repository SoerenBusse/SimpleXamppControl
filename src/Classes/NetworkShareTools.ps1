class NetworkShareTools {
    hidden [Logger] $logger
    hidden [char] $driveLetter

    NetworkShareTools([Logger] $logger, [char] $driveLetter) {
        $this.logger = $logger
        $this.driveLetter = $driveLetter
    }

    [string] GetDocumentsDirectoryAsNetworkPath() {
        $documentsDirectory = [System.Environment]::GetFolderPath("mydocuments")
        
        if($documentsDirectory.StartsWith("\\")) {
            return $documentsDirectory
        } elseif (-Not $documentsDirectory.StartsWith("C")) {
            # Der Dokumenteordner liegt nicht auf C. Windows stellt hier kein Network Share bereit. Fehler.
            throw "Cannot start Xampp, because Document Directory '$documentsDirectory' is not a network share nor on drive C"
        } else {
            # Wir haben ein lokalen Dokumenteordner. UNC Pfad für Lokalen Rechner erstellen
            $currentDrive = Split-Path -qualifier "$documentsDirectory"
            $documentsDirectory = $documentsDirectory.Replace($currentDrive, "\\localhost\C$")
        }

        return $documentsDirectory
    }

    [void] CreateNetworkDrive([string] $mountPath) {
        $this.logger.Info("Create Network Drive '$($this.driveLetter) to '$mountPath'")
        New-PSDrive -Name $this.driveLetter -Root "$mountPath" -Persist -Scope Global -PSProvider FileSystem
        
        $shellApplication = New-Object -ComObject shell.application
        $shellApplication.NameSpace("$($this.driveLetter):\").self.name = "Web"
    }

    [void] SetNetworkDriveLabel([string] $label) {
        $shellApplication = New-Object -ComObject shell.application
        $shellApplication.NameSpace("$($this.driveLetter):\").self.name = $label
    }

    [string] GetPathOfNetworkDrive() {
        $drive = Get-PSDrive -Name $this.driveLetter
        return $drive.DisplayRoot
    }

    [void] RemoveNetworkDriveIfExists() {
        # Wir versuchen erstmal die weiche Methode
        if($this.NetworkDriveExists()) {
            $this.logger.Info("Network drive '$($this.driveLetter)' will be removed")
            Get-PSDrive $this.driveLetter | Remove-PSDrive -Force
        }

        # Existiert das Laufwerk immer noch? Dann brauchen wir geballte Powershell v5.0 Magic
        if($this.NetworkDriveExists()) {
            $this.logger.Info("Network drive still exists. Trying to remove network drive '$($this.driveLetter)' using another method")
            Remove-SmbMapping -LocalPath ($this.driveLetter + ":") -Force
        }
    }

    [bool] NetworkDriveExists() {
        $networkDrivePath = $this.driveLetter + ":\"

        return Test-Path $networkDrivePath
    }
}