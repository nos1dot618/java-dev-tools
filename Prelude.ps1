<#
.SYNOPSIS
Compiles a custom Checkstyle check.

.DESCRIPTION
Compiles a Java class implementing a custom Checkstyle check into the module's
build directory. The resulting class files are later packaged into the
compiled checks JAR by Invoke-JavaInventory.

.PARAMETER ClassName
The name of the Java class (without the .java extension) to compile.

.NOTES
This is an internal helper function and is not intended to be called directly.
#>
function Initialize-CheckstyleCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ClassName
    )

    $SourceFile = Join-Path $PSScriptRoot "src\main\java\fun\ninth\$ClassName.java"

    if (-not (Test-Path -LiteralPath $script:CheckstyleJarPath)) {
        Write-ErrorLog -Message "Checkstyle JAR '$script:CheckstyleJarPath' not found." -Throw
    }

    & javac `
        -cp $script:CheckstyleJarPath `
        -d $script:BuildPath `
        $SourceFile

    if ($LASTEXITCODE -ne 0) {
        Write-ErrorLog -Message "Failed to compile '$SourceFile'." -Throw
    }
    Write-InfoLog -Message "Compiled '$SourceFile'."
}

<#
.SYNOPSIS
Runs custom Checkstyle-based Java development tools.

.DESCRIPTION
Compiles the bundled custom Checkstyle checks, packages them into a JAR, and
executes Checkstyle using one of the supported analysis configurations against
a Java source tree.

The cmdlet currently supports:

- Method inventory generation
- REST API inventory generation

.PARAMETER Category
Specifies the inventory category to generate.

Supported values are:
- Method
- RestApi

.PARAMETER SourcePath
Path to the root directory containing the Java source files to analyze.

.PARAMETER OutputFile
Optional path to a file that receives the Checkstyle output. If omitted,
results are written to the console.

.EXAMPLE
Invoke-JavaInventory -Category Method -SourcePath .\src

Generates a method inventory for the Java sources under '.\src'.

.EXAMPLE
Invoke-JavaInventory -Category RestApi -SourcePath C:\Projects\Service -OutputFile .\rest-api.txt

Generates a REST API inventory and writes the output to 'rest-api.txt'.

.NOTES
Requirements:
- Java Development Kit (JDK) installed and available on PATH.
- The bundled Checkstyle JAR located in the module's resources directory.
- A valid Config.psd1 configuration file.
#>
function Invoke-JavaInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("Method", "RestApi")]
        [string]$Category,
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
        [string]$SourcePath,
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$OutputFile
    )

    if (-not (Get-Module -Name "PSLogger")) {
        Import-Module "PSLogger" -ErrorAction Stop
    }

    foreach ($Tool in "java", "javac", "jar") {
        if (-not (Get-Command $Tool -ErrorAction Ignore)) {
            Write-ErrorLog -Message "'$Tool' was not found in PATH." -Throw
        }
    }

    $Config = Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot "Config.psd1") -ErrorAction Stop
    $script:BuildPath = Join-Path $PSScriptRoot $Config.BuildDirectory
    $ResourcesPath = Join-Path $PSScriptRoot "resources"
    $script:CheckstyleJarPath = Join-Path $ResourcesPath "checkstyle-12.3.0-all.jar"
    $CompiledChecksJarPath = Join-Path $script:BuildPath $Config.CompiledChecksJarFileName
    $ConfigsPath = Join-Path $ResourcesPath "configs"
    $ClassPath = @($script:CheckstyleJarPath, $CompiledChecksJarPath) -join [System.IO.Path]::PathSeparator

    try {
        if (Test-Path -LiteralPath $script:BuildPath) {
            Remove-Item $script:BuildPath -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:BuildPath | Out-Null
        Write-InfoLog -Message "Initialized '$script:BuildPath'."

        foreach ($Class in "MethodInventoryCheck", "RestApiInventoryCheck") {
            Initialize-CheckstyleCheck -ClassName $Class
        }

        & jar `
            cf $CompiledChecksJarPath `
            -C $script:BuildPath "fun\ninth" `
            -C $ResourcesPath "checkstyle_packages.xml"

        if ($LASTEXITCODE -ne 0) {
            Write-ErrorLog -Message "Failed to generate '$CompiledChecksJarPath'." -Throw
        }
        Write-InfoLog -Message "Generated '$CompiledChecksJarPath'."

        $Configs = @{
            Method  = @{
                Config  = Join-Path $ConfigsPath "method_inventory_check_config.xml"
                Message = "Running method-inventory-checkstyle."
            }
            RestApi = @{
                Config  = Join-Path $ConfigsPath "rest_api_inventory_check_config.xml"
                Message = "Running REST-API-inventory-checkstyle."
            }
        }

        $Current = $Configs[$Category]
        Write-InfoLog -Message $Current.Message

        if ($OutputFile) {
            Write-VisualSeparator
            $Parent = Split-Path -Parent $OutputFile
            if ($Parent -and -not (Test-Path -LiteralPath $Parent)) {
                New-Item -ItemType Directory -Path $Parent -Force | Out-Null
                Write-InfoLog -Message "Created directory '$Parent'."
            }

            & java `
                -cp $ClassPath `
                com.puppycrawl.tools.checkstyle.Main `
                -c $Current.Config `
                $SourcePath | Out-File -FilePath $OutputFile -Encoding utf8
        }
        else {
            & java `
                -cp $ClassPath `
                com.puppycrawl.tools.checkstyle.Main `
                -c $Current.Config `
                $SourcePath
        }
        if ($LASTEXITCODE -ne 0) {
            Write-ErrorLog -Message "Checkstyle execution failed." -Throw
        }
    }
    catch {
    }
    finally {
        if (Test-Path -LiteralPath $script:BuildPath) {
            Remove-Item $script:BuildPath -Recurse -Force
        }
    }
}
