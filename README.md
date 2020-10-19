# Simple Xampp Control
Dieses Tool wurde entwickelt um Xampp in einer Active Directory Domänen Umgebung ohne Administratorechte starten zu können und gleichzeitig den Zugriff auf die Xampp Installationsdateien in `C:\xampp` einzuschränken, sodass nicht jeder Nutzer hier beliebige Dateien ablegt oder Einstellungen modifiziert.

Aus diesem Grund ist "Simple Xampp Control" für Lernumgebungen geeignet, in denen die Lernenden mit einer vorhandenen Umgebung den Umgang mit PHP und/oder SQL mit der Datenbank MySQL lernen sollen.
Nicht vom Administrator eingestellte Änderungen am Xampp-Server werden nicht unterstützt bzw. sind nicht möglich.

**Es wird ausschließlich Xampp in der minimal Installation mit Apache und MySQL unterstützt!**

## Problem
Standardmäßig installiert Xampp sämtliche Dateien in den `C:\xampp` Ordner.
Dies betrifft ebenfalls den `htdocs` Ordner sowie den Datenordner für die MySQL Installation.
Benutzer sollen ausschließlich auf diese Ordner Schreibrechte haben und ihre eigenen Dateien sehen.
Dieses Einschränken bringt allerdings ein paar Probleme mit sich, da so die Benutzer keine Schreibrechte mehr haben (Keine Schreibrechte auf eigene Webdateien, keine Schreibrechte für Apache auf den temporären Ordner in C:\xampp\tmp...)

## Lösung
Symlinks, Netzwerklaufwerke und noch mehr Symlinks :).
Was im ersten moment eher ungewöhnlich und hässlich wirkt erweist sich doch als eine saubere Lösung für diese Problemstellung.

### prepareXampp.ps1
Das Skript erstellt die Ordnerstruktur für Xampp, schränkt diese ein und erstellt entsprechende Symlinks

**Dieses Skript muss mit Administratorenrechten gestartet werden.**

#### Ausführen
`.\PrepareXampp.ps1 <Der in Symlinks zu nutzende Laufwerksbuchstabe - z.B. W (ohne Doppelpunkt und Pfad)> <Vorhanden Laufwerksbuchstaben für Startskript nutzen, siehe #SimpleXamppControl.ps1 in README>`

#### ACLs
Mittels vordefinierten SDDLs ACLs werden die Rechte auf dem Ordner `C:\xampp` so eingeschränkt, das ausschließlich Administratoren (inkl. Domänen Administratoren) Schreibzugriff haben.
Alle anderen Benutzer dürfen ausschließlich lesen.

Für temporäre Dateien von Apache und MySQL wird eine Ordnerstruktur in `C:\xampp-public` angelegt, die von den Benutzern allerdings **nicht** ohne Administratorrechte geändert werden kann.
Auf den Inhalt der Ordner haben die Benutzer dagegen Schreibrechte.

#### Symlinks
Zunächst wird der Ordner `mysql\data` in `mysql\data-template` umbenannt, sodass vom `data` Ordner im weiteren Verlauf ein Symlink erstellt werden kann und so die von Xampp mitgelieferte Datenbank, im folgenden Template genannt, nicht verloren geht.
Die für die Benutzer beschreibaren Ordner (`htdocs` und `mysql\data`) werden auf ein Netzwerklaufwerk gelinkt.
Gleichzeitig wird für die erforderlichen temporären Ordner ein Symlink nach `C:\xampp-public` erstellt

Konkret entsteht folgende Symlink Situation
```
C:\xampp\htdocs ==> Laufwerksbuchstabe:\Web\htdocs
C:\xampp\mysql\data ==> Laufwerksbuchstabe:\Web\mysqldata
C:\xampp\tmp ==> C:\xampp-public\tmp
C:\xampp\apache\logs ==> C:\xampp-public\apache-logs
C:\xampp\phpmyadmin\tmp ==> C:\xampp-public\phpmyadmin-tmp
```

