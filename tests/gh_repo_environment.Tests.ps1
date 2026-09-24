BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:properties = @('gh_repo_environment_id', 'gh_repo_environment_name')
    $script:values = @{ gh_repo_environment_id = 'environment-id'; gh_repo_environment_name = 'DEV' }
}

Describe 'gh_repo_environment' {
    It 'matches the gh_repo_environment.csv schema' {
        $instance = New-TestClassInstance -ClassName 'gh_repo_environment' -Properties @{}
        $propertyNames = @($instance | Get-Member -MemberType Property | Select-Object -ExpandProperty Name)
        $csvHeader = @((Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\data\gh_repo_environment.csv') -First 1) -split ',')

        Compare-Object -ReferenceObject $script:properties -DifferenceObject $propertyNames | Should -BeNullOrEmpty
        Compare-Object -ReferenceObject $csvHeader -DifferenceObject $propertyNames | Should -BeNullOrEmpty
    }

    It 'maps all constructor values' {
        $instance = New-TestClassInstance -ClassName 'gh_repo_environment' -Properties $script:values

        foreach ($property in $script:properties) {
            $instance.$property | Should -Be $script:values[$property]
        }
    }
}