[CmdletBinding()]
param()

Import-Module "$PSScriptRoot\PSLogger.psm1" -Force
Import-Module "$PSScriptRoot\Config.psm1" -Force

$BuildPath = Join-Path $PSScriptRoot $BuildDirectory
$CheckstyleJar = Join-Path $PSScriptRoot "resources\checkstyle-12.3.0-all.jar"

function Initialize-CheckstyleCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ClassName
    )

    $SourceFile = Join-Path $PSScriptRoot "src\main\java\fun\ninth\$ClassName.java"

    & javac `
        -cp $CheckstyleJar `
        -d $BuildPath `
        $SourceFile

    if ($LASTEXITCODE) {
        Write-ErrorLog -Message "Failed to compile '$ClassName.java'."
    }

    Write-InfoLog -Message "Compiled 'src\main\java\fun\ninth\$ClassName.java'."
}

New-Item -ItemType Directory -Path $BuildPath -Force | Out-Null
Write-InfoLog -Message "Created '$BuildPath'."

@(
    "MethodInventoryCheck"
    "RestApiInventoryCheck"
) | ForEach-Object {
    Initialize-CheckstyleCheck -ClassName $_
}

$JarFile = Join-Path $BuildPath "$ChecksJarFileName"
$ResourcesPath = Join-Path $PSScriptRoot "resources"

& jar `
    cf $JarFile `
    -C $BuildPath "fun\ninth" `
    -C $ResourcesPath "checkstyle_packages.xml"

if ($LASTEXITCODE) {
    Write-ErrorLog -Message "Failed to generate '$JarFile'."
}

Write-InfoLog -Message "Generated '$JarFile'."