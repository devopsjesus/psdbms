using module ..\psdbms.psd1

Describe 'PsEntitySchema' {
    It 'loads a JSON schema with a data path override' {
        $schemaPath = Join-Path $PSScriptRoot 'schemas-good\sample.json'
        $overridePath = Join-Path $TestDrive 'alternate.csv'

        $schema = [PsEntitySchema]::new($schemaPath, $overridePath)

        $schema.Name | Should -Be 'sample'
        $schema.Path | Should -Be $overridePath
    }

    It 'validates grouped unique column definitions' {
        $schemaPath = Join-Path $PSScriptRoot 'schemas-bad\invalid_unique_group.json'

        { [PsEntitySchema]::new($schemaPath) } | Should -Throw "*'missing' is not defined*"
    }

    It 'rejects duplicate columns' {
        $schemaPath = Join-Path $PSScriptRoot 'schemas-bad\duplicate_columns.json'

        { [PsEntitySchema]::new($schemaPath) } | Should -Throw "*duplicate column 'id'*"
    }

    It 'loads the sample schema with its metadata' {
        $schemaPath = Join-Path $PSScriptRoot 'schemas-good\sample.json'
        $schema = [PsEntitySchema]::new($schemaPath)

        $schema.Name | Should -Be 'sample'
        $schema.Path | Should -Be (Join-Path $PSScriptRoot 'schemas-good\sample.csv')
        $schema.Columns.Name | Should -Be @('id', 'tenant', 'name', 'active')
        $schema.Columns[0].Generated | Should -BeTrue
        $schema.Columns[3].Type | Should -Be 'bool'
        $schema.UniqueGroups[0].Columns | Should -Be @('tenant', 'name')
    }
}
