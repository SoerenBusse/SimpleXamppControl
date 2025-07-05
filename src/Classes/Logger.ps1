class Logger {
    hidden [void] Log([string]$level, [string]$message) {
        $color = switch ($level.ToUpper()) {
            "INFO"     { "Cyan" }
            "WARNING"  { "Yellow" }
            "ERROR"   { "Red" }
            default    { "White" }
        }

        Write-Host "[$level]" -ForegroundColor $color -NoNewline
        Write-Host " $message"
    }

    [void] Info([string]$message) {
        $this.Log("INFO", $message)
    }

    [void] Warning([string]$message) {
        $this.Log("WARNING", $message)
    }

    [void] Error([string]$message) {
        $this.Log("ERROR", $message)
    }
}