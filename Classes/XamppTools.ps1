class XamppTools {
    hidden [Logger] $logger
    hidden [string] $xamppRoot
    hidden [string] $xamppPublicRoot

    hidden [string] $xamppMysqlDataDirectory
    hidden [string] $xamppMysqlDataTemplateDirectory

    XamppTools([Logger] $logger, [string] $xamppRoot, [string] $xamppPublicRoot) {
        $this.logger = $logger
        $this.xamppRoot = $xamppRoot
        $this.xamppPublicRoot = $xamppPublicRoot

        $this.xamppMysqlDataTemplateDirectory = Join-Path -Path $xamppRoot -ChildPath "mysql\data-template"
    }

    [void] CopyDatabaseTemplate($userMysqlDataDirectory, $replaceContentIfExists) {
        if(-Not(Test-Path $userMysqlDataDirectory)) {
            throw "Directory $($userMysqlDataDirectory) does not exist"
        }

        # Wenn bereits Dateien existieren und diese nicht überschrieben werden sollen, überspringen wir
        if ((Test-Path "$($userMysqlDataDirectory)/*") -And -Not $replaceContentIfExists ) {
            $this.logger.Info("Use existing database directory")
            return
        }

        # Dateien löschen
        $this.logger.Info("Delete database files")
        Remove-Item -Path "$($userMysqlDataDirectory)\*" -Force -Recurse

        # Dateien aus Template in den User Dataordner kopieren
        $this.logger.Info("Copy template database files to user directory...")
        Copy-Item -Recurse "$($this.xamppMysqlDataTemplateDirectory)\*" -Destination $userMysqlDataDirectory
        $this.logger.Info("Copy successfully completed")
    }
}