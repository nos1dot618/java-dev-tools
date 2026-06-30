[CmdletBinding()]
param(
    [Parameter(Mandatory, ParameterSetName = "Method")]
    [switch]$MethodInventory,

    [Parameter(Mandatory, ParameterSetName = "RestApi")]
    [switch]$RestApiInventory
)

Import-Module "$PSScriptRoot\PSLogger.psm1" -Force
Import-Module "$PSScriptRoot\Config.psm1" -Force

$ClassPath = @(
    Join-Path $PSScriptRoot "resources\checkstyle-12.3.0-all.jar"
    Join-Path $BuildDirectory $ChecksJarFileName
) -join ";"

$Configs = @{
    Method  = @{
        Config  = Join-Path $PSScriptRoot "resources\configs\method_inventory_check_config.xml"
        Message = "Running method-inventory-checkstyle."
    }

    RestApi = @{
        Config  = Join-Path $PSScriptRoot "resources\configs\rest_api_inventory_check_config.xml"
        Message = "Running REST-API-inventory-checkstyle."
    }
}

$Current = $Configs[$PSCmdlet.ParameterSetName]

Write-InfoLog -Message $Current.Message

& java `
    -cp $ClassPath `
    com.puppycrawl.tools.checkstyle.Main `
    -c $Current.Config `
    (Join-Path $PSScriptRoot "dev-test\src")
