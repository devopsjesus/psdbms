BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')

    $script:originalDataSource = $env:DATA_SOURCE
    $script:defaultDataSource = Join-Path $TestDrive 'default.csv'
    Set-Content -LiteralPath $script:defaultDataSource -Value 'header'
    $env:DATA_SOURCE = $script:defaultDataSource

    $script:properties = @{
        az_service_principal_id          = '6340792e-2589-46f1-a693-1d6e64d52c13'
        az_service_principal_name        = 'S_TEST_SOLUTION'
        az_service_principal_secr_kv_ref = 'https://example.test/secrets/test-secret'
    }
}

AfterAll {
    $env:DATA_SOURCE = $script:originalDataSource
}

Describe 'az_service_principal class contract' {
    It 'exposes the expected public properties' {
        $instance = New-TestClassInstance -ClassName 'az_service_principal'
        $propertyNames = @(
            $instance |
                Get-Member -MemberType Property |
                Select-Object -ExpandProperty Name
        )

        $propertyNames | Should -Be @(
            'az_service_principal_id'
            'az_service_principal_name'
            'az_service_principal_secr_kv_ref'
        )
    }
}

Describe 'az_service_principal initialization' {
    It 'creates a blank instance with the configured default data source' {
        $instance = New-TestClassInstance -ClassName 'az_service_principal'

        $instance.az_service_principal_id | Should -BeNullOrEmpty
        $instance.az_service_principal_name | Should -BeNullOrEmpty
        $instance.az_service_principal_secr_kv_ref | Should -BeNullOrEmpty
        $instance.data_source | Should -Be $script:defaultDataSource
    }

    It 'maps constructor values to properties' {
        $instance = New-TestClassInstance -ClassName 'az_service_principal' -Properties $script:properties

        $instance.az_service_principal_id | Should -Be $script:properties.az_service_principal_id
        $instance.az_service_principal_name | Should -Be $script:properties.az_service_principal_name
        $instance.az_service_principal_secr_kv_ref | Should -Be $script:properties.az_service_principal_secr_kv_ref
    }

    It 'rejects a null constructor value for <PropertyName>' -ForEach @(
        @{ PropertyName = 'az_service_principal_id' }
        @{ PropertyName = 'az_service_principal_name' }
        @{ PropertyName = 'az_service_principal_secr_kv_ref' }
    ) {
        $properties = $script:properties.Clone()
        $properties[$PropertyName] = $null

        { New-TestClassInstance -ClassName 'az_service_principal' -Properties $properties } |
            Should -Throw -ExceptionType ([System.Management.Automation.SetValueInvocationException])
    }

    It 'rejects an unknown constructor property' {
        { New-TestClassInstance -ClassName 'az_service_principal' -Properties @{ unknown_property = 'value' } } |
            Should -Throw
    }

    It 'allows properties to be updated directly' {
        $instance = New-TestClassInstance -ClassName 'az_service_principal' -Properties $script:properties

        $instance.az_service_principal_name = 'S_UPDATED'

        $instance.az_service_principal_name | Should -Be 'S_UPDATED'
    }

    It 'rejects a null direct assignment to <PropertyName>' -ForEach @(
        @{ PropertyName = 'az_service_principal_id' }
        @{ PropertyName = 'az_service_principal_name' }
        @{ PropertyName = 'az_service_principal_secr_kv_ref' }
    ) {
        $instance = New-TestClassInstance -ClassName 'az_service_principal' -Properties $script:properties

        { $instance.$PropertyName = $null } |
            Should -Throw -ExceptionType ([System.Management.Automation.SetValueInvocationException])
    }

    It 'uses a constructor-supplied data source instead of the environment default' {
        $constructorDataSource = Join-Path $TestDrive 'constructor.csv'
        $instance = New-TestClassInstance -ClassName 'az_service_principal' -Properties @{
            data_source = $constructorDataSource
        }

        $instance.data_source | Should -Be $constructorDataSource
    }

    It 'uses the local data source when DATA_SOURCE is unset' {
        try {
            $env:DATA_SOURCE = $null

            $instance = New-TestClassInstance -ClassName 'az_service_principal'

            $expectedDataSource = (Resolve-Path (Join-Path $PSScriptRoot '..\data\az_service_principal.csv')).Path
            $instance.data_source | Should -Be $expectedDataSource
        }
        finally {
            $env:DATA_SOURCE = $script:defaultDataSource
        }
    }
}

Describe 'az_service_principal data-source methods' {
    BeforeEach {
        $script:explicitDataSource = Join-Path $TestDrive 'explicit.csv'
        Set-Content -LiteralPath $script:explicitDataSource -Value 'header'
    }

    It 'validates an existing data source' {
        $classType = 'az_service_principal' -as [type]
        $classType::ValidateDataSource($script:explicitDataSource) | Should -BeTrue
    }

    It 'rejects a missing data source' {
        $missingDataSource = Join-Path $TestDrive 'missing.csv'
        $classType = 'az_service_principal' -as [type]

        { $classType::ValidateDataSource($missingDataSource) } |
            Should -Throw -ExpectedMessage "*Data source path '$missingDataSource' was not found.*"
    }

    It 'adds using the default data source' {
        $instance = New-TestClassInstance -ClassName 'az_service_principal'

        $instance.Add() | Should -Be 'Data added teehee...'
    }

    It 'adds using an explicit data source' {
        $instance = New-TestClassInstance -ClassName 'az_service_principal'

        $instance.Add($script:explicitDataSource) | Should -Be 'Data added teehee...'
    }

    It 'rejects a missing configured data source' {
        $missingDataSource = Join-Path $TestDrive 'missing-configured.csv'
        $instance = New-TestClassInstance -ClassName 'az_service_principal' -Properties @{
            data_source = $missingDataSource
        }

        { $instance.Add() } |
            Should -Throw -ExpectedMessage "*Data source path '$missingDataSource' was not found.*"
    }

    It 'rejects a missing explicit data source' {
        $missingDataSource = Join-Path $TestDrive 'missing-explicit.csv'
        $instance = New-TestClassInstance -ClassName 'az_service_principal'

        { $instance.Add($missingDataSource) } |
            Should -Throw -ExpectedMessage "*Data source path '$missingDataSource' was not found.*"
    }

    It 'prefers the explicit data source over the configured data source' {
        $instance = New-TestClassInstance -ClassName 'az_service_principal' -Properties @{
            data_source = Join-Path $TestDrive 'missing-configured.csv'
        }

        $instance.Add($script:explicitDataSource) | Should -Be 'Data added teehee...'
    }
}