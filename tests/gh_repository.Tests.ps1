BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:properties = @('gh_repository_id', 'gh_repository_name')
    $script:values = @{ gh_repository_id = 'repository-id'; gh_repository_name = 'Repository' }
}

Describe 'gh_repository' {
    It 'matches the gh_repository.csv schema' {
        $instance = New-TestClassInstance -ClassName 'gh_repository' -Properties @{}
        $propertyNames = @($instance | Get-Member -MemberType Property | Select-Object -ExpandProperty Name)
        $csvHeader = @((Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\data\gh_repository.csv') -First 1) -split ',')

        Compare-Object -ReferenceObject $script:properties -DifferenceObject $propertyNames | Should -BeNullOrEmpty
        Compare-Object -ReferenceObject $csvHeader -DifferenceObject $propertyNames | Should -BeNullOrEmpty
    }

    It 'maps all constructor values' {
        $instance = New-TestClassInstance -ClassName 'gh_repository' -Properties $script:values

        foreach ($property in $script:properties) {
            $instance.$property | Should -Be $script:values[$property]
        }
    }
}