using namespace System.Windows.Forms
using namespace System.Drawing

class GUIManager {

    [Form] $window

    GUIManager([int] $sizeX, [int] $sizeY) {
        $this.window = [Form]::new()
        $this.window.StartPosition = "CenterScreen"
        $this.window.Size = [Size]::new($sizeX, $sizeY)
        $this.window.FormBorderStyle = "FixedDialog"
        $this.window.MaximizeBox = $false;
    }

    CreateButton([string] $text, [int] $locationX, [int] $locationY, [int] $sizeX, [int] $sizeY, [scriptblock] $callback) {
        $button = [Button]::new()
        $button.Location = [Size]::new($locationX, $locationY)
        $button.Size = [Size]::new($sizeX, $sizeY)
        $button.Text = $text
        
        $button.Add_Click($callback)
        $this.window.Controls.Add($button)
    }

    CreateLabel([string] $text, [int] $locationX, [int] $locationY, [int] $sizeX, [int] $sizeY, [int] $fontSize) {
        $label = [Label]::new()
        $label.Location = [Size]::new($locationX, $locationY)
        $label.Size = [Size]::new($sizeX, $sizeY)
        $label.Text = $text
        $label.Font = [Font]::new("Arial", $fontSize)
        $label.TextAlign = "MiddleCenter"

        $this.window.Controls.Add($label)
    }

    Show() {
        $this.window.ShowDialog()
    }

    Close() {
        $this.window.Close()
    }

    AddCloseEvent([scriptblock] $callback) {
        $this.window.Add_Closing($callback)
    }
}