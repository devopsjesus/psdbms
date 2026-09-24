BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:properties = @('az_subscription_id', 'az_subscription_name')
    $script:values = @{ az_subscription_id = 'subscription-id'; az_subscription_name = 'Subscription' }
}

Describe 'az_subscription' {
    It 'matches the az_subscription.csv schema' {
        $instance = New-TestClassInstance -ClassName 'az_subscription' -Properties @{}
        $propertyNames = @($instance | Get-Member -MemberType Property | Select-Object -ExpandProperty Name)
        $csvHeader = @((Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\data\az_subscription.csv') -First 1) -split ',')

        Compare-Object -ReferenceObject $script:properties -DifferenceObject $propertyNames | Should -BeNullOrEmpty
        Compare-Object -ReferenceObject $csvHeader -DifferenceObject $propertyNames | Should -BeNullOrEmpty
    }

    It 'maps all constructor values' {
        $instance = New-TestClassInstance -ClassName 'az_subscription' -Properties $script:values

        foreach ($property in $script:properties) {
            $instance.$property | Should -Be $script:values[$property]
        }
    }
}