#### Netzwerklaufwerke
Da ausschließlich Administratoren auf C:\xampp Zugriff haben, können Benutzer das Ziel der Symlinks von `htdocs` sowie `mysql/data` zur Laufzeit nicht auf ihren eigenen Benutzerordner ändern.
Diese Limitierung wird durch das erstellen von Symlinks auf Netzwerklaufwerke begenet, da ein Ziel eines Symlinks beim Anlegen noch nicht existieren muss.

Das `PrepareXampp.ps1` Skript erstellt also ein Symlink auf das angegebene Netzwerklaufwerk nach `Laufwerksbuchstabe:\Web\htdocs` bzw. `Laufwerksbuchstabe:\Web\mysqldata`.
Mit Benutzerrechten kann später z.B. das Dokumentenverzeichnis auf den Laufwerksbuchstaben gemountet werden.

Somit erhält man beispielsweise folgende Konstellation:

Der Benutzer kann in `C:\xampp\htdocs` Dateien anlegen und sie werden im eigenen Benutzerordner unter `\\localhost\C$\Users\Benutzer\Documents\Web\htdocs` gespeichert.
```
C:\xampp\htdocs == Symlink ==> W:\Web\htdocs == W gemountet nach ==> \\localhost\C$\Users\Benutzer\Documents\
```

#### Ergebnis
Der Benutzer erhält Zugriff auf einen individuellen `C:\xampp\htdocs` sowie `C:\xampp\mysql\data` Ordner während der andere Teil des `C:\xampp` Ordners nicht beschreibar ist.

### SimpleXamppControl.ps1
Das PrepareXampp.ps1 Skript sorgt dafür, das das Netzwerklaufwerk gemountet wird, die MySQL Datenbank aus dem Template Ordner in den Benutzerordner kopiert und Apache und MySQL im Anschluss gestartet wird.
Es stellt eine kleine und zugegebenerweise hässliche GUI zur Verfügung, die es ermöglicht Xampp sauber wieder zu beenden und die Datenbank zurück zu setzen.

#### Ausführen
`.\SimpleXamppControl.ps1 <Laufwerksbuchstabe, der auch im prepare Skript genutzt wurde> <true/false: Soll ein vorhandenes Netzwerklaufwerk genutzt werden>`

Wird als zweiter Parameter `false` angegeben, so versucht das Skript standardmäßig den Dokumentenordner des Benutzers ausfindig zu machen und unter dem angegebenen Laufwerksbuchstabe zu mounten. Es werden dabei zwei Fälle unterschieden:
| Typ  | Ziel des Netzwerklaufwerks  |
|---|---|
| Lokaler Dokumenten Ordner | \\localhost\C$\Users\<Benutzername>\Documents  |
| Folder Redirection | \\<Pfad zum umgeleiteten Documents Ordner>  |

Für ersteren Fall muss ein Zugriff auf das `C` Laufwerk über `\\localhost\C$` möglich sein

Ist der zweite Parameter `true` so wird kein Mountversuch unternommen und das Skript geht davon aus, das unter dem angegeben Laufwerksbuchstaben bereits ein Netzwerklaufwerk existiert, welches zum Beispiel über GPOs erstellt wurde.

In beiden Fälle erstellt das Skript im Root-Verzeichnis des Laufwerksbuchstaben folgende Ordnerstruktur:
```
W:
├───Web
│   ├───htdocs
│   └───mysqldata
```

#### Datenbank resetten
Wird auf den Datenbank resetten Knopf gedrückt, wird der Inhalt aus `Laufwerksbuchstabe:\Web\mysqldata` gelöscht und das Template erneut in diesen Ordner kopiert.
Somit erhält der Benutzer eine saubere und neue Datenbank.

#### Xampp beenden
Im Fehlerfalle oder beim klicken auf den "Xampp beenden" Knopf werden Apache und MySQL ordnungsgemäß gestoppt und im Anschluss das Netzwerklaufwerk wieder entfernt.

