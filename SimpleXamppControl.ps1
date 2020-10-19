# WICHTIG!
# Diese Datei muss als UTF-8 BOM gespeichert werden!


# Native Libraries laden
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

# Eigene Klassen laden
. $PSScriptRoot\Classes\GUIManager.ps1
. $PSScriptRoot\Classes\DatabaseTools.ps1
. $PSScriptRoot\Classes\NetworkShareTools.ps1
. $PSScriptRoot\Classes\XamppTools.ps1

# Globale Variabeln definieren
$xamppRootDirectory = "C:\xampp"
$xamppPublicDirectory = "C:\xampp-public"
$userWebDriveLetter = $null

# Parameter parsen und validieren
if ($args.Count -lt 2) {
    Write-Host "Zu wenig Argumente. <Laufwerksbuchstabe für den BenutzerWebOrdner> <Bestehendes Laufwerk verwenden>"
    exit 1
}

if(-Not($args[0] -match "^[A-Z]$")) {
    Write-Host "Der Laufwerksbuchstabe" $args[0] "ist ungültig"
    exit 1
}

if(-Not($args[1] -match "true" -Or $args[1] -Match "false")) {
    Write-Host "Der Wert für bestehendes Laufwerk verwenden ist ungültig. Muss true/false sein. Ist:" $args[1]
    exit 1
}

$userWebDriveLetter = $args[0]
[bool] $useExistingDriveLetter = If ($args[1] -Match "true") { $true } Else { $false }

# Alle Fehler abfangen und dem User zeigen
try {
    # Klassen instanzieren
    [GuiManager ] $guiManager = [GUIManager]::new(500, 210)
    [NetworkShareTools] $networkShareTools = [NetworkShareTools]::new($userWebDriveLetter)
    [DatabaseTools] $databaseTools = [DatabaseTools]::new($xamppRootDirectory + "\mysql")
    [XamppTools] $xamppTools = [XamppTools]::new($xamppRootDirectory, $xamppPublicDirectory, $useExistingDriveLetter, $databaseTools, $networkShareTools)

    # Gui erstellen
    $guiManager.CreateLabel("Xampp Steuerung", 5, 5, 475, 40, 20)
    $guiManager.CreateButton("Xampp beenden", 5, 70, 475, 40, 
        {
            $guiManager.Close()
        }.GetNewClosure()
    )

    $guiManager.CreateButton("Datenbank resetten", 5, 120, 475, 40, 
        {
            # Nachfrage, ob die Datenbank wirklich resettet werden soll?
            [DialogResult] $result = [MessageBox]::Show("Datenbank wirklich resetten? Sämtliche Daten in der Datenbank werden gelöscht und Xampp wird gestoppt!", "Fortfahren?", "YesNo", "Warning", "Button1")
        
            if($result -ne [DialogResult]::Yes) {
                return
            }
            
            $xamppTools.StopXampp()
            $databaseTools.ResetDatabase()
            $xamppTools.StartXampp()

            [MessageBox]::Show("Zurücksetzen erfolgreich.")
        }
    )

    $guiManager.AddCloseEvent(
        {
            # Das Programm soll beendet werden. Xampp stoppen und Netzwerklaufwerk unmounten
            $xamppTools.StopXampp()
            $xamppTools.RemoveNetworkDriveIfRequired()
            $xamppTools.CleanPublicDirecotry()
        }.GetNewClosure()
    )

    # Xampp starten
    $xamppTools.StartXampp()

    $guiManager.Show()
} catch {
    Write-Host "Ein nicht behandelter Fehler ist aufgetreten:" $_.Exception.Message

    # Messagebox dem User anzeigen
    [MessageBox]::Show("Ein Fehler ist aufgetreten: " + $_.Exception.Message + ". Das Programm wird beendet", "Fataler Fehler", "OK", "Error")
    # Wir versuchen zumindest noch das Netzwerklaufwerk zu unmounten
    $xamppTools.RemoveNetworkDriveIfRequired()
    $xamppTools.CleanPublicDirecotry()
    exit 1
}
