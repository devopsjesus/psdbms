$modulePath = Join-Path $PSScriptRoot '..\psdbms.psd1'
Remove-Module psdbms -Force -ErrorAction SilentlyContinue
Import-Module $modulePath -Force -ErrorAction Stop

function script:New-TestClassInstance {
    param(
        [Parameter(Mandatory)]
        [string] $ClassName,

        [hashtable] $Properties
    )

    $classType = $ClassName -as [type]
    if ($null -eq $classType) {
        throw "Class '$ClassName' was not loaded."
    }

    if ($null -eq $Properties) {
        return $classType::new()
    }

    return $classType::new($Properties)
}