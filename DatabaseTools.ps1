class DatabaseTools {
    hidden [string] $mysqlRootDirectory

    DatabaseTools([string] $mysqlRootDirectory) {
        $this.mysqlRootDirectory = $mysqlRootDirectory
    }

    [void] CopyTemplateDatabase([bool] $replaceContentIfExists) {
        $mysqlDataPath = $this.mysqlRootDirectory + "\data"
        $mysqlDataTemplatePath = $this.mysqlRootDirectory + "\data-template"
    
        # Existiert der Zielordner überhaupt
        $mysqlDataTarget = Get-Item $mysqlDataPath | Select-Object -ExpandProperty Target

        if(-Not(Test-Path "$mysqlDataTarget")) {
            throw "Das Ziel von $mysqlDataPath existiert nicht: $mysqlDataTarget"
        }

        # Existieren bereits Dateien im gesymlinkten MySQL Benutzerordner?
        if(Test-Path "$mysqlDataPath\*") {
            Write-Host "Der Ordner $mysqlDataPath enthält bereits Dateien. Content ersetzen: $replaceContentIfExists"
    
            if(-Not($replaceContentIfExists)) {
               # Dateien nicht kopieren und auch nicht löschen
               return
            }
    
            Write-Host "Lösche Inhalt aus \"$mysqlDataPath\""
            Remove-Item -Path "$mysqlDataPath\*" -Force -Recurse
    
            if(-not $?) {
                throw "Fehler beim Kopieren der Daten nach $mysqlDataPath"
            }
        }
    
        # Dateien aus dem Template in den Ordner kopieren
        Write-Host "Kopiere Daten von \"$mysqlDataTemplatePath\" nach \"$mysqlDataPath\""
        Copy-Item -Recurse "$mysqlDataTemplatePath/*" -Destination "$mysqlDataPath"
        Write-Host "Kopieren abgeschlossen"
    }
    [void] ResetDatabase() {
        try {
            $this.CopyTemplateDatabase($true)
        } catch {
            # TODO: Notwendig?
            throw "Fehler beim zurücksetzen: " + $_.Exception.Message
        }
    }


}