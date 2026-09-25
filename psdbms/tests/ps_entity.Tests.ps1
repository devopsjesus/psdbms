using module ..\psdbms.psd1

Describe 'PsEntity CRUD' {
    BeforeEach {
        $script:dataPath = Join-Path $TestDrive 'people.csv'
        $schemaPath = Join-Path $PSScriptRoot 'schemas-good\sample.json'
        $schema = [PsEntitySchema]::new($schemaPath, $script:dataPath)
        $script:entity = [PsEntity]::new($schema)
        $script:entity.Create($true)
        $script:id = [guid]::NewGuid()
    }

    It 'creates a CSV from its schema' {
        (Get-Content -LiteralPath $script:dataPath -First 1).Trim('"') | Should -Be 'id","tenant","name","active'
        Test-Path -LiteralPath "$script:dataPath.psdbms.json" | Should -BeFalse
    }

    It 'requires force to overwrite an existing entity' {
        $null = $script:entity.Add(@{ tenant = 'one'; name = 'Ada' })

        { $script:entity.Create() } | Should -Throw '*already exists*'
        $script:entity.Create($true)

        $script:entity.Find(@{}).Count | Should -Be 0
        (Get-Content -LiteralPath $script:dataPath -First 1).Trim('"') | Should -Be 'id","tenant","name","active'
    }

    It 'adds, finds, updates, and removes records' {
        $record = $script:entity.Add(@{ id = $script:id; tenant = 'one'; name = 'Ada'; active = $true })
        $record.id | Should -Be $script:id.ToString()

        $script:entity.Find($script:id).name | Should -Be 'Ada'
        $script:entity.Find(@{ id = $script:id }).name | Should -Be 'Ada'
        $script:entity.Update($script:id, @{ name = 'Grace' }).name | Should -Be 'Grace'

        $script:entity.Remove(@{ id = $script:id })
        $script:entity.Find(@{}).Count | Should -Be 0
    }

    It 'supports inferred and composite schema keys' {
        $noKeyPath = Join-Path $TestDrive 'no-key.csv'
        $noKeySchemaPath = Join-Path $PSScriptRoot 'schemas-good\no_key.json'
        $noKeyEntity = [PsEntity]::new([PsEntitySchema]::new($noKeySchemaPath, $noKeyPath))
        $noKeyEntity.Create()
        $null = $noKeyEntity.Add(@{ name = 'Ada' })
        { $noKeyEntity.Find('Ada') } | Should -Throw '*exactly one key column; found 0*'
        { $noKeyEntity.Update('Ada', @{ name = 'Grace' }) } | Should -Throw '*exactly one key column; found 0*'

        $multipleKeyPath = Join-Path $TestDrive 'multiple-key.csv'
        $multipleKeySchemaPath = Join-Path $PSScriptRoot 'schemas-good\composite_key.json'
        $multipleKeyEntity = [PsEntity]::new([PsEntitySchema]::new($multipleKeySchemaPath, $multipleKeyPath))
        $multipleKeyEntity.Create()
        $null = $multipleKeyEntity.Add(@{ first_id = '1'; second_id = '2'; name = 'Ada' })
        { $multipleKeyEntity.Find('1') } | Should -Throw '*exactly one key column; found 2*'
        { $multipleKeyEntity.Update('1', @{ name = 'Grace' }) } | Should -Throw '*exactly one key column; found 2*'
        { $multipleKeyEntity.Update(@{ first_id = '1' }, @{ name = 'Grace' }) } | Should -Throw '*must contain exactly these columns*'
        $multipleKeyEntity.Update(@{ first_id = '1'; second_id = '2' }, @{ name = 'Grace' }).name | Should -Be 'Grace'
    }

    It 'generates missing guid and numeric keys' {
        $record = $script:entity.Add(@{ tenant = 'one'; name = 'Ada'; active = $true })
        [guid]::Parse($record.id) | Should -Not -BeNullOrEmpty

        $numericPath = Join-Path $TestDrive 'typed-numeric.csv'
        $numericSchemaPath = Join-Path $PSScriptRoot 'schemas-good\typed.json'
        $numericSchema = [PsEntitySchema]::new($numericSchemaPath, $numericPath)
        $numericEntity = [PsEntity]::new($numericSchema)
        $numericEntity.Create()

        $numericEntity.Add(@{ string_value = 'first' }).id | Should -Be '1'
        $numericEntity.Add(@{ string_value = 'second' }).id | Should -Be '2'
    }

    It 'normalizes supported storage types and rejects relative URIs' {
        $typedPath = Join-Path $TestDrive 'typed.csv'
        $typedSchemaPath = Join-Path $PSScriptRoot 'schemas-good\typed.json'
        $typedEntity = [PsEntity]::new([PsEntitySchema]::new($typedSchemaPath, $typedPath))
        $typedEntity.Create()
        $identifier = [guid]::NewGuid()

        $record = $typedEntity.Add(@{
            string_value = 'text'
            integer_value = 42
            long_value = [long] 5000000000
            decimal_value = [decimal] 12.34
            double_value = [double] 1.5
            boolean_value = 'false'
            datetime_value = [datetime] '2026-01-02T03:04:05Z'
            guid_value = $identifier
            uri_value = 'https://example.test/path'
        })

        $record.string_value | Should -Be 'text'
        $record.integer_value | Should -Be '42'
        $record.long_value | Should -Be '5000000000'
        $record.decimal_value | Should -Be '12.34'
        $record.double_value | Should -Be '1.5'
        $record.boolean_value | Should -Be 'false'
        $record.datetime_value | Should -Be '2026-01-02T03:04:05.0000000Z'
        $record.guid_value | Should -Be $identifier.ToString()
        $record.uri_value | Should -Be 'https://example.test/path'
        { $typedEntity.Update($record.id, @{ uri_value = 'relative/path' }) } | Should -Throw '*not a valid uri*'
    }

    It 'allows repeated empty values in unique constraints' {
        $typedPath = Join-Path $TestDrive 'typed-empty.csv'
        $typedSchemaPath = Join-Path $PSScriptRoot 'schemas-good\typed.json'
        $typedEntity = [PsEntity]::new([PsEntitySchema]::new($typedSchemaPath, $typedPath))
        $typedEntity.Create()

        $null = $typedEntity.Add(@{})
        { $typedEntity.Add(@{}) } | Should -Not -Throw
    }

    It 'rejects missing, unknown, invalid, and duplicate values' {
        { $script:entity.Add(@{ id = [guid]::NewGuid() }) } | Should -Throw '*required*'
        { $script:entity.Add(@{ id = [guid]::NewGuid(); name = 'Ada'; extra = 'value' }) } | Should -Throw '*not defined*'
        { $script:entity.Add(@{ id = 'not-a-guid'; name = 'Ada' }) } | Should -Throw '*not a valid guid*'

        $null = $script:entity.Add(@{ id = $script:id; tenant = 'one'; name = 'Ada' })
        { $script:entity.Add(@{ id = $script:id; tenant = 'two'; name = 'Grace' }) } | Should -Throw '*must be unique*'
    }

    It 'requires exactly one matching record for updates and removals' {
        $missingId = [guid]::NewGuid()
        { $script:entity.Update($missingId, @{ name = 'Missing' }) } | Should -Throw '*found 0*'
        { $script:entity.Remove(@{ id = $missingId }) } | Should -Throw '*found 0*'

        $duplicateId = [guid]::NewGuid()
        $duplicate = $script:entity.Add(@{ id = $duplicateId; tenant = 'one'; name = 'First' })
        $duplicate | Export-Csv -LiteralPath $script:dataPath -Append -NoTypeInformation

        { $script:entity.Update($duplicateId, @{ name = 'Updated' }) } | Should -Throw '*found 2*'
        { $script:entity.Remove(@{ id = $duplicateId }) } | Should -Throw '*found 2*'
    }

    It 'enforces grouped unique values across rows' {
        $groupPath = Join-Path $TestDrive 'memberships.csv'
        $groupSchemaPath = Join-Path $PSScriptRoot 'schemas-good\sample.json'
        $groupSchema = [PsEntitySchema]::new($groupSchemaPath, $groupPath)
        $groupEntity = [PsEntity]::new($groupSchema)
        $groupEntity.Create()
        $first = $groupEntity.Add(@{ tenant = 'one'; name = 'ada' })
        $second = $groupEntity.Add(@{ tenant = 'two'; name = 'ada' })
        $null = $groupEntity.Add(@{ tenant = 'one'; name = 'grace' })

        { $groupEntity.Add(@{ tenant = 'one'; name = 'ada' }) } | Should -Throw '*must be unique as a group*'
        $groupEntity.Update($first.id, @{ name = 'ada' }).name | Should -Be 'ada'
        { $groupEntity.Update($second.id, @{ tenant = 'one' }) } | Should -Throw '*must be unique as a group*'
    }
}

