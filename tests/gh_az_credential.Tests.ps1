BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:properties = @(
        'az_service_principal_id'
        'az_subscription_id'
        'gh_az_credential_id'
        'gh_repo_environment_id'
        'gh_repository_id'
    )
    $script:values = @{
        gh_az_credential_id = 'credential-id'
        gh_repository_id = 'repository-id'
        gh_repo_environment_id = 'environment-id'
        az_subscription_id = 'subscription-id'
        az_service_principal_id = 'principal-id'
    }
}

Describe 'gh_az_credential' {
    It 'matches the gh_az_credential.csv schema' {
        $instance = New-TestClassInstance -ClassName 'gh_az_credential' -Properties @{}
        $propertyNames = @($instance | Get-Member -MemberType Property | Select-Object -ExpandProperty Name)
        $csvHeader = @((Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\data\gh_az_credential.csv') -First 1) -split ',')

        Compare-Object -ReferenceObject $script:properties -DifferenceObject $propertyNames | Should -BeNullOrEmpty
        Compare-Object -ReferenceObject $csvHeader -DifferenceObject $propertyNames | Should -BeNullOrEmpty
    }

    It 'maps all constructor values' {
        $instance = New-TestClassInstance -ClassName 'gh_az_credential' -Properties $script:values

        foreach ($property in $script:properties) {
            $instance.$property | Should -Be $script:values[$property]
        }
    }
}