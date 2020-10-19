class NetworkShareTools {
    hidden [char] $driveLetter

    NetworkShareTools([char] $driveLetter) {
        $this.driveLetter = $driveLetter
    }

    [string] GetDocumentsDirectoryAsNetworkPath() {
        $documentsDirectory = [System.Environment]::GetFolderPath("mydocuments")
        
        if($documentsDirectory.StartsWith("\\")) {
            return $documentsDirectory
        } elseif (-Not $documentsDirectory.StartsWith("C")) {
            # Der Dokumenteordner liegt nicht auf C. Windows stellt hier kein Network Share bereit. Fehler.
            throw "Xampp kann nicht gestartet werden, da der Dokumenteordner nicht auf C oder einem Netzwerkpfad liegt."
        } else {
            # Wir haben ein lokalen Dokumenteordner. UNC Pfad für Lokalen Rechner erstellen
            $currentDrive = Split-Path -qualifier "$documentsDirectory"
            $documentsDirectory = $documentsDirectory.Replace($currentDrive, "\\localhost\C$")
        }

        return $documentsDirectory
    }

    [void] CreateNetworkDrive([string] $mountPath) {
        Write-Host "Create Drive"
        New-PSDrive -Name $this.driveLetter -Root "$mountPath" -Persist -Scope Global -PSProvider FileSystem
    }

    [void] RemoveNetworkDriveIfExists() {
        $driveLetterPath = $this.driveLetter + ":\"

        # Wir versuchen erstmal die weiche Methode
        if(Test-Path $driveLetterPath) {
            Write-Host "Bestehendes Netzwerklaufwerk wird gelöscht"
            Get-PSDrive $this.driveLetter | Remove-PSDrive -Force
        }

        # Existiert das Laufwerk immer noch? Dann brauchen wir geballte Powershell v5.0 Magic
        if(Test-Path $driveLetterPath) {
            Write-Host "Windows ist hartnäckig und löscht das Netzwerklaufwerk nicht. Wir versuchen es erneut mit einer anderen Methode"
            Remove-SmbMapping -LocalPath ($this.driveLetter + ":") -Force
        }
    }

    [char] GetDriveLetter() {
        return $this.driveLetter
    }
}