Describe 'PsEntity references' {
    It 'resolves relative references and enforces matching values' {
        $parentPath = Join-Path $TestDrive 'parent.csv'
        $parentSchemaPath = Join-Path $PSScriptRoot 'schemas-good\parent.json'
        $parent = [PsEntity]::new([PsEntitySchema]::new($parentSchemaPath, $parentPath))
        $parent.Create()
        $parentRecord = $parent.Add(@{ parent_name = 'Parent' })

        $childSchemaPath = Join-Path $PSScriptRoot 'schemas-good\child.json'
        $child = [PsEntity]::new([PsEntitySchema]::new($childSchemaPath, (Join-Path $TestDrive 'child.csv')))
        $child.Create()
        { $child.Add(@{ parent_id = 'missing'; child_name = 'Child' }) } | Should -Throw '*does not exist in reference*'
        $childRecord = $child.Add(@{ parent_id = $parentRecord.parent_id; child_name = 'Child' })
        $childRecord.parent_id | Should -Be $parentRecord.parent_id
        $referencedRow = $child.GetReferencedRowByKey('parent_id', $childRecord.parent_id)
        $referencedRow.parent_id | Should -Be $parentRecord.parent_id
        $referencedRow.parent_name | Should -Be 'Parent'
        { $child.Update($childRecord.child_id, @{ parent_id = 'missing' }) } | Should -Throw '*does not exist in reference*'
    }

    It 'validates referenced row queries' {
        $childSchemaPath = Join-Path $PSScriptRoot 'schemas-good\child.json'
        $child = [PsEntity]::new([PsEntitySchema]::new($childSchemaPath, (Join-Path $TestDrive 'query\child.csv')))

        { $child.GetReferencedRowByKey('missing', 'value') } | Should -Throw '*not defined*'
        { $child.GetReferencedRowByKey('child_name', 'value') } | Should -Throw '*does not reference*'
        { $child.GetReferencedRowByKey('parent_id', 'value') } | Should -Throw '*Referenced entity*was not found*'
    }

    It 'rejects a missing referenced entity' {
        $childSchemaPath = Join-Path $PSScriptRoot 'schemas-good\child.json'
        $child = [PsEntity]::new([PsEntitySchema]::new($childSchemaPath, (Join-Path $TestDrive 'orphan\child.csv')))
        $child.Create()

        { $child.Add(@{ parent_id = 'missing'; child_name = 'Child' }) } | Should -Throw '*Referenced entity*was not found*'
    }

    It 'rejects a reference whose key column name does not match' {
        $parentPath = Join-Path $TestDrive 'mismatched_parent.csv'
        $parentSchemaPath = Join-Path $PSScriptRoot 'schemas-bad\mismatched_parent.json'
        $parent = [PsEntity]::new([PsEntitySchema]::new($parentSchemaPath, $parentPath))
        $parent.Create()
        $null = $parent.Add(@{ id = 'parent-1' })

        $childSchemaPath = Join-Path $PSScriptRoot 'schemas-bad\mismatched_child.json'
        $child = [PsEntity]::new([PsEntitySchema]::new($childSchemaPath, (Join-Path $TestDrive 'mismatched_child.csv')))
        $child.Create()

        { $child.Add(@{ child_id = 'child-1'; parent_id = 'parent-1' }) } | Should -Throw "*does not contain matching key column 'parent_id'*"
    }
}

Describe 'module surface' {
    It 'creates schema and entity objects through exported functions' {
        $schemaPath = Join-Path $PSScriptRoot 'schemas-good\sample.json'
        $dataPath = Join-Path $TestDrive 'wrapper.csv'

        $schema = New-PsEntitySchema -SchemaPath $schemaPath -DataPath $dataPath
        $entity = $schema | New-PsEntity

        $schema | Should -BeOfType PsEntitySchema
        $schema.Path | Should -Be $dataPath
        $entity | Should -BeOfType PsEntity
        @(Get-Command -Module psdbms -CommandType Function).Name | Should -Be @('New-PsEntity', 'New-PsEntitySchema')
    }
}
