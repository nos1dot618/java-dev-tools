[CmdletBinding()]
param()

git submodule update --init --recursive

$Module = "PSLogger"

if (-not (Get-Module -ListAvailable -Name $Module)) {
    $ArchiveUri = "https://gitlab.com/ninthcircle/PSLogger/-/archive/master/PSLogger-master.zip"
    $Path = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "PowerShell\Modules\$Module"

    Invoke-WebRequest -Uri $ArchiveUri -OutFile "$env:TEMP\$Module.zip"
    Expand-Archive -Path "$env:TEMP\$Module.zip" -DestinationPath "$env:TEMP\$Module" -Force

    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Copy-Item "$env:TEMP\$Module\PSLogger-master\*" $Path -Recurse -Force
}
