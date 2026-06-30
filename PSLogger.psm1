<#
MIT License

Copyright (c) 2026 Lakshay Chauhan

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Reference: <https://gitlab.com/ninthcircle/ps-logger/-/blob/master/PSLogger.psm1>
#>

enum LogLevel {
    ERROR
    WARN
    INFO
    DEBUG
    SUCCESS
}

$Colors = @{
    [LogLevel]::ERROR   = [ConsoleColor]::Red
    [LogLevel]::WARN    = [ConsoleColor]::Yellow
    [LogLevel]::INFO    = [ConsoleColor]::Blue
    [LogLevel]::DEBUG   = [ConsoleColor]::DarkGray
    [LogLevel]::SUCCESS = [ConsoleColor]::Green
}

$script:DebugEnabled = $false
$script:TimestampLoggingEnabled = $false

function Set-DebugLogging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [bool]$Enabled
    )
    $script:DebugEnabled = $Enabled
}

function Set-TimestampLogging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [bool]$Enabled
    )
    $script:TimestampLoggingEnabled = $Enabled
}

function Write-Log {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [LogLevel]$Level,
        [Parameter(Mandatory)]
        [string[]]$Message,
        [switch]$Time
    )

    if (-not $Message -or $Message.Count -eq 0) { return }

    $IndentSize = 0
    if ($Time -or $script:TimestampLoggingEnabled) {
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $IndentSize += "[$TimeStamp] ".Length
        Write-Host "[$TimeStamp] " -NoNewline
    }

    Write-Host "[" -NoNewline
    $LevelText = $Level.ToString().ToUpperInvariant()
    Write-Host $LevelText -ForegroundColor $Colors[$Level] -NoNewline
    Write-Host "] $($Message[0])"

    $IndentSize += "[$LevelText] ".Length
    if ($Message.Count -le 1) { return }
    foreach ($Line in $Message[1..($Message.Count - 1)]) {
        Write-Host "$(' ' * $IndentSize)$Line"
    }
}

function Write-ErrorLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string[]]$Message,
        [switch]$Exit,
        [switch]$Time
    )
    Write-Log -Level ([LogLevel]::ERROR) -Message $Message -Time:$Time
    if ($Exit) { exit 1 }
}

function Write-InfoLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string[]]$Message,
        [switch]$Time
    )
    Write-Log -Level ([LogLevel]::INFO) -Message $Message -Time:$Time
}

function Write-WarnLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string[]]$Message,
        [switch]$Time
    )
    Write-Log -Level ([LogLevel]::WARN) -Message $Message -Time:$Time
}

function Write-DebugLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string[]]$Message,
        [switch]$Time
    )
    if (-not $script:DebugEnabled) { return }
    Write-Log -Level ([LogLevel]::DEBUG) -Message $Message -Time:$Time
}

function Write-SuccessLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string[]]$Message,
        [switch]$Time
    )
    Write-Log -Level ([LogLevel]::SUCCESS) -Message $Message -Time:$Time
}

function Write-VisualSeparator {
    [CmdletBinding()]
    param(
        [LogLevel]$Level = ([LogLevel]::INFO),
        [switch]$Time
    )
    Write-Log -Level $Level -Message ("-" * 72) -Time:$Time
}

Export-ModuleMember -Function @(
    "Write-ErrorLog",
    "Write-InfoLog",
    "Write-WarnLog",
    "Write-DebugLog",
    "Write-SuccessLog",
    "Set-DebugLogging",
    "Set-TimestampLogging",
    "Write-VisualSeparator"
) -Variable * -Alias *
